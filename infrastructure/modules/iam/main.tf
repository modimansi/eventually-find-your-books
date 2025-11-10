########################################
# IAM Module for AWS Academy Labs
# Uses existing LabRole instead of creating new roles
########################################

# Data source to get existing LabRole
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Output the LabRole ARN for use by ECS
# This role typically has broad permissions in AWS Academy

