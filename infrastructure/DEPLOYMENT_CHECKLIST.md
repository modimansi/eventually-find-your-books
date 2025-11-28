# 🚀 Deployment Checklist

Complete pre-deployment verification and step-by-step deployment guide.

## ✅ Pre-Deployment Checklist

### 1. Prerequisites Installed

```bash
# AWS CLI
aws --version  # Should be >= 2.x
aws sts get-caller-identity  # Verify credentials

# Terraform
terraform version  # Should be >= 1.3.0

# Docker
docker --version  # Should be >= 20.x
docker ps  # Verify Docker is running
```

**Status**: ⬜ Complete

---

### 2. AWS Credentials Configured

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Should return:
# - Account ID
# - User/Role ARN
# - No errors
```

**Required Permissions**:
- EC2 (VPC, Subnets, Security Groups)
- ECS (Cluster, Services, Tasks)
- ECR (Repositories)
- DynamoDB (Tables)
- IAM (Roles, Policies)
- CloudWatch (Logs)
- Elastic Load Balancing (ALB, Target Groups)

**Status**: ⬜ Complete

---

### 3. Project Files Present

```bash
# Verify directory structure
ls infrastructure/environments/dev/
# Should show: main.tf, variables.tf, outputs.tf, terraform.tfvars.example

ls infrastructure/modules/
# Should show: alb, database, ecr, ecs, iam, monitoring, networking, security

ls infrastructure/scripts/
# Should show: deploy-images.sh, init-environment.sh

ls services/
# Should show: search-api, bookdetail-api, ratings-api
```

**Status**: ⬜ Complete

---

### 4. Services Ready

Check each service has:

**Search API** (Go):
```bash
ls services/search-api/
# Required: Dockerfile, go.mod, cmd/api/main.go, internal/
```

**Book Detail API** (Go):
```bash
ls services/bookdetail-api/
# Required: Dockerfile, go.mod, cmd/api/main.go, internal/
```

**Ratings API** (Node.js):
```bash
ls services/ratings-api/
# Required: Dockerfile, package.json, cmd/api/main.js, internal/
```

**Status**: ⬜ Complete

---

### 5. Network Configuration

Verify you're not behind a restrictive firewall that blocks:
- Docker Hub (for pulling base images)
- AWS ECR (for pushing images)
- AWS services (for Terraform)

**Status**: ⬜ Complete

---

## 🏗️ Deployment Steps

### Step 1: Initialize Terraform (5 minutes)

```bash
cd infrastructure/environments/dev

# Initialize Terraform (downloads providers and modules)
terraform init

# Expected output:
# ✓ Module downloads
# ✓ Provider downloads
# ✓ Backend initialization
```

**Verify**:
```bash
ls -la .terraform/  # Should exist
ls .terraform.lock.hcl  # Should exist
```

**Status**: ⬜ Complete

---

### Step 2: Review Infrastructure Plan (2 minutes)

```bash
# Review what will be created
terraform plan

# Expected: ~60-80 resources to be created
# - VPC and networking (~15)
# - Security groups (~2)
# - DynamoDB tables (~3)
# - ECR repositories (~6)
# - IAM roles and policies (~8)
# - ALB and target groups (~8)
# - CloudWatch logs (~3)
# - ECS cluster and services (~10-15)
```

**Review checklist**:
- ⬜ No errors in plan
- ⬜ Resource names look correct
- ⬜ Regions are correct (us-west-2)
- ⬜ No unexpected deletions or replacements

**Status**: ⬜ Complete

---

### Step 3: Deploy Infrastructure (10-15 minutes)

```bash
# Apply the configuration
terraform apply

# Type 'yes' when prompted
```

**This will create**:
1. VPC with public/private subnets (2 AZs)
2. Internet Gateway and NAT Gateways
3. Security Groups
4. DynamoDB Tables (Books, Ratings, UserProfiles)
5. ECR Repositories (3)
6. IAM Roles
7. Application Load Balancer
8. CloudWatch Log Groups
9. ECS Cluster
10. ECS Services (will be in PENDING state until images are pushed)

**Watch for**:
- Any errors (red text)
- Successful resource creation (green text)
- Final output values

**Save outputs**:
```bash
terraform output > deployment-outputs.txt
```

**Status**: ⬜ Complete

---

### Step 4: Verify Infrastructure (2 minutes)

```bash
# Get important outputs
terraform output alb_url
terraform output ecs_cluster_name
terraform output ecr_search_api_url

