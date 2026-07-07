
# AWS provider — authenticates using AWS CLI credentials or environment variables.
provider "aws" {
  # Region where resources will be created (from terraform.tfvars).
  region = var.aws_region

  # Automatically attach common tags to every resource this provider creates.
  default_tags {
    tags = local.common_tags
  }
}

# ------------------------------------------------------------------------------
# S3 — Private gallery bucket and uploaded objects
# ------------------------------------------------------------------------------

# Creates the private S3 bucket that stores images and index.html.
resource "aws_s3_bucket" "gallery" {
  # AWS appends a random suffix to ensure the bucket name is globally unique.
  bucket_prefix = "${var.project_name}-"
}

# Blocks ALL public access — bucket cannot be accessed directly from the internet.
resource "aws_s3_bucket_public_access_block" "gallery" {
  # Reference to the gallery bucket created above.
  bucket = aws_s3_bucket.gallery.id
  # Reject new public ACLs on objects.
  block_public_acls       = true 
  # Ignore any existing public ACLs.
  ignore_public_acls      = true 
  block_public_policy     = true # Reject bucket policies that grant public access.
  restrict_public_buckets = true # Block public/cross-account access via policy.
}

# Disables ACLs — bucket owner always owns all objects (required for bucket policy access).
resource "aws_s3_bucket_ownership_controls" "gallery" {
  bucket = aws_s3_bucket.gallery.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Upload each gallery image from local images/ folder to S3.
resource "aws_s3_object" "images" {
  # Create one S3 object per image file found in local.image_files.
  for_each = toset(local.image_files)

  bucket = aws_s3_bucket.gallery.id
  # S3 object key — stored under images/ prefix (e.g. images/image1.jpg).
  key = "${var.images_dir}/${each.value}"
  # Local file path to upload from.
  source = "${path.module}/${var.images_dir}/${each.value}"
  # MD5 hash — Terraform re-uploads only when the file content changes.
  etag = filemd5("${path.module}/${var.images_dir}/${each.value}")

  # Set correct MIME type based on file extension (e.g. image/jpeg for .jpg).
  content_type = lookup(
    local.content_types,
    lower(regex("\\.[^.]+$", each.value)),
    "application/octet-stream"
  )
}

# Upload the generated gallery HTML page to S3 as index.html.
resource "aws_s3_object" "index_page" {
  bucket  = aws_s3_bucket.gallery.id
  key     = "index.html"
  content = local.index_html_content
  # MD5 of HTML content — triggers re-upload when gallery HTML changes.
  etag         = md5(local.index_html_content)
  content_type = "text/html; charset=utf-8"
}


# CloudFront — CDN to serve private S3 content over HTTPS


# Origin Access Control — lets CloudFront securely read from the private S3 bucket.
resource "aws_cloudfront_origin_access_control" "gallery" {
  name        = "${var.project_name}-oac"
  description = "Origin access control for private image gallery"
  # OAC is configured for an S3 origin (not a custom HTTP origin).
  origin_access_control_origin_type = "s3"
  # Every request from CloudFront to S3 is signed.
  signing_behavior = "always"
  # Use AWS Signature Version 4 for signing.
  signing_protocol = "sigv4"
}

# CloudFront distribution — the public HTTPS endpoint users access in the browser.
resource "aws_cloudfront_distribution" "gallery" {
  enabled = true
  comment = var.project_name
  # When user visits /, CloudFront serves index.html automatically.
  default_root_object = "index.html"
  # Use edge locations in North America and Europe only (lower cost).
  price_class = "PriceClass_100"
  # Support HTTP/2 and HTTP/3 for faster page loads.
  http_version = "http2and3"

  # S3 bucket is the origin — CloudFront fetches objects from here on cache miss.
  origin {
    domain_name = aws_s3_bucket.gallery.bucket_regional_domain_name
    origin_id   = "gallery-s3-origin"
    # Attach OAC so CloudFront can access the private bucket.
    origin_access_control_id = aws_cloudfront_origin_access_control.gallery.id
  }

  # Default caching rules applied to all paths (/, /images/*, etc.).
  default_cache_behavior {
    target_origin_id = "gallery-s3-origin"
    # Redirect HTTP requests to HTTPS.
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"] # Only read operations allowed.
    cached_methods  = ["GET", "HEAD"] # Cache GET and HEAD responses at edge.
    compress        = true            # Compress text responses (HTML).

    forwarded_values {
      query_string = false # Do not forward query strings to S3.

      cookies {
        forward = "none" # Do not forward cookies to S3.
      }
    }
  }

  # No geographic restrictions — accessible worldwide.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use the free default CloudFront SSL certificate (*.cloudfront.net).
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Ensure public access block is in place before creating the distribution.
  depends_on = [aws_s3_bucket_public_access_block.gallery]
}


# S3 Bucket Policy — allow only CloudFront to read objects


# Attach the IAM policy document (from data.tf) to the gallery bucket.
resource "aws_s3_bucket_policy" "gallery" {
  bucket = aws_s3_bucket.gallery.id
  # JSON policy built by data.aws_iam_policy_document.gallery_bucket_policy.
  policy = data.aws_iam_policy_document.gallery_bucket_policy.json
}
