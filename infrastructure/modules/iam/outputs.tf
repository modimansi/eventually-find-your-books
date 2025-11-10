output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (using LabRole)"
  value       = data.aws_iam_role.lab_role.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role (using LabRole)"
  value       = data.aws_iam_role.lab_role.arn
}

