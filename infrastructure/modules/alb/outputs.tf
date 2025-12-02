output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "search_api_target_group_arn" {
  description = "ARN of the Search API target group"
  value       = aws_lb_target_group.search_api.arn
}

output "bookdetail_api_target_group_arn" {
  description = "ARN of the Book Detail API target group"
  value       = aws_lb_target_group.bookdetail_api.arn
}

output "ratings_api_target_group_arn" {
  description = "ARN of the Ratings API target group"
  value       = aws_lb_target_group.ratings_api.arn
}

output "recommendation_api_target_group_arn" {
  description = "ARN of the Recommendation API target group"
  value       = aws_lb_target_group.recommendation_api.arn
}

