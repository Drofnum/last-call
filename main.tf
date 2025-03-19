terraform {
  backend "s3" {
    key = "tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # CloudFront requires ACM certificates to be in us-east-1
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

# Get the current AWS account ID
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  s3_origin_id = "lcm-challenge-origin"
}

# Import existing state bucket if needed
import {
  to = aws_s3_bucket.tfstate
  id = "tf-${local.account_id}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "tf-${local.account_id}"
}

# S3 bucket for hosting website content
resource "aws_s3_bucket" "web_bucket" {
  bucket = "lcm-challenge-${local.account_id}"
}

# Enable bucket versioning for website content
resource "aws_s3_bucket_versioning" "web_bucket_versioning" {
  bucket = aws_s3_bucket.web_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Make the bucket publicly accessible to CloudFront
resource "aws_s3_bucket_public_access_block" "web_bucket_public_access" {
  bucket = aws_s3_bucket.web_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload website content to S3
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.id
  key    = "index.html"
  source = "web/index.html"
  etag   = filemd5("web/index.html")
  content_type = "text/html"
}

# Create IAM role for Lambda@Edge
resource "aws_iam_role" "lambda_edge_role" {
  name = "lambda-edge-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach basic execution policy to role
resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create zip file for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda/basic-auth.js"
  output_path = "lambda/basic-auth.zip"
}

# Lambda@Edge function for basic authentication
resource "aws_lambda_function" "auth_lambda" {
  provider         = aws # Lambda@Edge must be in us-east-1
  function_name    = "cloudfront-basic-auth"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_edge_role.arn
  handler          = "basic-auth.handler"
  runtime          = "nodejs18.x"
  publish          = true # Required for Lambda@Edge
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "lcm-challenge-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy to allow CloudFront access via OAC
resource "aws_s3_bucket_policy" "web_bucket_policy" {
  bucket = aws_s3_bucket.web_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.web_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })

  # Make sure the policy is applied after the distribution is created
  depends_on = [aws_cloudfront_distribution.s3_distribution]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.web_bucket.bucket_regional_domain_name
    origin_id                = local.s3_origin
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "CloudFront distribution for LCM challenge"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.auth_lambda.qualified_arn
      include_body = false
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100" # US and Europe (cheapest option)

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Ensure the distribution depends on the Lambda function being published
  depends_on = [aws_lambda_function.auth_lambda]
}

# Output the CloudFront URL
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

# Output the authentication credentials
output "auth_credentials" {
  value = "Username: lcm-user"
  sensitive = true
}
