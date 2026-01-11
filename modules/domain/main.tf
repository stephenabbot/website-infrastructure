terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  domain_safe = replace(var.domain_name, ".", "-")
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket = "${local.domain_safe}-static-${var.environment}"

  tags = merge(var.tags, {
    Name   = "Static Website Bucket"
    Domain = var.domain_name
  })
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Route53 hosted zone
resource "aws_route53_zone" "website" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name   = "Website Hosted Zone"
    Domain = var.domain_name
  })
}

# Automatically update nameservers for Route53-registered domains
resource "aws_route53domains_registered_domain" "website" {
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.website.name_servers
    content {
      name = name_server.value
    }
  }

  tags = merge(var.tags, {
    Name   = "Website Domain Registration"
    Domain = var.domain_name
  })
}

# ACM certificate (apex domain and www subdomain)
resource "aws_acm_certificate" "website" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, {
    Name   = "Website Certificate"
    Domain = var.domain_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = aws_route53_zone.website.zone_id
}

resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
  timeouts {
    create = "30m"
  }
}

# Origin Access Control
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${local.domain_safe}-oac-${var.environment}"
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Response Headers Policy for security
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${local.domain_safe}-security-headers-${var.environment}"
  comment = "Security headers policy for ${var.domain_name}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none';"
      override                = true
    }
  }
}

# CloudFront function for directory index handling
resource "aws_cloudfront_function" "directory_index" {
  name    = "${local.domain_safe}-directory-index-${var.environment}"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrites directory requests to index.html for ${var.domain_name}"
  publish = true
  code    = file("${path.module}/cloudfront-function.js")
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = "S3-${aws_s3_bucket.website.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods                = ["GET", "HEAD", "OPTIONS"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "S3-${aws_s3_bucket.website.id}"
    viewer_protocol_policy         = "redirect-to-https"
    compress                       = true
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.directory_index.arn
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.website.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(var.tags, {
    Name   = "Website Distribution"
    Domain = var.domain_name
  })

  depends_on = [aws_acm_certificate_validation.website]
}

# S3 bucket policy
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

# Route53 A record
resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.website.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record for IPv6
resource "aws_route53_record" "website_ipv6" {
  zone_id = aws_route53_zone.website.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 CNAME record for www subdomain
resource "aws_route53_record" "website_www" {
  zone_id = aws_route53_zone.website.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}

# Google Site Verification TXT record (optional)
resource "aws_route53_record" "google_verification" {
  count   = var.google_site_verification != "" ? 1 : 0
  zone_id = aws_route53_zone.website.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = ["google-site-verification=${var.google_site_verification}"]
}

# Coming soon page
resource "aws_s3_object" "coming_soon" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"
  content      = var.coming_soon_content

  tags = merge(var.tags, {
    Name   = "Coming Soon Page"
    Domain = var.domain_name
  })

  lifecycle {
    ignore_changes = [content, etag, metadata]
  }
}

# Parameter Store entries
# Note: Terraform natively handles resource readiness and validation.
# The ACM certificate validation resource (aws_acm_certificate_validation) already
# waits for the certificate to be issued. CloudFront and Route53 resources are
# created in the correct dependency order automatically.
resource "aws_ssm_parameter" "bucket_name" {
  name  = "/static-website/infrastructure/${var.domain_name}/bucket-name"
  type  = "String"
  value = aws_s3_bucket.website.id
}

resource "aws_ssm_parameter" "bucket_arn" {
  name  = "/static-website/infrastructure/${var.domain_name}/bucket-arn"
  type  = "String"
  value = aws_s3_bucket.website.arn
}

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name  = "/static-website/infrastructure/${var.domain_name}/cloudfront-distribution-id"
  type  = "String"
  value = aws_cloudfront_distribution.website.id
}

resource "aws_ssm_parameter" "cloudfront_domain_name" {
  name  = "/static-website/infrastructure/${var.domain_name}/cloudfront-domain-name"
  type  = "String"
  value = aws_cloudfront_distribution.website.domain_name
}

resource "aws_ssm_parameter" "certificate_arn" {
  name  = "/static-website/infrastructure/${var.domain_name}/certificate-arn"
  type  = "String"
  value = aws_acm_certificate_validation.website.certificate_arn
}

resource "aws_ssm_parameter" "hosted_zone_id" {
  name  = "/static-website/infrastructure/${var.domain_name}/hosted-zone-id"
  type  = "String"
  value = aws_route53_zone.website.zone_id
}
