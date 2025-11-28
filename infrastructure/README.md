# Infrastructure

This directory contains Terraform configuration for deploying the Book Recommendation System on AWS.

## Directory Structure

```
infrastructure/
├── environments/               # Environment-specific configurations
│   ├── dev/                   # Development environment
│   │   ├── main.tf           # Main configuration calling modules
│   │   ├── variables.tf      # Environment variables
│   │   ├── outputs.tf        # Output values
│   │   └── terraform.tfvars.example  # Example variables file
│   └── prod/                  # Production environment (template)
│       └── ...
├── modules/                   # Reusable Terraform modules
│   ├── networking/           # VPC, subnets, NAT gateways
│   ├── security/             # Security groups
│   ├── database/             # DynamoDB tables
│   ├── ecr/                  # Container registries
│   ├── iam/                  # IAM roles and policies
│   ├── alb/                  # Application Load Balancer
│   ├── monitoring/           # CloudWatch logs
│   └── ecs/                  # ECS cluster and services
├── scripts/                   # Deployment and utility scripts
│   ├── deploy-images.sh      # Build and push Docker images
│   └── init-environment.sh   # Initialize new environment
├── .gitignore                # Git ignore patterns
└── README.md                 # This file
```

## Architecture

The infrastructure creates:

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: Routes traffic to services based on path patterns
- **ECR**: Container image repositories
- **DynamoDB**: NoSQL database tables
- **CloudWatch**: Centralized logging
- **IAM**: Roles and policies for secure access

## Prerequisites

1. **AWS CLI** configured:
   ```bash
   aws configure
   ```

2. **Terraform** installed (>= 1.3.0):
   ```bash
   terraform version
   ```

3. **Docker** installed

## Quick Start

### 1. Initialize Infrastructure

```bash
# Navigate to the dev environment
cd infrastructure/environments/dev

# Copy example variables (optional, if you want to customize)
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### 2. Build and Deploy Docker Images

```bash
# From the infrastructure directory
cd ../..  # Back to infrastructure root
./scripts/deploy-images.sh dev
```

Or specify region and account:
```bash
./scripts/deploy-images.sh dev us-west-2 123456789012
```

### 3. Get Service Endpoints

```bash
cd environments/dev
terraform output alb_url
```

## Module Documentation

### Networking Module

Creates VPC, subnets, NAT gateways, and route tables.

**Inputs:**
- `project_name`: Project name for tagging
- `environment`: Environment name (dev/prod)
- `vpc_cidr`: CIDR block for VPC
- `availability_zones`: List of AZs to use

**Outputs:**
- `vpc_id`: VPC ID
- `public_subnet_ids`: Public subnet IDs
- `private_subnet_ids`: Private subnet IDs

### Security Module

Creates security groups for ALB and ECS tasks.

**Inputs:**
- `project_name`: Project name
- `environment`: Environment name
- `vpc_id`: VPC ID

**Outputs:**
- `alb_security_group_id`: ALB security group ID
- `ecs_tasks_security_group_id`: ECS tasks security group ID

### Database Module

Creates DynamoDB tables for Books, Ratings, and UserProfiles.

**Inputs:**
- `project_name`: Project name
- `environment`: Environment name

**Outputs:**
- `books_table_name`: Books table name
- `books_table_arn`: Books table ARN
- `ratings_table_name`: Ratings table name
- `ratings_table_arn`: Ratings table ARN
- `user_profiles_table_name`: UserProfiles table name
- `user_profiles_table_arn`: UserProfiles table ARN

### ECR Module

Creates ECR repositories for each service.

**Inputs:**
- `project_name`: Project name
- `environment`: Environment name

**Outputs:**
- `search_api_repository_url`: Search API repository URL
- `bookdetail_api_repository_url`: Book Detail API repository URL
- `ratings_api_repository_url`: Ratings API repository URL

### IAM Module

Creates IAM roles and policies for ECS tasks.

**Inputs:**
- `project_name`: Project name
- `environment`: Environment name
- `books_table_arn`: ARN of Books table
- `ratings_table_arn`: ARN of Ratings table
- `user_profiles_table_arn`: ARN of UserProfiles table

**Outputs:**
- `task_execution_role_arn`: Task execution role ARN
- `task_role_arn`: Task role ARN

### ALB Module

Creates Application Load Balancer with path-based routing.

**Inputs:**
- `project_name`: Project name
- `environment`: Environment name
- `vpc_id`: VPC ID
- `public_subnet_ids`: Public subnet IDs
- `alb_security_group_id`: ALB security group ID
- Service ports for each API

**Outputs:**
- `alb_dns_name`: ALB DNS name
- `alb_arn`: ALB ARN
- `http_listener_arn`: HTTP listener ARN
- Target group ARNs for each service

### Monitoring Module

Creates CloudWatch log groups for services.

**Inputs:**
- `project_name`: Project name
- `environment`: Environment name
- `log_retention_days`: Number of days to retain logs (default: 7)

**Outputs:**
- Log group names for each service

### ECS Module

Creates ECS cluster, task definitions, and services.

**Inputs:**
- All configuration from other modules
- Service-specific CPU, memory, and desired count

**Outputs:**
- `cluster_name`: ECS cluster name
- `cluster_arn`: ECS cluster ARN
- Service names for each API

## Environment Configuration

### Development Environment

Located in `environments/dev/`, optimized for cost with:
- 2 tasks per service
- Smaller CPU/memory allocations
- 7-day log retention

### Production Environment

To create a production environment:

```bash
# Copy dev to prod
cp -r environments/dev environments/prod

