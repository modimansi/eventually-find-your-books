output "search_api_repository_url" {
  description = "URL of the Search API ECR repository"
  value       = aws_ecr_repository.search_api.repository_url
}

output "bookdetail_api_repository_url" {
  description = "URL of the Book Detail API ECR repository"
  value       = aws_ecr_repository.bookdetail_api.repository_url
}

output "ratings_api_repository_url" {
  description = "URL of the Ratings API ECR repository"
  value       = aws_ecr_repository.ratings_api.repository_url
}

