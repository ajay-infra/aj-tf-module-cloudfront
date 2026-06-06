# skills.md — aj-tf-module-cloudfront

## Purpose
Provisions a CloudFront distribution with blue/green origin support, Route53 DNS, ACM certificate, and WAF integration for blue/green ALB traffic splitting.

## Type
`tf-module`

## Stable ref
```
source = "github.com/ajaylakma/aj-tf-module-cloudfront?ref=cloudfront-01"
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
`Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer`

## Branching convention
- `main` — active development
- `cloudfront-01` — stable pinned release

## CI checks
fmt, validate, plan (dry-run), tfsec/checkov

## Agentic capabilities
- Validate active_color matches live cluster color
- Detect missing WAF association in prod
- Generate PR to flip active_color during blue/green cutover
- Check cache behavior headers for security (HSTS, CSP)
