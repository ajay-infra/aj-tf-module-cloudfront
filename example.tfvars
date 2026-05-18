# example.tfvars — CI dry-run plan (no real AWS credentials required)

environment = "prod"

# Domain + Route53
domain_name    = "platform.example.com"
hosted_zone_id = "Z1234567890ABCDEF0000"

# ALB origins (placeholder DNS names from EKS + AWS LBC)
blue_alb_dns  = "k8s-frontend-blue1234-1234567890.us-east-1.elb.amazonaws.com"
green_alb_dns = ""
green_enabled = false

# Normally blue is active; flip to green after cutover is validated
active_color   = "blue"
active_dns_ttl = 300

# CloudFront
price_class = "PriceClass_100"

# Geo restriction — none by default
geo_restriction_type      = "none"
geo_restriction_locations = []

# Cache TTL — 0 for dynamic app (rely on Cache-Control headers)
default_ttl = 0
max_ttl     = 86400

# WAF
waf_enabled         = true
bot_control_enabled = false
rate_limit_per_ip   = 1000

team        = "infra-core"
cost_center = "infra-2026-q1"