# Verify in AWS Console (optional)
# - VPC exists
# - ECS cluster exists
# - DynamoDB tables exist
# - ECR repositories exist
```

**Expected ECS State**: 
- Services created but tasks not running (waiting for Docker images)

**Status**: ⬜ Complete

---

### Step 5: Build and Push Docker Images (5-10 minutes)

```bash
# Navigate to infrastructure root
cd ../..  # Should be in infrastructure/

# Make script executable (Linux/Mac only)
chmod +x scripts/deploy-images.sh

# Run deployment script
./scripts/deploy-images.sh dev

# Or on Windows PowerShell
bash scripts/deploy-images.sh dev
```

**This will**:
1. Login to ECR
2. Build search-api Docker image
3. Tag and push to ECR
4. Build bookdetail-api Docker image
5. Tag and push to ECR
6. Build ratings-api Docker image
7. Tag and push to ECR
8. Trigger ECS service updates

**Watch for**:
- ✓ marks for each successful step
- Docker build completing without errors
- Push to ECR succeeding
- ECS service update confirmation

**Status**: ⬜ Complete

---

### Step 6: Wait for Services to Start (3-5 minutes)

ECS will now pull images and start tasks.

```bash
# Monitor service status
cd environments/dev
CLUSTER=$(terraform output -raw ecs_cluster_name)

# Check all services
aws ecs describe-services \
  --cluster $CLUSTER \
  --services \
    book-recommendation-search-api-dev \
    book-recommendation-bookdetail-api-dev \
    book-recommendation-ratings-api-dev \
  --query "services[*].[serviceName,runningCount,desiredCount]" \
  --output table

# Repeat every 30 seconds until runningCount = desiredCount
```

**Expected progression**:
- Initial: runningCount = 0, desiredCount = 2
- After 1-2 min: runningCount = 1, desiredCount = 2
- After 3-5 min: runningCount = 2, desiredCount = 2 ✓

**If tasks fail to start**:
```bash
# Check CloudWatch logs
aws logs tail /ecs/book-recommendation/dev/search-api --since 10m
```

**Status**: ⬜ Complete

---

### Step 7: Test Deployment (5 minutes)

```bash
# Get ALB URL
export ALB_URL=$(terraform output -raw alb_url)
echo "Testing: $ALB_URL"

# Wait a moment for ALB to register targets
sleep 30
```

#### Test 1: Search API Health Check
```bash
curl $ALB_URL/search/healthz

# Expected: "ok" with 200 status
```

#### Test 2: Book Detail API Health Check
```bash
curl $ALB_URL/books/healthz

# Expected: "ok" with 200 status
```

#### Test 3: Search API Query
```bash
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query":"gatsby","limit":5}'

# Expected: JSON response with books (may be empty if no data loaded)
```

#### Test 4: Book Detail API (using test data)
```bash
curl $ALB_URL/books/OL1000046W

# Expected: JSON with book details or 404 if not found
```

#### Test 5: Ratings API Health Check
```bash
curl $ALB_URL/healthz

# Expected: "ok" with 200 status
```

#### Test 6: Ratings API - Rate a book
```bash
curl -X POST $ALB_URL/books/OL1000046W/rate \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test123","rating":5}'

# Expected: {"message": "Rating added successfully"}
```

#### Test 7: Ratings API - Get ratings
```bash
curl $ALB_URL/books/OL1000046W/ratings

# Expected: Array of ratings
```

**Test Results**:
- ⬜ Search API Health: Pass
- ⬜ Book Detail API Health: Pass
- ⬜ Ratings API Health: Pass
- ⬜ Search API Query: Pass
- ⬜ Book Detail API: Pass
- ⬜ Rate a Book: Pass
- ⬜ Get Ratings: Pass

**Status**: ⬜ Complete

---

### Step 8: Load Sample Data (Optional, 5 minutes)

```bash
# Load books into DynamoDB
cd ../../../scripts
python load_books_to_dynamodb.py

# Retest search after data load
curl -X POST $ALB_URL/search \
  -H "Content-Type: application/json" \
  -d '{"query":"harry potter","limit":5}'

# Should now return results
```

**Status**: ⬜ Complete

---

## 📊 Post-Deployment Verification

### 1. Check ECS Service Health

```bash
cd infrastructure/environments/dev
CLUSTER=$(terraform output -raw ecs_cluster_name)

