# ── Core ──────────────────────────────────────────────────────────────────────

variable "environment" {
  type    = string
  default = "prod"
}

variable "name_prefix" {
  type    = string
  default = ""
}

# ── DNS ───────────────────────────────────────────────────────────────────────

variable "domain_name" {
  type        = string
  description = "Root domain name (e.g. platform.example.com). CloudFront serves this + *.<domain>."
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for the domain. ACM validation and all records are created here."
}

# ── ALB Origins ───────────────────────────────────────────────────────────────

variable "blue_alb_dns" {
  type        = string
  description = "Blue EKS cluster ALB DNS name (from AWS LBC Ingress). Always required."
}

variable "green_alb_dns" {
  type        = string
  description = "Green EKS cluster ALB DNS name. Only needed when green_enabled = true."
  default     = ""
}

variable "green_enabled" {
  type        = bool
  description = "Provision the green Route53 record. Set true only when green cluster is live."
  default     = false
}

variable "active_color" {
  type        = string
  description = <<-EOT
    Which ALB receives traffic from CloudFront.
    blue  = normal operation
    green = cutover complete, all traffic on green

    CloudFront origin always points to active.<domain> CNAME.
    Changing active_color flips the CNAME → triggers Route53 propagation.
    CloudFront distribution itself is NEVER modified during a blue/green swap.
  EOT
  default     = "blue"
  validation {
    condition     = contains(["blue", "green"], var.active_color)
    error_message = "active_color must be 'blue' or 'green'."
  }
}

variable "active_dns_ttl" {
  type        = number
  description = <<-EOT
    TTL for the active.<domain> CNAME record in seconds.
    Lower TTL before a cutover so DNS propagates faster.
    Recommended: 300 normally → 60 starting 24hrs before cutover window.
  EOT
  default     = 300
}

# ── CloudFront ────────────────────────────────────────────────────────────────

variable "price_class" {
  type        = string
  description = <<-EOT
    CloudFront edge location coverage.
    PriceClass_100  — US, Canada, Europe (lowest cost)
    PriceClass_200  — + South America, Asia, Middle East, Africa
    PriceClass_All  — all edge locations (lowest latency worldwide, highest cost)
  EOT
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "geo_restriction_type" {
  type        = string
  description = "Geo restriction mode: none | blacklist | whitelist."
  default     = "none"
  validation {
    condition     = contains(["none", "blacklist", "whitelist"], var.geo_restriction_type)
    error_message = "geo_restriction_type must be none, blacklist, or whitelist."
  }
}

variable "geo_restriction_locations" {
  type        = list(string)
  description = "ISO 3166-1 alpha-2 country codes for geo restriction. Empty when type = none."
  default     = []
}

variable "default_ttl" {
  type        = number
  description = "Default cache TTL in seconds. Set 0 for dynamic applications (rely on Cache-Control headers)."
  default     = 0
}

variable "max_ttl" {
  type        = number
  description = "Maximum cache TTL in seconds."
  default     = 86400
}

# ── WAF ───────────────────────────────────────────────────────────────────────

variable "waf_enabled" {
  type        = bool
  description = "Attach a WAFv2 WebACL to the CloudFront distribution."
  default     = true
}

variable "bot_control_enabled" {
  type        = bool
  description = <<-EOT
    Enable AWSManagedRulesBotControlRuleSet. Adds bot protection but costs extra.
    ~$10/month + $1/million requests. Enable for prod only when needed.
  EOT
  default     = false
}

variable "rate_limit_per_ip" {
  type        = number
  description = "Maximum requests per IP per 5-minute window before WAF blocks."
  default     = 1000
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "team" {
  type    = string
  default = "infra-core"
}

variable "cost_center" {
  type    = string
  default = "infra-2026-q1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
