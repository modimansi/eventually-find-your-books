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

