output "cloudfront_domain" {
  description = "CloudFront distribution domain name (e.g. d1234abcd.cloudfront.net). Use as ALIAS target for Route53."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_id" {
  description = "CloudFront distribution ID — needed for cache invalidations."
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID — fixed value Z2FDTNDATAQYW2, use in Route53 alias records."
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "acm_cert_arn" {
  description = "ACM certificate ARN (us-east-1) — covers domain_name + *.domain_name."
  value       = aws_acm_certificate.main.arn
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID (passed through for downstream use)."
  value       = var.hosted_zone_id
}

output "active_record_fqdn" {
  description = "FQDN of the active.<domain> CNAME record — CloudFront origin."
  value       = aws_route53_record.active.fqdn
}

output "blue_record_fqdn" {
  description = "FQDN of the blue.<domain> CNAME record."
  value       = aws_route53_record.blue.fqdn
}

output "green_record_fqdn" {
  description = "FQDN of the green.<domain> CNAME record (null when green_enabled = false)."
  value       = var.green_enabled ? aws_route53_record.green[0].fqdn : null
}

output "waf_arn" {
  description = "WAFv2 WebACL ARN (null when waf_enabled = false)."
  value       = var.waf_enabled ? aws_wafv2_web_acl.main[0].arn : null
}

output "logs_bucket" {
  description = "S3 bucket name for CloudFront access logs."
  value       = aws_s3_bucket.logs.bucket
}
