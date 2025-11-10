#!/bin/bash

# Initialize a new environment
# Usage: ./init-environment.sh <environment-name>

set -e

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: ./init-environment.sh <environment-name>"
  echo "Example: ./init-environment.sh staging"
  exit 1
fi

SCRIPT_DIR="$(dirname "$0")"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

if [ -d "$ENV_DIR" ]; then
  echo "Error: Environment '$ENVIRONMENT' already exists at $ENV_DIR"
  exit 1
fi

echo "Creating new environment: $ENVIRONMENT"
echo ""

# Create environment directory
mkdir -p "$ENV_DIR"

# Create main.tf
cat > "$ENV_DIR/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
module "networking" {
  source = "../../modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# Security Groups
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

# DynamoDB Tables
module "database" {
  source = "../../modules/database"

  project_name = var.project_name
  environment  = var.environment
}

# ECR Repositories
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# IAM Roles and Policies
module "iam" {
  source = "../../modules/iam"

  project_name             = var.project_name
  environment              = var.environment
  books_table_arn          = module.database.books_table_arn
  ratings_table_arn        = module.database.ratings_table_arn
  user_profiles_table_arn  = module.database.user_profiles_table_arn
}

# Application Load Balancer
module "alb" {
  source = "../../modules/alb"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.networking.vpc_id
  public_subnet_ids    = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  search_api_port      = var.search_api_port
  bookdetail_api_port  = var.bookdetail_api_port
  ratings_api_port     = var.ratings_api_port
}

# CloudWatch Log Groups
module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
}

# ECS Cluster and Services
module "ecs" {
  source = "../../modules/ecs"

  project_name                  = var.project_name
  environment                   = var.environment
  aws_region                    = var.aws_region
  
  # Networking
  vpc_id                        = module.networking.vpc_id
  private_subnet_ids            = module.networking.private_subnet_ids
  ecs_tasks_security_group_id   = module.security.ecs_tasks_security_group_id
  
  # IAM
  task_execution_role_arn       = module.iam.task_execution_role_arn
  task_role_arn                 = module.iam.task_role_arn
  
  # ECR
  search_api_repository_url     = module.ecr.search_api_repository_url
  bookdetail_api_repository_url = module.ecr.bookdetail_api_repository_url
  ratings_api_repository_url    = module.ecr.ratings_api_repository_url
  
  # ALB
  search_api_target_group_arn   = module.alb.search_api_target_group_arn
  bookdetail_api_target_group_arn = module.alb.bookdetail_api_target_group_arn
  ratings_api_target_group_arn  = module.alb.ratings_api_target_group_arn
  alb_listener_arn              = module.alb.http_listener_arn
  
  # CloudWatch
  search_api_log_group_name     = module.monitoring.search_api_log_group_name
  bookdetail_api_log_group_name = module.monitoring.bookdetail_api_log_group_name
  ratings_api_log_group_name    = module.monitoring.ratings_api_log_group_name
  
  # DynamoDB
  books_table_name              = module.database.books_table_name
  ratings_table_name            = module.database.ratings_table_name
  
  # Service Configuration
  search_api_port               = var.search_api_port
  search_api_cpu                = var.search_api_cpu
  search_api_memory             = var.search_api_memory
  search_api_desired_count      = var.search_api_desired_count
  
  bookdetail_api_port           = var.bookdetail_api_port
  bookdetail_api_cpu            = var.bookdetail_api_cpu
  bookdetail_api_memory         = var.bookdetail_api_memory
  bookdetail_api_desired_count  = var.bookdetail_api_desired_count
  
  ratings_api_port              = var.ratings_api_port
  ratings_api_cpu               = var.ratings_api_cpu
  ratings_api_memory            = var.ratings_api_memory
  ratings_api_desired_count     = var.ratings_api_desired_count
}
EOF

# Copy variables.tf from dev
cp "$SCRIPT_DIR/../environments/dev/variables.tf" "$ENV_DIR/variables.tf"

# Copy outputs.tf from dev
cp "$SCRIPT_DIR/../environments/dev/outputs.tf" "$ENV_DIR/outputs.tf"

# Create terraform.tfvars with environment-specific values
cat > "$ENV_DIR/terraform.tfvars" <<EOF
# $ENVIRONMENT environment configuration

project_name = "book-recommendation"
environment  = "$ENVIRONMENT"
aws_region   = "us-west-2"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

search_api_port      = 8080
bookdetail_api_port  = 8081
ratings_api_port     = 3000

# Adjust these values based on environment needs
search_api_cpu    = 512
search_api_memory = 1024
search_api_desired_count = 2

bookdetail_api_cpu    = 512
bookdetail_api_memory = 1024
bookdetail_api_desired_count = 2

ratings_api_cpu    = 256
ratings_api_memory = 512
ratings_api_desired_count = 2
EOF

echo "✓ Environment '$ENVIRONMENT' created successfully!"
echo ""
echo "Next steps:"
echo "1. Review and edit the configuration:"
echo "   cd environments/$ENVIRONMENT"
echo "   vim terraform.tfvars"
echo ""
echo "2. Initialize Terraform:"
echo "   terraform init"
echo ""
echo "3. Review the plan:"
echo "   terraform plan"
echo ""
echo "4. Apply the configuration:"
echo "   terraform apply"
echo ""
echo "5. Deploy Docker images:"
echo "   cd ../.. && ./scripts/deploy-images.sh $ENVIRONMENT"

