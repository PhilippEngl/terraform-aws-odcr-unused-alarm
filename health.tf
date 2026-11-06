# AWS Health's own underutilization notifications, routed to the same topic. Complementary to the
# alarms rather than a replacement: these fire only below 20 percent utilization, so a
# reservation with 2 of 3 slots used never produces one. What they add is coverage of
# reservations nobody listed, at no cost per reservation.

locals {
  health_event_type_codes = [
    # A newly created reservation below 20 percent usage over 24 hours.
    "AWS_EC2_ODCR_UNDERUTILIZATION_NOTIFICATION",
    # Every reservation below 20 percent usage over 7 days, in one event.
    "AWS_EC2_ODCR_UNDERUTILIZATION_NOTIFICATION_SUMMARY",
  ]
}

resource "aws_cloudwatch_event_rule" "health" {
  count = var.create_health_event_rule ? 1 : 0

  name        = "${var.name_prefix}-odcr-underutilization"
  description = "AWS Health EC2 ODCR underutilization notifications, forwarded to SNS"

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
    detail = {
      service       = ["EC2"]
      eventTypeCode = local.health_event_type_codes
    }
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-odcr-underutilization"
  })
}

resource "aws_cloudwatch_event_target" "health_sns" {
  count = var.create_health_event_rule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.health[0].name
  target_id = "sns"
  arn       = local.topic_arn
}
