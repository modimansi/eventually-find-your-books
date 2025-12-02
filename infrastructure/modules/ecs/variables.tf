variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Networking
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

# IAM
variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

# ECR
variable "search_api_repository_url" {
  description = "URL of the Search API ECR repository"
  type        = string
}

variable "bookdetail_api_repository_url" {
  description = "URL of the Book Detail API ECR repository"
  type        = string
}

variable "ratings_api_repository_url" {
  description = "URL of the Ratings API ECR repository"
  type        = string
}

variable "recommendation_api_repository_url" {
  description = "URL of the Recommendation API ECR repository"
  type        = string
}

# ALB
variable "search_api_target_group_arn" {
  description = "ARN of the Search API target group"
  type        = string
}

variable "bookdetail_api_target_group_arn" {
  description = "ARN of the Book Detail API target group"
  type        = string
}

variable "ratings_api_target_group_arn" {
  description = "ARN of the Ratings API target group"
  type        = string
}

variable "recommendation_api_target_group_arn" {
  description = "ARN of the Recommendation API target group"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener"
  type        = string
}

# CloudWatch
variable "search_api_log_group_name" {
  description = "Name of the Search API log group"
  type        = string
}

variable "bookdetail_api_log_group_name" {
  description = "Name of the Book Detail API log group"
  type        = string
}

variable "ratings_api_log_group_name" {
  description = "Name of the Ratings API log group"
  type        = string
}

# DynamoDB
variable "books_table_name" {
  description = "Name of the Books DynamoDB table"
  type        = string
}

variable "ratings_table_name" {
  description = "Name of the Ratings DynamoDB table"
  type        = string
}

# Search API Configuration
variable "search_api_port" {
  description = "Port for search API"
  type        = number
}

variable "search_api_cpu" {
  description = "CPU units for search API task"
  type        = number
}

variable "search_api_memory" {
  description = "Memory for search API task (in MB)"
  type        = number
}

variable "search_api_desired_count" {
  description = "Desired number of search API tasks"
  type        = number
}

# Book Detail API Configuration
variable "bookdetail_api_port" {
  description = "Port for book detail API"
  type        = number
}

variable "bookdetail_api_cpu" {
  description = "CPU units for book detail API task"
  type        = number
}

variable "bookdetail_api_memory" {
  description = "Memory for book detail API task (in MB)"
  type        = number
}

variable "bookdetail_api_desired_count" {
  description = "Desired number of book detail API tasks"
  type        = number
}

# Ratings API Configuration
variable "ratings_api_port" {
  description = "Port for ratings API"
  type        = number
}

variable "ratings_api_cpu" {
  description = "CPU units for ratings API task"
  type        = number
}

variable "ratings_api_memory" {
  description = "Memory for ratings API task (in MB)"
  type        = number
}

variable "ratings_api_desired_count" {
  description = "Desired number of ratings API tasks"
  type        = number
}

########################################
# Search API autoscaling
########################################
variable "search_api_min_count" {
  description = "Minimum number of Search API tasks"
  type        = number
  default     = 2
}

variable "search_api_max_count" {
  description = "Maximum number of Search API tasks"
  type        = number
  default     = 10
}

variable "search_api_cpu_target" {
  description = "Target average CPU utilization (%) for Search API autoscaling"
  type        = number
  default     = 60
}

variable "search_api_scale_in_cooldown" {
  description = "Scale-in cooldown seconds for Search API"
  type        = number
  default     = 120
}

variable "search_api_scale_out_cooldown" {
  description = "Scale-out cooldown seconds for Search API"
  type        = number
  default     = 60
}

# Recommendation API autoscaling
variable "recommendation_api_min_count" {
  description = "Minimum number of recommendation API tasks"
  type        = number
  default     = 1
}

variable "recommendation_api_max_count" {
  description = "Maximum number of recommendation API tasks"
  type        = number
  default     = 5
}

variable "recommendation_api_cpu_target" {
  description = "Target average CPU utilization (%) for recommendation API autoscaling"
  type        = number
  default     = 60
}

variable "recommendation_api_scale_in_cooldown" {
  description = "Scale-in cooldown seconds for recommendation API"
  type        = number
  default     = 120
}

variable "recommendation_api_scale_out_cooldown" {
  description = "Scale-out cooldown seconds for recommendation API"
  type        = number
  default     = 60
}

# Redis Cache
variable "redis_endpoint" {
  description = "Redis ElastiCache endpoint address"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

