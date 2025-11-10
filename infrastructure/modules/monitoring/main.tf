########################################
# CloudWatch Log Groups Module
########################################

# Search API Log Group
resource "aws_cloudwatch_log_group" "search_api" {
  name              = "/ecs/${var.project_name}/${var.environment}/search-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-search-api-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Book Detail API Log Group
resource "aws_cloudwatch_log_group" "bookdetail_api" {
  name              = "/ecs/${var.project_name}/${var.environment}/bookdetail-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-bookdetail-api-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Ratings API Log Group
resource "aws_cloudwatch_log_group" "ratings_api" {
  name              = "/ecs/${var.project_name}/${var.environment}/ratings-api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-ratings-api-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

