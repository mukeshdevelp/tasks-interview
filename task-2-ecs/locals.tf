# Reusable computed values used across multiple resources.
locals {
  # Use the first two AZs in the region (ALB requires subnets in at least 2 AZs).
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Tags automatically applied to all taggable AWS resources.
  common_tags = {
    owner = var.owner
    Name  = var.project_name
  }
}
