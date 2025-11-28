# Migration Guide: Flat Structure to Modular Structure

This guide will help you migrate from the old flat Terraform structure to the new modular, environment-based structure.

## Old Structure (Deprecated)

```
infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── vpc.tf
├── security_groups.tf
├── ecr.tf
├── iam.tf
├── alb.tf
├── cloudwatch.tf
├── ecs.tf
├── dynamodb.tf
└── terraform.tfstate
```

## New Structure

```
infrastructure/
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── modules/
│   ├── networking/
│   ├── security/
│   ├── database/
│   ├── ecr/
│   ├── iam/
│   ├── alb/
│   ├── monitoring/
│   └── ecs/
└── scripts/
    ├── deploy-images.sh
    └── init-environment.sh
```

## Benefits of New Structure

1. **Environment Isolation**: Separate dev, staging, prod configurations
2. **Reusable Modules**: DRY principle, easier testing
3. **Better Organization**: Related resources grouped together
4. **Scalability**: Easy to add new environments
5. **Team Collaboration**: Clear separation of concerns
6. **Version Control**: Better diff visibility

## Migration Steps

### Step 1: Backup Current State

```bash
cd infrastructure

# Backup terraform state
cp terraform.tfstate terraform.tfstate.backup
cp terraform.tfstate.backup terraform.tfstate.old

# Backup all .tf files
mkdir -p old-structure
cp *.tf old-structure/
```

### Step 2: Export Current State

Get information about your current resources:

```bash
# List all resources
terraform state list > current-resources.txt

# Export outputs
terraform output > current-outputs.txt
```

### Step 3: Understand State Migration Options

You have three options:

#### Option A: Fresh Start (Recommended for Dev)

**Pros**: Clean, no state migration complexity
**Cons**: Requires destroying and recreating resources

```bash
# 1. Destroy old infrastructure (WARNING: This deletes everything!)
terraform destroy

# 2. Use new structure
cd environments/dev
terraform init
terraform apply

# 3. Redeploy services
cd ../..
./scripts/deploy-images.sh dev
```

#### Option B: State Migration (For Production)

**Pros**: No downtime, keeps existing resources
**Cons**: Complex, requires careful planning

```bash
# This will be covered in Step 4
```

#### Option C: Import Resources

**Pros**: Start fresh with state, keep resources
**Cons**: Time-consuming, manual process

### Step 4: State Migration (Option B - Detailed)

If you need to keep existing resources:

```bash
# 1. Initialize new structure
cd environments/dev
terraform init

# 2. Pull old state into new location
cp ../../terraform.tfstate .

# 3. Create a migration script
cat > migrate-state.sh <<'SCRIPT'
#!/bin/bash
set -e

# VPC Resources
terraform state mv aws_vpc.main module.networking.aws_vpc.main
terraform state mv 'aws_subnet.public[0]' 'module.networking.aws_subnet.public[0]'
terraform state mv 'aws_subnet.public[1]' 'module.networking.aws_subnet.public[1]'
terraform state mv 'aws_subnet.private[0]' 'module.networking.aws_subnet.private[0]'
terraform state mv 'aws_subnet.private[1]' 'module.networking.aws_subnet.private[1]'
terraform state mv aws_internet_gateway.main module.networking.aws_internet_gateway.main
# ... Add all other resources

# Security Groups
terraform state mv aws_security_group.alb module.security.aws_security_group.alb
terraform state mv aws_security_group.ecs_tasks module.security.aws_security_group.ecs_tasks

# DynamoDB
terraform state mv aws_dynamodb_table.books module.database.aws_dynamodb_table.books
terraform state mv aws_dynamodb_table.ratings module.database.aws_dynamodb_table.ratings
terraform state mv aws_dynamodb_table.user_profiles module.database.aws_dynamodb_table.user_profiles

# ECR
terraform state mv aws_ecr_repository.search_api module.ecr.aws_ecr_repository.search_api
terraform state mv aws_ecr_repository.bookdetail_api module.ecr.aws_ecr_repository.bookdetail_api
terraform state mv aws_ecr_repository.ratings_api module.ecr.aws_ecr_repository.ratings_api

# IAM
terraform state mv aws_iam_role.ecs_task_execution_role module.iam.aws_iam_role.ecs_task_execution_role
terraform state mv aws_iam_role.ecs_task_role module.iam.aws_iam_role.ecs_task_role

# ... Continue for all resources
SCRIPT

chmod +x migrate-state.sh

# 4. Run migration
./migrate-state.sh

# 5. Verify plan shows no changes
terraform plan
```

### Step 5: Verify Migration

