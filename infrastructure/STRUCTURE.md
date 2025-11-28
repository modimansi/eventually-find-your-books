# Infrastructure Structure Overview

This document provides a comprehensive overview of the infrastructure directory structure.

## Directory Tree

```
infrastructure/
│
├── environments/                    # Environment-specific configurations
│   ├── dev/                        # Development environment
│   │   ├── main.tf                # Main entry point (calls all modules)
│   │   ├── variables.tf           # Variable declarations
│   │   ├── outputs.tf             # Output values
│   │   ├── terraform.tfvars       # Variable values (gitignored)
│   │   └── terraform.tfvars.example  # Example values
│   │
│   └── prod/                       # Production environment (template)
│       └── (same structure as dev)
│
├── modules/                        # Reusable Terraform modules
│   │
│   ├── networking/                # VPC, Subnets, NAT Gateways
│   │   ├── main.tf               # Resource definitions
│   │   ├── variables.tf          # Input variables
│   │   └── outputs.tf            # Output values
│   │
│   ├── security/                  # Security Groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── database/                  # DynamoDB Tables
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecr/                       # Container Registries
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam/                       # IAM Roles and Policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/                       # Application Load Balancer
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── monitoring/                # CloudWatch Logs
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── ecs/                       # ECS Cluster and Services
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── scripts/                        # Utility scripts
│   ├── deploy-images.sh           # Build and push Docker images
│   └── init-environment.sh        # Create new environment
│
├── .gitignore                     # Git ignore patterns
├── README.md                      # Main documentation
├── MIGRATION.md                   # Migration guide
└── STRUCTURE.md                   # This file
```

## Module Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                         environments/dev/                    │
│                           main.tf                           │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
  ┌──────────┐          ┌──────────┐
  │networking│          │ security │
  └────┬─────┘          └────┬─────┘
       │                     │
       └──────────┬──────────┘
                  │
       ┌──────────┼──────────┬──────────┬──────────┐
       │          │          │          │          │
       ▼          ▼          ▼          ▼          ▼
  ┌────────┐ ┌─────┐   ┌─────┐   ┌─────┐   ┌────────┐
  │database│ │ ecr │   │ iam │   │ alb │   │monitor │
  └────┬───┘ └──┬──┘   └──┬──┘   └──┬──┘   └───┬────┘
       │        │         │         │          │
       └────────┴─────────┴─────────┴──────────┘
                          │
                          ▼
                     ┌────────┐
                     │  ecs   │
                     └────────┘
