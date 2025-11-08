########################################
# DynamoDB: Books table
########################################

resource "aws_dynamodb_table" "books" {
  name         = "Books"
  billing_mode = "PAY_PER_REQUEST"

  # Primary key: book_id
  hash_key = "book_id"

  # Attributes (only those used as keys or GSIs must be declared)
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

  # GSI1: Search by lowercase title (exact or prefix match)
  global_secondary_index {
    name               = "TitleLowerIndex"
    hash_key           = "title_lower"
    projection_type    = "ALL"
    read_capacity      = 0   # Required when using on-demand billing
    write_capacity     = 0
  }

  # GSI2: Browse by first-letter prefix (A–Z sharding)
  global_secondary_index {
    name               = "TitlePrefixIndex"
    hash_key           = "title_prefix"
    projection_type    = "ALL"
    read_capacity      = 0
    write_capacity     = 0
  }

  # Optional: Enable point-in-time recovery for safety
  point_in_time_recovery {
    enabled = true
  }

  # Enable server-side encryption (recommended)
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "Books"
    Environment = "dev"
    Project     = "cs6650-final"
  }
}

########################################
# DynamoDB: Ratings table
########################################

resource "aws_dynamodb_table" "ratings" {
  name         = "Ratings"
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
    Name        = "Ratings"
    Environment = "dev"
    Project     = "cs6650-final"
  }
}

########################################
# DynamoDB: UserProfiles table
########################################

resource "aws_dynamodb_table" "user_profiles" {
  name         = "UserProfiles"
  billing_mode = "PAY_PER_REQUEST"

  # Primary key: user_id
  hash_key = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  # No GSIs for now — can add username-based index later if needed

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "UserProfiles"
    Environment = "dev"
    Project     = "cs6650-final"
  }
}