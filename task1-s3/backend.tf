
# terraform block configures Terraform itself (version, providers, state storage).
terraform {
  
  required_version = ">= 1.5.0"

 
  required_providers {
    aws = {
      
      source = "hashicorp/aws"
      
      version = "~> 6.0"
    }
  }

  # Remote backend — stores state file in S3 instead of locally on disk.
  backend "s3" {
    
    bucket = "remote-backend-mukesh"
    
    key = "s3-task/terraform.tfstate"
    
    region = "eu-central-1"
    
  }
}
