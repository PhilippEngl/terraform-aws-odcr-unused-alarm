output "sns_topic_arn" {
  description = "Topic the alarms publish to"
  value       = module.odcr_unused_alarm.sns_topic_arn
}

output "capacity_reservation_alarm_arns" {
  description = "Per-reservation alarm ARNs, keyed by Capacity Reservation ID"
  value       = module.odcr_unused_alarm.capacity_reservation_alarm_arns
}

output "instance_type_alarm_arns" {
  description = "Per-instance-type alarm ARNs, keyed by instance type"
  value       = module.odcr_unused_alarm.instance_type_alarm_arns
}
