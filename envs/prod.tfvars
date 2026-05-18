# envs/prod.tfvars — production CloudFront + WAF + DNS

environment = "prod"

domain_name    = "REPLACE_WITH_YOUR_DOMAIN"
hosted_zone_id = "REPLACE_WITH_HOSTED_ZONE_ID"

# Filled in from EKS + AWS LBC Ingress outputs
blue_alb_dns  = "REPLACE_WITH_BLUE_ALB_DNS"
green_alb_dns = ""
green_enabled = false

active_color   = "blue"
active_dns_ttl = 300 # lower to 60 starting 24hrs before cutover

price_class               = "PriceClass_100"
geo_restriction_type      = "none"
geo_restriction_locations = []

default_ttl = 0
max_ttl     = 86400

waf_enabled         = true
bot_control_enabled = false
rate_limit_per_ip   = 1000

team        = "infra-core"
cost_center = "infra-2026-q1"
