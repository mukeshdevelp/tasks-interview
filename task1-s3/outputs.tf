
# Name of the private gallery S3 bucket
output "bucket_name" {
  description = "Private S3 bucket name."
  value       = aws_s3_bucket.gallery.id
}

# CloudFront domain used to access the gallery in a browser
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain."
  value       = aws_cloudfront_distribution.gallery.domain_name
}

# Full HTTPS URL for the gallery homepage — open this in a browser
output "home_url" {
  description = "Gallery homepage."
  value       = "https://${aws_cloudfront_distribution.gallery.domain_name}/"
}
