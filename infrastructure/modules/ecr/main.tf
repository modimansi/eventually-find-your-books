########################################
# ECR Repositories Module
########################################

# Search API Repository
resource "aws_ecr_repository" "search_api" {
  name                 = "${var.project_name}/search-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-search-api"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lifecycle policy for search API
resource "aws_ecr_lifecycle_policy" "search_api" {
  repository = aws_ecr_repository.search_api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Book Detail API Repository
resource "aws_ecr_repository" "bookdetail_api" {
  name                 = "${var.project_name}/bookdetail-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-bookdetail-api"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lifecycle policy for book detail API
resource "aws_ecr_lifecycle_policy" "bookdetail_api" {
  repository = aws_ecr_repository.bookdetail_api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Ratings API Repository
resource "aws_ecr_repository" "ratings_api" {
  name                 = "${var.project_name}/ratings-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-ratings-api"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lifecycle policy for ratings API
resource "aws_ecr_lifecycle_policy" "ratings_api" {
  repository = aws_ecr_repository.ratings_api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

