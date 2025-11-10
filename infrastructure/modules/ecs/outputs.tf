output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "search_api_service_name" {
  description = "Name of the Search API ECS service"
  value       = aws_ecs_service.search_api.name
}

output "bookdetail_api_service_name" {
  description = "Name of the Book Detail API ECS service"
  value       = aws_ecs_service.bookdetail_api.name
}

output "ratings_api_service_name" {
  description = "Name of the Ratings API ECS service"
  value       = aws_ecs_service.ratings_api.name
}

