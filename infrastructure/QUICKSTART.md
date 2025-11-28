# Quick Start Guide

Get your infrastructure up and running in minutes!

## Prerequisites Check

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Terraform
terraform version

# Check Docker
docker --version
```

## 🚀 Deploy Infrastructure (5 minutes)

```bash
# 1. Navigate to dev environment
cd infrastructure/environments/dev

# 2. Initialize Terraform
terraform init

# 3. (Optional) Customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed

# 4. Review what will be created
terraform plan

# 5. Deploy!
terraform apply -auto-approve
```

## 🐳 Deploy Services (3 minutes)

```bash
# From infrastructure directory
cd ../..
./scripts/deploy-images.sh dev
```

## ✅ Test Deployment (1 minute)

```bash
# Get ALB URL
cd environments/dev
export ALB_URL=$(terraform output -raw alb_url)

# Test Search API
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query":"harry potter","limit":5}'

# Test Book Detail API
curl $ALB_URL/books/OL1000046W

# Test Ratings API
curl -X POST $ALB_URL/books/OL1000046W/rate \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test123","rating":5}'
```

## 📊 View Logs

```bash
# Search API logs
aws logs tail /ecs/book-recommendation/dev/search-api --follow

# Book Detail API logs
aws logs tail /ecs/book-recommendation/dev/bookdetail-api --follow

# Ratings API logs
aws logs tail /ecs/book-recommendation/dev/ratings-api --follow
```

## 🔄 Update Services

```bash
# After code changes, rebuild and redeploy
cd infrastructure
./scripts/deploy-images.sh dev
```

## 🗑️ Clean Up

```bash
cd infrastructure/environments/dev
terraform destroy -auto-approve
```

## 📁 Directory Structure

```
infrastructure/
├── environments/dev/    ← Work here for dev
├── modules/            ← Don't modify (reusable)
├── scripts/            ← Helper scripts
└── README.md           ← Full documentation
```

## 🎯 Common Commands

### Check Service Status
```bash
cd environments/dev
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs describe-services --cluster $CLUSTER --services \
  book-recommendation-search-api-dev \
  book-recommendation-bookdetail-api-dev \
  book-recommendation-ratings-api-dev
```

### Scale Services
```bash
# Edit terraform.tfvars
search_api_desired_count = 3

# Apply
terraform apply
```

### View All Outputs
```bash
terraform output
```

## 🆘 Troubleshooting

### Services Won't Start
```bash
# Check logs
aws logs tail /ecs/book-recommendation/dev/search-api --since 10m

# Check service events
aws ecs describe-services --cluster <cluster-name> --services <service-name>
```

### Can't Access ALB
```bash
# Verify ALB is active
terraform output alb_dns_name

# Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

### Module Not Found
```bash
terraform init -upgrade
```

## 📚 Documentation

- **README.md**: Full documentation
- **STRUCTURE.md**: Architecture overview
- **MIGRATION.md**: Migrate from old structure

## 💡 Tips

1. **Always work in** `environments/dev/` directory
2. **Use** `terraform plan` before `apply`
3. **Check logs** if services fail to start
4. **Wait 2-3 minutes** after deployment for services to be ready
5. **Save costs**: Destroy when not in use

## 🎓 Next Steps

1. Load sample data into DynamoDB
2. Configure custom domain
3. Add HTTPS/TLS
4. Set up monitoring alerts
5. Create production environment

## 🔗 Quick Links

| Resource | Location |
|----------|----------|
| Main Config | `environments/dev/main.tf` |
| Variables | `environments/dev/terraform.tfvars` |
| Deploy Script | `scripts/deploy-images.sh` |
| Modules | `modules/` |

## 💰 Cost Estimate

Development environment: ~$120-140/month
- ECS Fargate: ~$30
- ALB: ~$16
- NAT Gateways: ~$64
- DynamoDB: ~$5-25
- Other: ~$5

**Tip**: Run `terraform destroy` when not in use to save costs!