aws ecs describe-services \
  --cluster $CLUSTER \
  --services book-recommendation-search-api-dev \
  --query "services[0].{Name:serviceName,Desired:desiredCount,Running:runningCount,Status:status}" \
  --output table
```

**Expected**: Running = Desired, Status = ACTIVE

**Status**: ⬜ Complete

---

### 2. Check Target Health

```bash
# Get target group ARN from Terraform
TG_ARN=$(terraform output -raw search_api_target_group_arn 2>/dev/null || echo "")

if [ -n "$TG_ARN" ]; then
  aws elbv2 describe-target-health --target-group-arn $TG_ARN
fi
```

**Expected**: All targets "healthy"

**Status**: ⬜ Complete

---

### 3. Monitor CloudWatch Logs

```bash
# Tail logs for each service
aws logs tail /ecs/book-recommendation/dev/search-api --follow &
aws logs tail /ecs/book-recommendation/dev/bookdetail-api --follow &
aws logs tail /ecs/book-recommendation/dev/ratings-api --follow &

# Press Ctrl+C to stop
```

**Look for**:
- ⬜ No error messages
- ⬜ Services listening on correct ports
- ⬜ Successful requests being logged

**Status**: ⬜ Complete

---

## 💰 Cost Verification

```bash
# Check running resources
aws ecs list-tasks --cluster $CLUSTER
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
aws elbv2 describe-load-balancers

# Expected monthly cost: ~$120-140
# - ECS Fargate (6 tasks): ~$30
# - ALB: ~$16
# - NAT Gateways (2): ~$64
# - DynamoDB: ~$5-25
# - Other: ~$5
```

**Status**: ⬜ Complete

---

## 🔧 Troubleshooting

### Issue: Terraform init fails

**Solution**:
```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Issue: Services won't start

**Check logs**:
```bash
aws logs tail /ecs/book-recommendation/dev/search-api --since 15m
```

**Common causes**:
- Image not found in ECR → Rerun deploy-images.sh
- Port conflicts → Check Dockerfile EXPOSE matches variables.tf
- IAM permissions → Check task role has DynamoDB access

### Issue: Can't access ALB

**Wait**: ALB can take 2-3 minutes to register healthy targets

**Check**:
```bash
# Verify ALB exists
aws elbv2 describe-load-balancers --names book-recommendation-alb-dev

# Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

### Issue: Docker build fails

**Check**:
- Docker daemon is running
- Enough disk space
- go.mod/package.json are correct

---

## 🎉 Success Criteria

All items below should be ✓:

- ⬜ Infrastructure deployed without errors
- ⬜ All ECS services running (runningCount = desiredCount)
- ⬜ All health checks returning 200 OK
- ⬜ Can search for books
- ⬜ Can get book details
- ⬜ Can rate books
- ⬜ CloudWatch logs show successful requests
- ⬜ No errors in logs

---

## 📞 Support

If you encounter issues:

1. **Check CloudWatch Logs** first
2. **Review Terraform plan** for unexpected changes
3. **Verify AWS credentials** and permissions
4. **Check service events** in ECS console
5. **Review** `STRUCTURE.md` for architecture
6. **Check** `README.md` for detailed module docs

---

## 🧹 Cleanup (When Done)

```bash
cd infrastructure/environments/dev
terraform destroy -auto-approve
```

**This will delete**:
- All ECS services and tasks
- ECR repositories (and images)
- ALB and target groups
- DynamoDB tables (and data)
- VPC and networking
- All other resources

**Cost savings**: ~$120-140/month

---

## 📝 Deployment Log

| Date | Time | Action | Status | Notes |
|------|------|--------|--------|-------|
| | | Terraform Init | | |
| | | Terraform Apply | | |
| | | Docker Build/Push | | |
| | | Services Started | | |
| | | Tests Passed | | |
| | | Data Loaded | | |

---

## Next Steps After Deployment

1. ✅ Load production data into DynamoDB
2. ✅ Configure custom domain
3. ✅ Add HTTPS/TLS certificate
4. ✅ Set up monitoring and alerts
5. ✅ Configure auto-scaling
6. ✅ Create production environment
7. ✅ Set up CI/CD pipeline
8. ✅ Add API documentation

---

**Ready to deploy?** Start with Step 1! 🚀

