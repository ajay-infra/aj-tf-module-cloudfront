# aj-tf-module-cloudfront

Terraform module for CloudFront CDN + WAFv2 + ACM SSL + Route53 DNS. L1 in the platform stack — provisioned once per product domain, after the EKS cluster and ALB are up.

---

## The core invariant

**CloudFront is never modified during a blue/green cluster swap.**

```
Internet → CloudFront → origin: active.platform.example.com
                                          ↕
                               Route53 CNAME record
                               active → blue ALB  (normal)
                               active → green ALB (after cutover flip)
```

CloudFront's origin is always `active.<domain>` — a CNAME record. During a blue/green upgrade:
1. Green cluster is provisioned and validated
2. `active_color = "green"` → Terraform apply → Route53 flips the CNAME
3. CloudFront starts hitting the green ALB
4. No CloudFront deployment, no cache invalidation, no distribution update

---

## What this module provisions

| Resource | Purpose |
|---|---|
| `aws_acm_certificate` | Wildcard SSL cert (`*.domain`, `domain`) in us-east-1 — required by CloudFront |
| `aws_route53_record.cert_validation` | DNS validation records for ACM cert |
| `aws_route53_record.active` | `active.<domain>` CNAME → active ALB (the origin CloudFront uses) |
| `aws_route53_record.blue` | `blue.<domain>` CNAME → blue ALB |
| `aws_route53_record.green` | `green.<domain>` CNAME → green ALB (when `green_enabled = true`) |
| `aws_route53_record.cloudfront_root` | `<domain>` A alias → CloudFront |
| `aws_route53_record.cloudfront_www` | `www.<domain>` A alias → CloudFront |
| `aws_wafv2_web_acl` | WAF with CRS, IP reputation, optional bot control, rate limiting |
| `aws_cloudfront_distribution` | CDN with TLS, cache behaviors, WAF attachment |
| `aws_s3_bucket.logs` | CloudFront access logs (90-day retention) |

---

## Blue/green cutover procedure

```bash
# 1. Validate green cluster is healthy (smoke tests, synthetic checks)

# 2. Lower active DNS TTL 24hrs before cutover
terraform apply -var-file=envs/prod.tfvars -var="active_dns_ttl=60"

# 3. Flip active_color — CloudFront starts hitting green
terraform apply -var-file=envs/prod.tfvars \
  -var="active_color=green" \
  -var="active_dns_ttl=60"

# 4. Monitor for 24-48hrs — check metrics, logs, error rates

# 5. After validation: destroy blue cluster, restore TTL
terraform apply -var-file=envs/prod.tfvars \
  -var="active_color=green" \
  -var="active_dns_ttl=300" \
  -var="green_enabled=false"
```

CloudFront distribution is **never touched** during this process. Only Route53 changes.

---

## Apply order

```
Stage 1: aj-tf-module-vpc       → VPCs provisioned
Stage 2: aj-tf-module-eks       → EKS cluster up
Stage 3: aj-infra-platform      → AWS LBC installs, Ingress creates ALB
Stage 6: aj-tf-module-cloudfront  ← this module (after ALB DNS is known)
            → blue_alb_dns = output from Ingress/LBC
```

Route53 hosted zone must exist before applying — the zone is not created by this module.

---

## WAF rules

| Rule | Priority | Action | Cost |
|---|---|---|---|
| AWSManagedRulesCommonRuleSet | 1 | Count/Block | Included |
| AWSManagedRulesAmazonIpReputationList | 2 | Count/Block | Included |
| AWSManagedRulesBotControlRuleSet | 3 | Count/Block | +$10/mo + $1/M req |
| Rate limit (1000 req/5min per IP) | 10 | Block | Included |

Bot control is disabled by default — enable for prod when bot traffic is a concern.

---

## Usage

```hcl
module "cloudfront" {
  source = "github.com/ajay-infra/aj-tf-module-cloudfront?ref=v0.1.0"

  domain_name    = "platform.example.com"
  hosted_zone_id = data.aws_route53_zone.main.zone_id

  blue_alb_dns = "k8s-frontend-blue1234.us-east-1.elb.amazonaws.com"
  active_color = "blue"

  waf_enabled   = true
  price_class   = "PriceClass_100"
  environment   = "prod"
}
```

---

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `domain_name` | yes | — | Root domain (e.g. `platform.example.com`) |
| `hosted_zone_id` | yes | — | Route53 hosted zone ID |
| `blue_alb_dns` | yes | — | Blue ALB DNS from AWS LBC Ingress |
| `green_alb_dns` | no | `""` | Green ALB DNS (required when `green_enabled = true`) |
| `green_enabled` | no | `false` | Provision `green.<domain>` record |
| `active_color` | no | `blue` | Which ALB receives CloudFront traffic |
| `active_dns_ttl` | no | `300` | TTL for `active.<domain>` — lower to 60 before cutover |
| `price_class` | no | `PriceClass_100` | CloudFront edge coverage |
| `geo_restriction_type` | no | `none` | `none` / `blacklist` / `whitelist` |
| `geo_restriction_locations` | no | `[]` | Country codes for geo restriction |
| `default_ttl` | no | `0` | Default cache TTL (0 = rely on Cache-Control) |
| `waf_enabled` | no | `true` | Attach WAFv2 to CloudFront |
| `bot_control_enabled` | no | `false` | Enable bot control (extra cost) |
| `rate_limit_per_ip` | no | `1000` | Requests per IP per 5-min before block |

---

## Outputs

| Output | Description |
|---|---|
| `cloudfront_domain` | CloudFront distribution domain (for Route53 aliases) |
| `cloudfront_id` | Distribution ID (for cache invalidations) |
| `acm_cert_arn` | ACM certificate ARN |
| `active_record_fqdn` | `active.<domain>` FQDN — CloudFront origin |
| `blue_record_fqdn` | `blue.<domain>` FQDN |
| `green_record_fqdn` | `green.<domain>` FQDN (null when disabled) |
| `waf_arn` | WAFv2 WebACL ARN (null when disabled) |
| `logs_bucket` | S3 bucket for CloudFront access logs |

---

## Provider pins

| Tool | Version |
|---|---|
| Terraform | `= 1.7.5` |
| AWS provider | `= 5.100.0` |
