# Look up available availability zones in the configured AWS region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Trust policy allowing the ECS tasks service to assume the execution role.
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Permissions for the ECS agent to read SSM parameters and Secrets Manager values at task startup.
data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    sid    = "ReadRuntimeConfiguration"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameters",
      "kms:Decrypt",
    ]

    resources = [
      aws_secretsmanager_secret.api_key.arn,
      aws_secretsmanager_secret.db_password.arn,
      aws_ssm_parameter.app_name.arn,
      aws_ssm_parameter.db_host.arn,
    ]
  }
}