```

## Module Descriptions

### 1. Networking Module
**Purpose**: Creates VPC and network infrastructure

**Resources**:
- VPC with DNS support
- Public subnets (2 AZs)
- Private subnets (2 AZs)
- Internet Gateway
- NAT Gateways (one per AZ)
- Route Tables and associations

**Outputs**: VPC ID, subnet IDs

---

### 2. Security Module
**Purpose**: Manages security groups

**Resources**:
- ALB security group (HTTP/HTTPS ingress)
- ECS tasks security group (ALB → tasks)

**Outputs**: Security group IDs

---

### 3. Database Module
**Purpose**: Creates DynamoDB tables

**Resources**:
- Books table (with GSIs for search)
- Ratings table (with GSI for book queries)
- UserProfiles table

**Outputs**: Table names and ARNs

---

### 4. ECR Module
**Purpose**: Container image repositories

**Resources**:
- Search API repository
- Book Detail API repository
- Ratings API repository
- Lifecycle policies

**Outputs**: Repository URLs

---

### 5. IAM Module
**Purpose**: IAM roles and policies

**Resources**:
- ECS task execution role
- ECS task role
- DynamoDB access policy
- CloudWatch Logs policy

**Outputs**: Role ARNs

---

### 6. ALB Module
**Purpose**: Application Load Balancer setup

**Resources**:
- Application Load Balancer
- Target groups (one per service)
- HTTP listener
- Path-based routing rules

**Routing**:
- `/search*` → Search API
- `/books*` → Book Detail API
- `/users/*` → Ratings API

**Outputs**: ALB DNS, target group ARNs

---

### 7. Monitoring Module
**Purpose**: CloudWatch log groups

**Resources**:
- Log group for each service
- Configurable retention period

**Outputs**: Log group names

---

### 8. ECS Module
**Purpose**: Container orchestration

**Resources**:
- ECS Cluster (Fargate)
- Task definitions (one per service)
- ECS services (one per API)
- Auto-scaling ready

**Outputs**: Cluster info, service names

---

## Data Flow

### 1. User Request Flow
```
User Request
    ↓
Internet Gateway
    ↓
Application Load Balancer (Public Subnet)
    ↓
Path-based routing
    ├─→ /search*     → Search API (Private Subnet)
    ├─→ /books*      → Book Detail API (Private Subnet)
    └─→ /users/*     → Ratings API (Private Subnet)
            ↓
        ECS Tasks
            ↓
        DynamoDB
```

### 2. Service Deployment Flow
```
Developer
    ↓
docker build
    ↓
docker push → ECR
    ↓
ECS Service Update
    ↓
Pull new image
    ↓
Rolling deployment
```

### 3. Logging Flow
```
ECS Tasks
    ↓
CloudWatch Logs
    ↓
Log Groups (per service)
    ↓
Retention (7 days default)
```

## Resource Naming Convention

All resources follow this pattern:
```
{project_name}-{resource-type}-{environment}
```

Examples:
- `book-recommendation-cluster-dev`
- `book-recommendation-search-api-dev`
- `book-recommendation-books-dev`

## Environment Management

### Creating a New Environment

```bash
# Option 1: Use init script
./scripts/init-environment.sh staging

# Option 2: Manual copy
cp -r environments/dev environments/staging
cd environments/staging
# Edit terraform.tfvars
terraform init
terraform apply
```

### Environment Differences

| Aspect | Dev | Prod |
|--------|-----|------|
| Task Count | 1-2 | 3-5 |
| CPU/Memory | Small | Large |
| Log Retention | 7 days | 30 days |
| AZs | 2 | 3 |
| Auto-scaling | No | Yes |

## Common Operations

### Deploy Infrastructure
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Deploy Services
```bash
cd infrastructure
./scripts/deploy-images.sh dev
```

### View Logs
```bash
aws logs tail /ecs/book-recommendation/dev/search-api --follow
```

### Scale Services
```bash
# Edit terraform.tfvars
search_api_desired_count = 5

# Apply changes
terraform apply
```

### Update Service
```bash
# After code changes
./scripts/deploy-images.sh dev

# Or specific service
cd environments/dev
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw search_api_service_name)

aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment
```

## State Management

### Local State (Current)
```
environments/dev/terraform.tfstate
environments/prod/terraform.tfstate
```

### Remote State (Recommended)
```hcl
# Add to environments/*/main.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "book-recommendation/dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

## Security Best Practices

1. **Never commit** `terraform.tfvars`
2. **Use remote state** with encryption
3. **Enable MFA** for production
4. **Rotate credentials** regularly
5. **Use IAM roles** instead of keys
6. **Enable CloudTrail** for audit
7. **Review security groups** regularly
8. **Enable encryption** at rest

## Cost Optimization

### Development
- Use FARGATE_SPOT
- Reduce task counts to 1
- Use single AZ
- Reduce CPU/memory
- Shorter log retention

### Production
- Right-size resources
- Use auto-scaling
- Reserved capacity
- VPC endpoints
- CloudWatch metrics

## Monitoring and Alerts

### Current Monitoring
- CloudWatch Logs
- ECS Container Insights
- ALB metrics

### Recommended Additions
- CloudWatch Alarms
- SNS notifications
- X-Ray tracing
- Custom metrics
- Dashboards

## Backup and Recovery

### State Backup
```bash
# Automated (use S3 versioning)
terraform {
  backend "s3" {
    bucket = "terraform-state"
    versioning = true
  }
}

# Manual
cp terraform.tfstate terraform.tfstate.backup
```

### Disaster Recovery
1. State files backed up
2. DynamoDB point-in-time recovery enabled
3. ECR images retained (lifecycle policy)
4. Infrastructure as code (reproducible)

## Troubleshooting

### Common Issues

**Issue**: Module not found
```bash
# Solution
terraform init -upgrade
```

**Issue**: State locked
```bash
# Solution
terraform force-unlock <lock-id>
```

**Issue**: Resource already exists
```bash
# Solution
terraform import module.name.resource <resource-id>
```

## Next Steps

1. ✅ Set up remote state backend
2. ✅ Add production environment
3. ✅ Configure auto-scaling
4. ✅ Add CloudWatch alarms
5. ✅ Implement CI/CD
6. ✅ Add HTTPS/TLS
7. ✅ Add WAF rules
8. ✅ Add CloudFront

## References

- [Terraform Modules Best Practices](https://www.terraform.io/docs/language/modules/develop/index.html)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

