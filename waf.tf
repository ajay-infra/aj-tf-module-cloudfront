# ── WAFv2 Web ACL ─────────────────────────────────────────────────────────────
# scope = CLOUDFRONT requires this resource to be in us-east-1.
# Attached to the CloudFront distribution — enforced at edge locations globally.

resource "aws_wafv2_web_acl" "main" {
  count = var.waf_enabled ? 1 : 0

  name        = "${local.name_prefix}-cloudfront"
  description = "WAF for CloudFront — SQLi, XSS, IP reputation, rate limiting"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # ── Rule 1: Common threat protection (SQLi, XSS, path traversal) ─────────
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 2: Block known malicious IPs ─────────────────────────────────────
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 3: Bot control (optional — extra cost) ───────────────────────────
  dynamic "rule" {
    for_each = var.bot_control_enabled ? [1] : []
    content {
      name     = "AWSManagedRulesBotControlRuleSet"
      priority = 3

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"

          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = "COMMON"
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-bot-control"
        sampled_requests_enabled   = true
      }
    }
  }

  # ── Rule 4: Rate limiting per IP ─────────────────────────────────────────
  rule {
    name     = "RateLimitPerIP"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_ip
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = local.full_tags
}
