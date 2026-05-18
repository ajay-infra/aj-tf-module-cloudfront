# CLAUDE.md — aj-tf-module-cloudfront

> Local context file for Claude Code. Not pushed to GitHub.

## What This Module Does

L1 — CloudFront CDN + WAFv2 + ACM SSL + Route53 DNS.
Provisioned once per domain after EKS + ALB are live.

Core invariant: CloudFront origin is always active.<domain> CNAME.
During blue/green swap: only active_color changes → Route53 flips → done.
CloudFront distribution is NEVER modified during cluster upgrades.

## Where It Fits

**Architecture layer:** L1 — Edge (CDN + WAF + DNS)
**Provisioned by:** Run once per domain after EKS + ALB + Ingress are live
**State key:** `workload/<mode>/<env>/cloudfront/terraform.tfstate` (planned)
**Depends on:** ALB DNS name from AWS LBC after Ingress is created on the workload cluster

## How to Use

Run after the workload cluster is up and the application Ingress is deployed (AWS LBC creates the ALB):

```bash
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=workload/blue-green/<env>/cloudfront/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"

terraform apply -var-file=envs/prod.tfvars \
  -var="blue_alb_dns=<alb-dns-from-kubectl-get-ingress>" \
  -var="active_color=blue"
```

Blue/green cutover: change `active_color` from `blue` to `green` and re-apply. Route53 flips `active.<domain>` CNAME — CloudFront distribution is never modified.

Lower `active_dns_ttl` to `60` in the tfvars 24 hours before a planned cutover to reduce propagation delay.

## Module Structure

```
acm.tf       → aws_acm_certificate (wildcard), aws_route53_record (DNS validation),
               aws_acm_certificate_validation
waf.tf       → aws_wafv2_web_acl (4 rules: CRS, IP reputation, bot control, rate limit)
main.tf      → aws_route53_record (active/blue/green/root/www),
               aws_cloudfront_distribution,
               aws_s3_bucket (access logs + lifecycle + encryption)
variables.tf → domain_name, hosted_zone_id, blue_alb_dns, green_alb_dns,
               active_color, active_dns_ttl, price_class, waf_enabled, etc.
locals.tf    → name_prefix, active_origin_domain, full_tags
outputs.tf   → cloudfront_domain, cloudfront_id, acm_cert_arn, active/blue/green fqdns
providers.tf → aws provider hardcoded to us-east-1 (CloudFront + WAF requirement)
```

## Key Design Decisions

- **us-east-1 always** — CloudFront, WAF CLOUDFRONT scope, and ACM for CloudFront
  all require us-east-1. Provider is hardcoded (no variable), cannot be overridden.
- **active.<domain> CNAME** — CloudFront origin is this CNAME, not the ALB directly.
  Flip active_color = "green" → Terraform apply → Route53 updates → CloudFront hits green.
  Distribution never modified = no CloudFront deployment delay (15-30 min) during cutover.
- **lower active_dns_ttl to 60 before cutover** — 300s TTL means 5 min max propagation;
  60s = faster flip. Lower TTL 24hrs before the maintenance window starts.
- **WAF scope = CLOUDFRONT** — WAF must be in us-east-1 to attach to CloudFront.
  Same restriction as ACM.
- **ACM wildcard cert** — covers *.domain_name and domain_name with one cert.
  Validated via DNS (Route53 CNAME records auto-created by this module).
- **S3 log bucket force_destroy** — true in non-prod (easy teardown); false in prod.

## Known TODOs

- [ ] Fill in domain_name + hosted_zone_id in envs/prod.tfvars
- [ ] Fill in blue_alb_dns after ALB is provisioned (EKS + AWS LBC + Ingress)
- [ ] Consider bot_control_enabled = true once real traffic is on the domain
- [ ] Add custom WAF rules if specific attack patterns are observed in logs
