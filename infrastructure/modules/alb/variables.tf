variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "search_api_port" {
  description = "Port for search API"
  type        = number
}

variable "bookdetail_api_port" {
  description = "Port for book detail API"
  type        = number
}

variable "ratings_api_port" {
  description = "Port for ratings API"
  type        = number
}

