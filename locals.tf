locals {
  name_prefix = var.name_prefix != "" ? var.name_prefix : var.environment

  # CloudFront origin always points to this CNAME — never the ALB directly.
  # Flip active_color to cut over; CloudFront distribution never changes.
  active_origin_domain = "active.${var.domain_name}"

  full_tags = merge({
    Project     = "aj-infra-platform"
    ManagedBy   = "Terraform"
    Repository  = "aj-tf-module-cloudfront"
    Environment = var.environment
    Team        = var.team
    CostCenter  = var.cost_center
  }, var.tags)
}
