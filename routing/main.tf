

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "remote-backend-mukesh"
    key    = "routing/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# Import the existing CloudFront distribution.
import {
  to = aws_cloudfront_distribution.combined
  id = var.cloudfront_distribution_id
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "s3_bucket_name" {
  description = "Gallery S3 bucket name — task1-s3: terraform output -raw bucket_name"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "Existing CloudFront distribution ID from task1-s3 (Exxxxxxxxxxxx)."
  type        = string
}

variable "cloudfront_oac_id" {
  description = "OAC ID from task1-s3: terraform state show aws_cloudfront_origin_access_control.gallery"
  type        = string
}

variable "ecs_project_name" {
  description = "ECS project_name from task-2-ecs (ALB is named <name>-alb)."
  type        = string
  default     = "ecs-task-app"
}

variable "s3_project_name" {
  description = "S3 project_name from task1-s3 (used for resource naming)."
  type        = string
  default     = "s3-task-images"
}

# ECS ALB from from ecs.
data "aws_lb" "ecs" {
  name = "${var.ecs_project_name}-alb"
}

# Private gallery bucket from task1-s3.
data "aws_s3_bucket" "gallery" {
  bucket = var.s3_bucket_name
}

# Rewrites the path.
resource "aws_cloudfront_function" "s3_rewrite" {
  name    = "${var.s3_project_name}-routing-s3-rewrite"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      if (request.uri === '/s3' || request.uri === '/s3/') {
        request.uri = '/index.html';
      }
      return request;
    }
  JS
}

# Manages the existing  CloudFront distribution with dual-origin routing.
resource "aws_cloudfront_distribution" "combined" {
  enabled    = true
  comment    = var.s3_project_name
  price_class = "PriceClass_100"
  http_version = "http2and3"

  # Origin 1 — private S3 gallery.
  origin {
    domain_name              = data.aws_s3_bucket.gallery.bucket_regional_domain_name
    origin_id                = "gallery-s3-origin"
    origin_access_control_id = var.cloudfront_oac_id
  }

  # Origin 2 — ECS ALB 
  origin {
    domain_name = data.aws_lb.ecs.dns_name
    origin_id   = "ecs-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  # Default: /, /health, /config → ECS.
  default_cache_behavior {
    target_origin_id       = "ecs-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

  # Gallery images -  S3.
  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "gallery-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  # Gallery page → S3 (function rewrites /s3 to /index.html).
  ordered_cache_behavior {
    path_pattern           = "/s3*"
    target_origin_id       = "gallery-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.s3_rewrite.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "cloudfront_domain_name" {
  description = "Same CloudFront URL as task1 — now routes / to ECS and /s3 to gallery."
  value       = aws_cloudfront_distribution.combined.domain_name
}

output "ecs_url" {
  description = "ECS Welcome page."
  value       = "https://${aws_cloudfront_distribution.combined.domain_name}/"
}

output "gallery_url" {
  description = "S3 gallery index.html."
  value       = "https://${aws_cloudfront_distribution.combined.domain_name}/s3"
}
