# Variables for development environment

variable "project_name" {
  description = "Project name used for tagging and naming resources"
  type        = string
  default     = "book-recommendation"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# Service configuration
variable "search_api_port" {
  description = "Port for search API"
  type        = number
  default     = 8080
}

variable "bookdetail_api_port" {
  description = "Port for book detail API"
  type        = number
  default     = 8081
}

variable "ratings_api_port" {
  description = "Port for ratings API"
  type        = number
  default     = 3000
}

variable "recommendation_api_port" {
  description = "Port for recommendation API"
  type        = number
  default     = 8000
}

# ECS task resources
variable "search_api_cpu" {
  description = "CPU units for search API task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "search_api_memory" {
  description = "Memory for search API task (in MB)"
  type        = number
  default     = 1024
}

variable "bookdetail_api_cpu" {
  description = "CPU units for book detail API task"
  type        = number
  default     = 512
}

variable "bookdetail_api_memory" {
  description = "Memory for book detail API task (in MB)"
  type        = number
  default     = 1024
}

variable "ratings_api_cpu" {
  description = "CPU units for ratings API task"
  type        = number
  default     = 256
}

variable "ratings_api_memory" {
  description = "Memory for ratings API task (in MB)"
  type        = number
  default     = 512
}

# Desired task count
variable "search_api_desired_count" {
  description = "Desired number of search API tasks"
  type        = number
  default     = 2
}

variable "bookdetail_api_desired_count" {
  description = "Desired number of book detail API tasks"
  type        = number
  default     = 2
}

variable "ratings_api_desired_count" {
  description = "Desired number of ratings API tasks"
  type        = number
  default     = 2
}

########################################
# Search API autoscaling
########################################
variable "search_api_min_count" {
  description = "Minimum Search API tasks"
  type        = number
  default     = 2
}

variable "search_api_max_count" {
  description = "Maximum Search API tasks"
  type        = number
  default     = 10
}

variable "search_api_cpu_target" {
  description = "CPU target for Search API autoscaling (%)"
  type        = number
  default     = 60
}

variable "search_api_scale_in_cooldown" {
  description = "Scale-in cooldown seconds"
  type        = number
  default     = 120
}

variable "search_api_scale_out_cooldown" {
  description = "Scale-out cooldown seconds"
  type        = number
  default     = 60
}

variable "recommendation_api_min_count" {
  description = "Minimum recommendation API tasks"
  type        = number
  default     = 1
}

variable "recommendation_api_max_count" {
  description = "Maximum recommendation API tasks"
  type        = number
  default     = 5
}

variable "recommendation_api_cpu_target" {
  description = "CPU target for recommendation API autoscaling (%)"
  type        = number
  default     = 60
}

variable "recommendation_api_scale_in_cooldown" {
  description = "Scale-in cooldown seconds"
  type        = number
  default     = 120
}

variable "recommendation_api_scale_out_cooldown" {
  description = "Scale-out cooldown seconds"
  type        = number
  default     = 60
}

