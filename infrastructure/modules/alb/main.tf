########################################
# Application Load Balancer Module
########################################

# ALB
resource "aws_lb" "main" {
  name               = "book-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Groups

# Search API Target Group
resource "aws_lb_target_group" "search_api" {
  name        = "book-search-${var.environment}"
  port        = var.search_api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-search-api-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Book Detail API Target Group
resource "aws_lb_target_group" "bookdetail_api" {
  name        = "book-detail-${var.environment}"
  port        = var.bookdetail_api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-bookdetail-api-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Ratings API Target Group
resource "aws_lb_target_group" "ratings_api" {
  name        = "book-ratings-${var.environment}"
  port        = var.ratings_api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-ratings-api-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# HTTP Listener with path-based routing
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - return 404
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\": \"not_found\", \"message\": \"Service not found\"}"
      status_code  = "404"
    }
  }

  tags = {
    Name        = "${var.project_name}-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener Rules

# Search API routing
resource "aws_lb_listener_rule" "search_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.search_api.arn
  }

  condition {
    path_pattern {
      values = ["/search*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-search-api-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Ratings API routing - Book ratings endpoints (higher priority to match first)
resource "aws_lb_listener_rule" "ratings_api_books" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 150

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ratings_api.arn
  }

  condition {
    path_pattern {
      values = ["/books/*/rate", "/books/*/ratings"]
    }
  }

  tags = {
    Name        = "${var.project_name}-ratings-api-books-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Ratings API routing - User ratings endpoints
resource "aws_lb_listener_rule" "ratings_api_users" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 160

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ratings_api.arn
  }

  condition {
    path_pattern {
      values = ["/users/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-ratings-api-users-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Book Detail API routing (lower priority so ratings rules match first)
resource "aws_lb_listener_rule" "bookdetail_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bookdetail_api.arn
  }

  condition {
    path_pattern {
      values = ["/books*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-bookdetail-api-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

