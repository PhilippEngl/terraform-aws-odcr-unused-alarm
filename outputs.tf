output "sns_topic_arn" {
  description = "Topic the alarms and the Health rule publish to, whether this module created it or was given it"
  value       = local.topic_arn
}

output "capacity_reservation_alarm_arns" {
  description = "Per-reservation alarm ARNs, keyed by Capacity Reservation ID"
  value       = { for id, alarm in aws_cloudwatch_metric_alarm.capacity_reservation : id => alarm.arn }
}

output "instance_type_alarm_arns" {
  description = "Per-instance-type alarm ARNs, keyed by instance type"
  value       = { for t, alarm in aws_cloudwatch_metric_alarm.instance_type : t => alarm.arn }
}

output "account_alarm_arn" {
  description = "Account-wide alarm ARN, or null when create_account_wide_alarm is false"
  value       = try(aws_cloudwatch_metric_alarm.account[0].arn, null)
}

output "health_event_rule_arn" {
  description = "EventBridge rule forwarding AWS Health underutilization events, or null when create_health_event_rule is false"
  value       = try(aws_cloudwatch_event_rule.health[0].arn, null)
}

output "pending_email_subscriptions" {
  description = "Email addresses subscribed to the topic. Listed so nobody forgets that each one has to confirm before it receives anything."
  value       = var.email_subscriptions
}