```bash
cd environments/dev

# Check that plan shows minimal or no changes
terraform plan

# If you see resources being destroyed/recreated, review the state migration

# Once plan looks good, apply
terraform apply
```

### Step 6: Test Services

```bash
# Get ALB URL
export ALB_URL=$(terraform output -raw alb_url)

# Test each service
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "limit": 5}'

curl $ALB_URL/books/OL1000046W

# Check ECS services
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs list-services --cluster $CLUSTER
```

### Step 7: Update CI/CD Pipelines

If you have automated deployments:

```bash
# Old command
cd infrastructure && terraform apply

# New command
cd infrastructure/environments/dev && terraform apply
```

Update your deployment scripts:

```bash
# Old
./infrastructure/deploy-images.sh

# New
./infrastructure/scripts/deploy-images.sh dev
```

### Step 8: Clean Up Old Files

Once migration is successful and verified:

```bash
cd infrastructure

# Remove old .tf files from root
rm -f main.tf variables.tf outputs.tf vpc.tf security_groups.tf ecr.tf iam.tf alb.tf cloudwatch.tf ecs.tf

# Keep dynamodb.tf as reference if needed, or remove it
# rm -f dynamodb.tf

# Remove old state backup (after confirming everything works)
# rm -f terraform.tfstate.old current-resources.txt current-outputs.txt
```

## Complete State Migration Script

Here's a comprehensive migration script:

```bash
#!/bin/bash
# migrate-to-modules.sh

set -e

echo "Starting Terraform state migration to modular structure..."

# Networking Module
terraform state mv aws_vpc.main 'module.networking.aws_vpc.main'
terraform state mv aws_internet_gateway.main 'module.networking.aws_internet_gateway.main'
terraform state mv 'aws_subnet.public[0]' 'module.networking.aws_subnet.public[0]'
terraform state mv 'aws_subnet.public[1]' 'module.networking.aws_subnet.public[1]'
terraform state mv 'aws_subnet.private[0]' 'module.networking.aws_subnet.private[0]'
terraform state mv 'aws_subnet.private[1]' 'module.networking.aws_subnet.private[1]'
terraform state mv 'aws_eip.nat[0]' 'module.networking.aws_eip.nat[0]'
terraform state mv 'aws_eip.nat[1]' 'module.networking.aws_eip.nat[1]'
terraform state mv 'aws_nat_gateway.main[0]' 'module.networking.aws_nat_gateway.main[0]'
terraform state mv 'aws_nat_gateway.main[1]' 'module.networking.aws_nat_gateway.main[1]'
terraform state mv aws_route_table.public 'module.networking.aws_route_table.public'
terraform state mv 'aws_route_table.private[0]' 'module.networking.aws_route_table.private[0]'
terraform state mv 'aws_route_table.private[1]' 'module.networking.aws_route_table.private[1]'
terraform state mv 'aws_route_table_association.public[0]' 'module.networking.aws_route_table_association.public[0]'
terraform state mv 'aws_route_table_association.public[1]' 'module.networking.aws_route_table_association.public[1]'
terraform state mv 'aws_route_table_association.private[0]' 'module.networking.aws_route_table_association.private[0]'
terraform state mv 'aws_route_table_association.private[1]' 'module.networking.aws_route_table_association.private[1]'

# Security Module
terraform state mv aws_security_group.alb 'module.security.aws_security_group.alb'
terraform state mv aws_security_group.ecs_tasks 'module.security.aws_security_group.ecs_tasks'

# Database Module
terraform state mv aws_dynamodb_table.books 'module.database.aws_dynamodb_table.books'
terraform state mv aws_dynamodb_table.ratings 'module.database.aws_dynamodb_table.ratings'
terraform state mv aws_dynamodb_table.user_profiles 'module.database.aws_dynamodb_table.user_profiles'

# ECR Module
terraform state mv aws_ecr_repository.search_api 'module.ecr.aws_ecr_repository.search_api'
terraform state mv aws_ecr_lifecycle_policy.search_api 'module.ecr.aws_ecr_lifecycle_policy.search_api'
terraform state mv aws_ecr_repository.bookdetail_api 'module.ecr.aws_ecr_repository.bookdetail_api'
terraform state mv aws_ecr_lifecycle_policy.bookdetail_api 'module.ecr.aws_ecr_lifecycle_policy.bookdetail_api'
terraform state mv aws_ecr_repository.ratings_api 'module.ecr.aws_ecr_repository.ratings_api'
terraform state mv aws_ecr_lifecycle_policy.ratings_api 'module.ecr.aws_ecr_lifecycle_policy.ratings_api'

# IAM Module
terraform state mv aws_iam_role.ecs_task_execution_role 'module.iam.aws_iam_role.ecs_task_execution_role'
terraform state mv aws_iam_role_policy_attachment.ecs_task_execution_role_policy 'module.iam.aws_iam_role_policy_attachment.ecs_task_execution_role_policy'
terraform state mv aws_iam_role.ecs_task_role 'module.iam.aws_iam_role.ecs_task_role'
terraform state mv aws_iam_policy.dynamodb_access 'module.iam.aws_iam_policy.dynamodb_access'
terraform state mv aws_iam_role_policy_attachment.ecs_task_dynamodb 'module.iam.aws_iam_role_policy_attachment.ecs_task_dynamodb'
terraform state mv aws_iam_policy.cloudwatch_logs 'module.iam.aws_iam_policy.cloudwatch_logs'
terraform state mv aws_iam_role_policy_attachment.ecs_task_cloudwatch 'module.iam.aws_iam_role_policy_attachment.ecs_task_cloudwatch'

# ALB Module
terraform state mv aws_lb.main 'module.alb.aws_lb.main'
terraform state mv aws_lb_target_group.search_api 'module.alb.aws_lb_target_group.search_api'
terraform state mv aws_lb_target_group.bookdetail_api 'module.alb.aws_lb_target_group.bookdetail_api'
terraform state mv aws_lb_target_group.ratings_api 'module.alb.aws_lb_target_group.ratings_api'
terraform state mv aws_lb_listener.http 'module.alb.aws_lb_listener.http'
terraform state mv aws_lb_listener_rule.search_api 'module.alb.aws_lb_listener_rule.search_api'
terraform state mv aws_lb_listener_rule.bookdetail_api 'module.alb.aws_lb_listener_rule.bookdetail_api'
terraform state mv aws_lb_listener_rule.ratings_api 'module.alb.aws_lb_listener_rule.ratings_api'

# Monitoring Module
terraform state mv aws_cloudwatch_log_group.search_api 'module.monitoring.aws_cloudwatch_log_group.search_api'
terraform state mv aws_cloudwatch_log_group.bookdetail_api 'module.monitoring.aws_cloudwatch_log_group.bookdetail_api'
terraform state mv aws_cloudwatch_log_group.ratings_api 'module.monitoring.aws_cloudwatch_log_group.ratings_api'

# ECS Module
terraform state mv aws_ecs_cluster.main 'module.ecs.aws_ecs_cluster.main'
terraform state mv aws_ecs_cluster_capacity_providers.main 'module.ecs.aws_ecs_cluster_capacity_providers.main'
terraform state mv aws_ecs_task_definition.search_api 'module.ecs.aws_ecs_task_definition.search_api'
terraform state mv aws_ecs_service.search_api 'module.ecs.aws_ecs_service.search_api'
terraform state mv aws_ecs_task_definition.bookdetail_api 'module.ecs.aws_ecs_task_definition.bookdetail_api'
terraform state mv aws_ecs_service.bookdetail_api 'module.ecs.aws_ecs_service.bookdetail_api'
terraform state mv aws_ecs_task_definition.ratings_api 'module.ecs.aws_ecs_task_definition.ratings_api'
terraform state mv aws_ecs_service.ratings_api 'module.ecs.aws_ecs_service.ratings_api'

echo "Migration complete! Running terraform plan to verify..."
terraform plan
```

## Troubleshooting

### Issue: Resources being recreated

**Solution**: Check resource naming. The new structure adds `-${environment}` suffix to many resources.

You may need to manually edit the state or accept the recreation.

### Issue: Module not found

**Solution**: Ensure you're in the correct directory:

```bash
cd infrastructure/environments/dev
terraform init
```

### Issue: State locking

**Solution**: 
```bash
terraform force-unlock <lock-id>
```

### Issue: Variable not defined

**Solution**: Ensure `terraform.tfvars` exists with all required variables.

## Rollback Plan

If migration fails:

```bash
# 1. Restore old state
cd infrastructure
cp terraform.tfstate.old terraform.tfstate

# 2. Restore old .tf files
cp old-structure/*.tf .

# 3. Reinitialize
terraform init -reconfigure

# 4. Verify
terraform plan
```

## Support

If you encounter issues:
1. Check the backup files
2. Review Terraform state with `terraform state list`
3. Use `terraform state show <resource>` to inspect resources
4. Consider starting fresh for non-production environments

## Recommended Approach

**For Development**: Use Option A (Fresh Start)
**For Production**: Use Option B (State Migration) or Option C (Import)

Always test the migration in a development environment first!