# Edit environments/prod/main.tf
# Update:
# - environment = "prod"
# - Increase desired_count
# - Increase CPU/memory allocations
# - Update log retention

# Edit environments/prod/terraform.tfvars
# Update all values for production
```

## Testing the Deployment

```bash
# Get the ALB URL
cd environments/dev
export ALB_URL=$(terraform output -raw alb_url)

# Test Search API
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query": "harry potter", "limit": 10}'

# Test Book Detail API
curl $ALB_URL/books/OL1000046W

# Test Ratings API
curl -X POST $ALB_URL/books/OL1000046W/rate \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user123", "rating": 5}'
```

## Monitoring

### View Logs

```bash
# Search API
aws logs tail /ecs/book-recommendation/dev/search-api --follow

# Book Detail API
aws logs tail /ecs/book-recommendation/dev/bookdetail-api --follow

# Ratings API
aws logs tail /ecs/book-recommendation/dev/ratings-api --follow
```

### Check Service Health

```bash
# Get cluster name
cd environments/dev
CLUSTER=$(terraform output -raw ecs_cluster_name)

# List services
aws ecs list-services --cluster $CLUSTER

# Describe service
aws ecs describe-services \
  --cluster $CLUSTER \
  --services book-recommendation-search-api-dev
```

## Updating Services

After making code changes:

```bash
# From infrastructure root
./scripts/deploy-images.sh dev

# Or manually for one service
cd environments/dev
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw search_api_service_name)

aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment
```

## Cost Optimization

### Development Environment

1. **Reduce task counts**:
   ```hcl
   search_api_desired_count = 1
   bookdetail_api_desired_count = 1
   ratings_api_desired_count = 1
   ```

2. **Use smaller resources**:
   ```hcl
   search_api_cpu = 256
   search_api_memory = 512
   ```

3. **Single AZ**:
   ```hcl
   availability_zones = ["us-west-2a"]
   ```

### Production Environment

1. Enable auto-scaling
2. Use FARGATE_SPOT for non-critical tasks
3. Add VPC endpoints for AWS services
4. Enable CloudWatch alarms

## Cleanup

⚠️ **Warning**: This will delete all resources!

```bash
cd environments/dev
terraform destroy
```

## Adding a New Environment

```bash
# Copy dev environment
cp -r environments/dev environments/staging

# Update environment-specific values
cd environments/staging
# Edit main.tf, variables.tf, terraform.tfvars

# Initialize and apply
terraform init
terraform apply
```

## Troubleshooting

### Module Not Found

If you see "Module not found" errors:

```bash
cd environments/dev
terraform init -upgrade
```

### Service Won't Start

1. Check ECS task logs in CloudWatch
2. Verify ECR images exist
3. Check IAM permissions
4. Verify security group rules

### Can't Access Services

1. Check ALB target health
2. Verify security group rules
3. Ensure tasks are in private subnets with NAT
4. Check route table configurations

## Best Practices

1. **Always use workspaces or separate state files for different environments**
2. **Never commit `terraform.tfvars` with sensitive data**
3. **Use remote state backend (S3 + DynamoDB) for team collaboration**
4. **Tag all resources appropriately**
5. **Enable MFA for production deployments**
6. **Use Terraform Cloud or Atlantis for automated deployments**

## Next Steps

1. Add auto-scaling policies
2. Add HTTPS/TLS with ACM
3. Add WAF for security
4. Add CloudFront for caching
5. Implement blue-green deployments
6. Add monitoring and alerting
7. Set up CI/CD pipeline

## Support

For issues:
- Check module documentation
- Review CloudWatch logs
- Verify IAM permissions
- Check security groups

## Contributing

When adding new modules:
1. Create module directory under `modules/`
2. Include `main.tf`, `variables.tf`, `outputs.tf`
3. Add documentation in module README
4. Test in dev environment first
5. Update this README
