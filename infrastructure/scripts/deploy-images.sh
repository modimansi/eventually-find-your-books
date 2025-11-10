#!/bin/bash

# Deploy Docker images to ECR
# Usage: ./deploy-images.sh [environment] [aws-region] [aws-account-id]

set -e

# Save the actual script directory location FIRST (before any cd commands)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${2:-us-west-2}
AWS_ACCOUNT_ID=${3:-$(aws sts get-caller-identity --query Account --output text)}
PROJECT_NAME="book-recommendation"

echo "======================================"
echo "Deploying Docker Images to ECR"
echo "======================================"
echo "Environment: $ENVIRONMENT"
echo "AWS Region: $AWS_REGION"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Get ECR repository URLs from Terraform outputs
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/environments/$ENVIRONMENT"

if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "Error: Environment directory not found: $TERRAFORM_DIR"
  exit 1
fi

cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfstate" ]; then
  echo "Error: terraform.tfstate not found. Please run 'terraform apply' first."
  exit 1
fi

echo ""
echo "Getting ECR repository URLs from Terraform..."
SEARCH_API_REPO=$(terraform output -raw ecr_search_api_url 2>/dev/null || echo "")
BOOKDETAIL_API_REPO=$(terraform output -raw ecr_bookdetail_api_url 2>/dev/null || echo "")
RATINGS_API_REPO=$(terraform output -raw ecr_ratings_api_url 2>/dev/null || echo "")

if [ -z "$SEARCH_API_REPO" ] || [ -z "$BOOKDETAIL_API_REPO" ] || [ -z "$RATINGS_API_REPO" ]; then
  echo "Warning: Could not get repository URLs from Terraform. Using defaults..."
  SEARCH_API_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME/search-api"
  BOOKDETAIL_API_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME/bookdetail-api"
  RATINGS_API_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME/ratings-api"
fi

echo "Search API Repository: $SEARCH_API_REPO"
echo "Book Detail API Repository: $BOOKDETAIL_API_REPO"
echo "Ratings API Repository: $RATINGS_API_REPO"

# Navigate to services directory using the saved project root
echo ""
echo "Navigating to services directory..."
cd "$PROJECT_ROOT/services" || {
    echo "Error: Could not find services directory"
    echo "Project root: $PROJECT_ROOT"
    echo "Looking for: $PROJECT_ROOT/services"
    ls -la "$PROJECT_ROOT"
    exit 1
}

# Build and push Search API
echo ""
echo "======================================"
echo "Building and pushing Search API..."
echo "======================================"
cd search-api
docker build -t $PROJECT_NAME/search-api:latest .
docker tag $PROJECT_NAME/search-api:latest $SEARCH_API_REPO:latest
docker push $SEARCH_API_REPO:latest
echo "✓ Search API deployed successfully"

# Build and push Book Detail API
echo ""
echo "======================================"
echo "Building and pushing Book Detail API..."
echo "======================================"
cd ../bookdetail-api
docker build -t $PROJECT_NAME/bookdetail-api:latest .
docker tag $PROJECT_NAME/bookdetail-api:latest $BOOKDETAIL_API_REPO:latest
docker push $BOOKDETAIL_API_REPO:latest
echo "✓ Book Detail API deployed successfully"

# Build and push Ratings API
echo ""
echo "======================================"
echo "Building and pushing Ratings API..."
echo "======================================"
cd ../ratings-api
docker build -t $PROJECT_NAME/ratings-api:latest .
docker tag $PROJECT_NAME/ratings-api:latest $RATINGS_API_REPO:latest
docker push $RATINGS_API_REPO:latest
echo "✓ Ratings API deployed successfully"

# Force ECS to redeploy services
echo ""
echo "======================================"
echo "Updating ECS services..."
echo "======================================"

cd "$TERRAFORM_DIR"
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "$PROJECT_NAME-cluster-$ENVIRONMENT")

echo "Updating search-api service..."
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $PROJECT_NAME-search-api-$ENVIRONMENT \
  --force-new-deployment \
  --region $AWS_REGION \
  --no-cli-pager > /dev/null 2>&1 || echo "Warning: Could not update search-api service"

echo "Updating bookdetail-api service..."
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $PROJECT_NAME-bookdetail-api-$ENVIRONMENT \
  --force-new-deployment \
  --region $AWS_REGION \
  --no-cli-pager > /dev/null 2>&1 || echo "Warning: Could not update bookdetail-api service"

echo "Updating ratings-api service..."
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $PROJECT_NAME-ratings-api-$ENVIRONMENT \
  --force-new-deployment \
  --region $AWS_REGION \
  --no-cli-pager > /dev/null 2>&1 || echo "Warning: Could not update ratings-api service"

echo ""
echo "======================================"
echo "✓ All services deployed successfully!"
echo "======================================"
echo ""
echo "Services are updating. This may take a few minutes."
echo "You can check the status with:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $PROJECT_NAME-search-api-$ENVIRONMENT --region $AWS_REGION"
echo ""
echo "Application Load Balancer URL:"
terraform output alb_url 2>/dev/null || echo "Run 'cd environments/$ENVIRONMENT && terraform output alb_url' to get the URL"

