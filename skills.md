# skills.md — aj-tf-module-cloudfront

## Purpose
Provisions a CloudFront distribution, Route53 DNS, ACM certificate, and WAF integration.
Blue/green cutover is a hard CNAME flip (`active_color` moves `active.<domain>` from
blue ALB to green ALB in one apply) — NOT weighted/gradual traffic splitting. The
CloudFront distribution itself is never modified during cutover; only the Route53
record behind its origin changes.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajay-infra/aj-tf-module-cloudfront?ref=v1.0.0"
```

## Key inputs
| Variable | Description |
|---|---|
| `environment` | dev \| staging \| uat \| prod |
| `name_prefix` | Resource name prefix |
| `domain_name` | Public domain name |
| `hosted_zone_id` | Route53 hosted zone ID |
| `blue_alb_dns` | Blue ALB DNS name (origin) |
| `green_alb_dns` | Green ALB DNS name (origin) |
| `green_enabled` | Enable green origin |
| `active_color` | blue \| green — active origin |

## AWS tags applied
`Project`, `ManagedBy`, `Repository`, `Environment`, `Team`, `CostCenter` (set in
`locals.full_tags`), plus whatever's in `var.tags`. No `Env`, `Model`, or `Customer`
tag exists in this module.

## Branching convention
- `main` — active development
- semver tags (`v1.0.0`, ...) — stable pinned releases, per `README.md` usage examples

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Validate active_color matches live cluster color
- Detect missing WAF association in prod
- Generate PR to flip active_color during blue/green cutover
- Check cache behavior headers for security (HSTS, CSP)
