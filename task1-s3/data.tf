
# Builds an IAM policy JSON document that allows CloudFront to read from S3.
data "aws_iam_policy_document" "gallery_bucket_policy" {
  # Single policy statement block.
  statement {
    # Statement identifier — useful for debugging in the AWS console.
    sid = "AllowCloudFrontToRead"
    # Allow (not Deny) the actions listed below.
    effect = "Allow"

    # Who is allowed to perform the action.
    principals {
      # Principal type is an AWS service (not a user or role).
      type = "Service"
      # Only the CloudFront service can use this policy.
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # Permitted S3 action — read objects only, not write or delete.
    actions = ["s3:GetObject"]
    # Apply to all objects inside the gallery bucket.
    resources = ["${aws_s3_bucket.gallery.arn}/*"]

    # Extra restriction — only requests from OUR CloudFront distribution are allowed.
    condition {
      # Condition type: exact string match.
      test = "StringEquals"
      # The CloudFront distribution ARN must match.
      variable = "AWS:SourceArn"
      # ARN of the CloudFront distribution created in main.tf.
      values = [aws_cloudfront_distribution.gallery.arn]
    }
  }
}
