# Outputs for development environment

########################################
# Network Outputs
########################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

########################################
# Load Balancer Outputs
########################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

########################################
# ECR Outputs
########################################

output "ecr_search_api_url" {
  description = "URL of the Search API ECR repository"
  value       = module.ecr.search_api_repository_url
}

output "ecr_bookdetail_api_url" {
  description = "URL of the Book Detail API ECR repository"
  value       = module.ecr.bookdetail_api_repository_url
}

output "ecr_ratings_api_url" {
  description = "URL of the Ratings API ECR repository"
  value       = module.ecr.ratings_api_repository_url
}

########################################
# ECS Outputs
########################################

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "search_api_service_name" {
  description = "Name of the Search API ECS service"
  value       = module.ecs.search_api_service_name
}

output "bookdetail_api_service_name" {
  description = "Name of the Book Detail API ECS service"
  value       = module.ecs.bookdetail_api_service_name
}

output "ratings_api_service_name" {
  description = "Name of the Ratings API ECS service"
  value       = module.ecs.ratings_api_service_name
}

########################################
# DynamoDB Outputs
########################################

output "dynamodb_books_table_name" {
  description = "Name of the Books DynamoDB table"
  value       = module.database.books_table_name
}

output "dynamodb_ratings_table_name" {
  description = "Name of the Ratings DynamoDB table"
  value       = module.database.ratings_table_name
}

output "dynamodb_user_profiles_table_name" {
  description = "Name of the UserProfiles DynamoDB table"
  value       = module.database.user_profiles_table_name
}

########################################
# CloudWatch Outputs
########################################

output "search_api_log_group" {
  description = "CloudWatch log group for Search API"
  value       = module.monitoring.search_api_log_group_name
}

output "bookdetail_api_log_group" {
  description = "CloudWatch log group for Book Detail API"
  value       = module.monitoring.bookdetail_api_log_group_name
}

output "ratings_api_log_group" {
  description = "CloudWatch log group for Ratings API"
  value       = module.monitoring.ratings_api_log_group_name
}

########################################
# Service Endpoints
########################################

output "search_api_endpoint" {
  description = "Endpoint for Search API"
  value       = "http://${module.alb.alb_dns_name}/search"
}

output "bookdetail_api_endpoint" {
  description = "Endpoint for Book Detail API"
  value       = "http://${module.alb.alb_dns_name}/books"
}

output "ratings_api_endpoint" {
  description = "Endpoint for Ratings API"
  value       = "http://${module.alb.alb_dns_name}/books"
}

