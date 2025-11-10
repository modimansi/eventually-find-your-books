output "search_api_log_group_name" {
  description = "Name of the Search API log group"
  value       = aws_cloudwatch_log_group.search_api.name
}

output "bookdetail_api_log_group_name" {
  description = "Name of the Book Detail API log group"
  value       = aws_cloudwatch_log_group.bookdetail_api.name
}

output "ratings_api_log_group_name" {
  description = "Name of the Ratings API log group"
  value       = aws_cloudwatch_log_group.ratings_api.name
}

