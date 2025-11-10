########################################
# ECS Cluster and Services Module
########################################

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

########################################
# Search API ECS Service
########################################

resource "aws_ecs_task_definition" "search_api" {
  family                   = "${var.project_name}-search-api-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.search_api_cpu
  memory                   = var.search_api_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "search-api"
      image     = "${var.search_api_repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.search_api_port
          hostPort      = var.search_api_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.search_api_port)
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DYNAMODB_TABLE_BOOKS"
          value = var.books_table_name
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.search_api_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.search_api_port}/healthz || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-search-api-task"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecs_service" "search_api" {
  name            = "${var.project_name}-search-api-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.search_api.arn
  desired_count   = var.search_api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.search_api_target_group_arn
    container_name   = "search-api"
    container_port   = var.search_api_port
  }

  depends_on = [var.alb_listener_arn]

  tags = {
    Name        = "${var.project_name}-search-api-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

########################################
# Book Detail API ECS Service
########################################

resource "aws_ecs_task_definition" "bookdetail_api" {
  family                   = "${var.project_name}-bookdetail-api-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.bookdetail_api_cpu
  memory                   = var.bookdetail_api_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "bookdetail-api"
      image     = "${var.bookdetail_api_repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.bookdetail_api_port
          hostPort      = var.bookdetail_api_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.bookdetail_api_port)
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DYNAMODB_TABLE_BOOKS"
          value = var.books_table_name
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.bookdetail_api_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.bookdetail_api_port}/healthz || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-bookdetail-api-task"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecs_service" "bookdetail_api" {
  name            = "${var.project_name}-bookdetail-api-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.bookdetail_api.arn
  desired_count   = var.bookdetail_api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.bookdetail_api_target_group_arn
    container_name   = "bookdetail-api"
    container_port   = var.bookdetail_api_port
  }

  depends_on = [var.alb_listener_arn]

  tags = {
    Name        = "${var.project_name}-bookdetail-api-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

########################################
# Ratings API ECS Service
########################################

resource "aws_ecs_task_definition" "ratings_api" {
  family                   = "${var.project_name}-ratings-api-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ratings_api_cpu
  memory                   = var.ratings_api_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "ratings-api"
      image     = "${var.ratings_api_repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.ratings_api_port
          hostPort      = var.ratings_api_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.ratings_api_port)
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DYNAMODB_TABLE_RATINGS"
          value = var.ratings_table_name
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ratings_api_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-ratings-api-task"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecs_service" "ratings_api" {
  name            = "${var.project_name}-ratings-api-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ratings_api.arn
  desired_count   = var.ratings_api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.ratings_api_target_group_arn
    container_name   = "ratings-api"
    container_port   = var.ratings_api_port
  }

  depends_on = [var.alb_listener_arn]

  tags = {
    Name        = "${var.project_name}-ratings-api-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

