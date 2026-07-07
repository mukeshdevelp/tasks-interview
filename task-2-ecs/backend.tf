# Terraform version, provider, and remote state backend configuration.
terraform {
  required_version = ">= 1.5.0"

  # Provider plugins required by this project.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Store Terraform state remotely in S3 under the ecs-task prefix.
  backend "s3" {
    bucket = "remote-backend-mukesh"
    key    = "ecs-task/terraform.tfstate"
    region = "eu-central-1"
  }
}
