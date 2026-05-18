# ── Route53 Records ───────────────────────────────────────────────────────────

# blue.<domain> → blue ALB (always present)
resource "aws_route53_record" "blue" {
  zone_id = var.hosted_zone_id
  name    = "blue.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.blue_alb_dns]
}

# green.<domain> → green ALB (only when green cluster is live)
resource "aws_route53_record" "green" {
  count = var.green_enabled ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = "green.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.green_alb_dns]
}

# active.<domain> → the currently active ALB
# This is the ONLY record that changes during a blue/green cutover.
# CloudFront origin points here — the distribution itself never changes.
# Lower active_dns_ttl to 60s starting 24hrs before a cutover window.
resource "aws_route53_record" "active" {
  zone_id = var.hosted_zone_id
  name    = local.active_origin_domain
  type    = "CNAME"
  ttl     = var.active_dns_ttl
  records = [var.active_color == "blue" ? var.blue_alb_dns : var.green_alb_dns]
}

# Root domain → CloudFront distribution (A alias record)
resource "aws_route53_record" "cloudfront_root" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# www.<domain> → CloudFront (alias)
resource "aws_route53_record" "cloudfront_www" {
  zone_id = var.hosted_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# ── CloudFront Distribution ───────────────────────────────────────────────────
# Origin: active.<domain> — never the ALB directly.
# During blue/green swap: only the Route53 active record flips.
# This distribution is provisioned once and never modified for cluster upgrades.

resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = local.active_origin_domain
    origin_id   = "active-alb"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }

    custom_header {
      name  = "X-Forwarded-Proto"
      value = "https"
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  http_version    = "http2and3"

  aliases = [var.domain_name, "www.${var.domain_name}"]

  web_acl_id = var.waf_enabled ? aws_wafv2_web_acl.main[0].arn : null

  # Default cache behavior — passthrough for dynamic app content
  default_cache_behavior {
    target_origin_id       = "active-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = true

      headers = [
        "Accept",
        "Accept-Language",
        "Authorization",
        "CloudFront-Forwarded-Proto",
        "Host",
        "Origin",
        "Referer",
      ]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  # Cache behavior for static assets (if served from same origin)
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "active-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400    # 1 day for static assets
    max_ttl     = 31536000 # 1 year max
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront/"
  }

  tags = local.full_tags

  depends_on = [aws_acm_certificate_validation.main]
}

# ── Access Logs S3 Bucket ─────────────────────────────────────────────────────

resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name_prefix}-cloudfront-logs-${var.domain_name}"
  force_destroy = var.environment != "prod"

  tags = local.full_tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]

  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
