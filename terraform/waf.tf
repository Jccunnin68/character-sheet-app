# AWS WAF Configuration for Geo-restriction
# This file creates WAF rules to restrict access to US, Canada, and Europe only
# WAF (Web Application Firewall) filters traffic before it reaches the ALB

# WAF Web ACL for geo-restriction
resource "aws_wafv2_web_acl" "geo_restriction" {
  name  = "${var.project_name}-${var.environment}-geo-restriction"
  scope = "REGIONAL"  # For ALB (use CLOUDFRONT for CloudFront distributions)

  # Default action: Block all traffic (whitelist approach)
  default_action {
    block {}
  }

  # Rule 1: Allow traffic from specific countries (US, Canada, Europe)
  rule {
    name     = "AllowUSCanadaEurope"
    priority = 1

    # Geographic match statement
    statement {
      geo_match_statement {
        country_codes = [
          # North America
          "US",  # United States
          "CA",  # Canada
          
          # Western Europe
          "GB",  # United Kingdom
          "IE",  # Ireland
          "FR",  # France
          "DE",  # Germany
          "IT",  # Italy
          "ES",  # Spain
          "PT",  # Portugal
          "NL",  # Netherlands
          "BE",  # Belgium
          "LU",  # Luxembourg
          "AT",  # Austria
          "CH",  # Switzerland
          "LI",  # Liechtenstein
          
          # Nordic Countries
          "SE",  # Sweden
          "NO",  # Norway
          "DK",  # Denmark
          "FI",  # Finland
          "IS",  # Iceland
          
          # Central Europe
          "PL",  # Poland
          "CZ",  # Czech Republic
          "SK",  # Slovakia
          "HU",  # Hungary
          "SI",  # Slovenia
          "HR",  # Croatia
          
          # Eastern Europe (EU members)
          "EE",  # Estonia
          "LV",  # Latvia
          "LT",  # Lithuania
          "BG",  # Bulgaria
          "RO",  # Romania
          
          # Southern Europe
          "GR",  # Greece
          "CY",  # Cyprus
          "MT",  # Malta
        ]
      }
    }

    # Allow action for matching countries
    action {
      allow {}
    }

    # CloudWatch metrics configuration
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowUSCanadaEurope"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Rate limiting to prevent abuse
  rule {
    name     = "RateLimitRule"
    priority = 2

    statement {
      rate_based_statement {
        limit              = 2000  # Requests per 5-minute window
        aggregate_key_type = "IP"  # Rate limit per IP address
      }
    }

    # Block action for rate limit violations
    action {
      block {}
    }

    # CloudWatch metrics configuration
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Block known bad IPs (optional)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    # Override action to count instead of block (for monitoring)
    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Common attack protection
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 4

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    # Override action to count instead of block (for initial testing)
    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Overall WAF metrics
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}WAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-waf"
    Environment = var.environment
    Purpose     = "Geo-restriction and security protection"
  }
}

# CloudWatch Log Group for WAF logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/wafv2/${var.project_name}-${var.environment}"
  retention_in_days = 7  # Keep logs for 7 days (cost optimization)

  tags = {
    Name        = "${var.project_name}-${var.environment}-waf-logs"
    Environment = var.environment
  }
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  resource_arn            = aws_wafv2_web_acl.geo_restriction.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]

  # Redact sensitive fields from logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_wafv2_web_acl.geo_restriction]
}

# Output the WAF ARN for use in ALB/Ingress
output "waf_acl_arn" {
  description = "ARN of the WAF Web ACL for geo-restriction"
  value       = aws_wafv2_web_acl.geo_restriction.arn
}

# CloudWatch Dashboard for WAF monitoring
resource "aws_cloudwatch_dashboard" "waf_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-waf-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.geo_restriction.name, "Region", var.aws_region, "Rule", "ALL"],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", "."],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "WAF Request Overview"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.geo_restriction.name, "Region", var.aws_region, "Rule", "AllowUSCanadaEurope"],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", "."],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Geo-restriction Rule Activity"
          period  = 300
        }
      }
    ]
  })
} 