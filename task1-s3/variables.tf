

# AWS region where the gallery S3 bucket and CloudFront origin will be created.
variable "aws_region" {
  description = "AWS region for the S3 bucket and related resources."
  type        = string
}

# Prefix used in bucket names and resource naming (e.g. s3-task-images-abc123).
variable "project_name" {
  description = "Prefix used for AWS resource names."
  type        = string
}

# Local folder path containing image1.jpg … image10.jpg.
variable "images_dir" {
  description = "Local directory containing gallery images."
  type        = string
}

# Value applied to the 'owner' tag on all AWS resources via provider default_tags.
variable "owner" {
  description = "Owner tag applied to all taggable resources."
  type        = string
}
