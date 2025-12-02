########################################
# DynamoDB Tables Module
########################################

# Books Table
resource "aws_dynamodb_table" "books" {
  name         = "${var.project_name}-books-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  # Primary key: book_id
  hash_key = "book_id"

  # Attributes
  attribute {
    name = "book_id"
    type = "S"
  }

  attribute {
    name = "title_lower"
    type = "S"
  }

  attribute {
    name = "title_prefix"
    type = "S"
  }

  # ⭐ Added for composite sharding
  attribute {
    name = "shard_key"
    type = "S"
  }

  # GSI1: Search by lowercase title
  global_secondary_index {
    name               = "TitleLowerIndex"
    hash_key           = "title_lower"
    projection_type    = "ALL"
    read_capacity      = 0
    write_capacity     = 0
  }

  # GSI2: Browse by title prefix (A–Z)
  global_secondary_index {
    name               = "TitlePrefixIndex"
    hash_key           = "title_prefix"
    projection_type    = "ALL"
    read_capacity      = 0
    write_capacity     = 0
  }

  # ⭐ New GSI3: Composite Sharding (T1, I-M, R-U...)
  global_secondary_index {
    name               = "ShardIndex"
    hash_key           = "shard_key"
    projection_type    = "ALL"
    read_capacity      = 0
    write_capacity     = 0
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-books"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Ratings Table
resource "aws_dynamodb_table" "ratings" {
  name         = "${var.project_name}-ratings-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  # Primary key: user_id + book_id
  hash_key  = "user_id"
  range_key = "book_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "book_id"
    type = "S"
  }

  # GSI: Query all ratings for a given book
  global_secondary_index {
    name               = "BookRatingsIndex"
    hash_key           = "book_id"
    projection_type    = "ALL"
    read_capacity      = 0
    write_capacity     = 0
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-ratings"
    Environment = var.environment
    Project     = var.project_name
  }
}

# UserProfiles Table
resource "aws_dynamodb_table" "user_profiles" {
  name         = "${var.project_name}-user-profiles-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  # Primary key: user_id
  hash_key = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-user-profiles"
    Environment = var.environment
    Project     = var.project_name
  }
}

