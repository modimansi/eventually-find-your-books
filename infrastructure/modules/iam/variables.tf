variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# These are kept for compatibility but not used
variable "books_table_arn" {
  description = "ARN of the Books DynamoDB table"
  type        = string
}

variable "ratings_table_arn" {
  description = "ARN of the Ratings DynamoDB table"
  type        = string
}

variable "user_profiles_table_arn" {
  description = "ARN of the UserProfiles DynamoDB table"
  type        = string
}

