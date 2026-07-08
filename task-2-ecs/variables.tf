# AWS region where ECS, VPC, ALB, and related resources are created.
variable "aws_region" {
  description = "AWS region for ECS resources."
  type        = string
}

# Prefix applied to most resource names (VPC, ALB, ECS cluster, ECR repo, etc.).
variable "project_name" {
  description = "Prefix used for AWS resource names."
  type        = string
}

# Owner tag value applied to all taggable resources via provider default_tags.
variable "owner" {
  description = "Owner tag applied to all taggable resources."
  type        = string
}

# App display name stored in SSM and injected into the container as APP_NAME.
# Set in ~/.bashrc as TF_VAR_app_name.
variable "app_name" {
  description = "Application name loaded from AWS Parameter Store. Set via TF_VAR_app_name in ~/.bashrc."
  type        = string
  sensitive   = true
}

# Database hostname stored in SSM and injected into the container as DB_HOST.
# Set in ~/.bashrc as TF_VAR_db_host.
variable "db_host" {
  description = "Database host loaded from AWS Parameter Store. Set via TF_VAR_db_host in ~/.bashrc."
  type        = string
  sensitive   = true
}

# API key stored in Secrets Manager and injected into the container as API_KEY.
# Set in ~/.bashrc as TF_VAR_api_key.
variable "api_key" {
  description = "API key loaded from AWS Secrets Manager. Set via TF_VAR_api_key in ~/.bashrc."
  type        = string
  sensitive   = true
}

# Database password stored in Secrets Manager and injected as DB_PASSWORD.
# Set in ~/.bashrc as TF_VAR_db_password.
variable "db_password" {
  description = "Database password loaded from AWS Secrets Manager. Set via TF_VAR_db_password in ~/.bashrc."
  type        = string
  sensitive   = true
}
