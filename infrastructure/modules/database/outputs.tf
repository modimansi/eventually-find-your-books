output "books_table_name" {
  description = "Name of the Books DynamoDB table"
  value       = aws_dynamodb_table.books.name
}

output "books_table_arn" {
  description = "ARN of the Books DynamoDB table"
  value       = aws_dynamodb_table.books.arn
}

output "ratings_table_name" {
  description = "Name of the Ratings DynamoDB table"
  value       = aws_dynamodb_table.ratings.name
}

output "ratings_table_arn" {
  description = "ARN of the Ratings DynamoDB table"
  value       = aws_dynamodb_table.ratings.arn
}

output "user_profiles_table_name" {
  description = "Name of the UserProfiles DynamoDB table"
  value       = aws_dynamodb_table.user_profiles.name
}

output "user_profiles_table_arn" {
  description = "ARN of the UserProfiles DynamoDB table"
  value       = aws_dynamodb_table.user_profiles.arn
}

