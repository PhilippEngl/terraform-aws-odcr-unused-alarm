data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name = "${var.name_prefix}-odcr-unused"

  # Validation on sns_topic_arn guarantees one of the two is set.
  topic_arn = var.create_sns_topic ? aws_sns_topic.this[0].arn : var.sns_topic_arn

  alarm_actions = concat([local.topic_arn], var.additional_alarm_actions)
  ok_actions    = var.send_ok_notifications ? local.alarm_actions : []

  # Capacity Reservation metrics arrive every five minutes. One-hour periods with the Minimum
  # statistic mean a slot has to be unused for the whole hour to count, so a node group rolling
  # update — which frees a slot for a few minutes and then fills it again — does not page anyone.
  period_seconds = 3600
}
