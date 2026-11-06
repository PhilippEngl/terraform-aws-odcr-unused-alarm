# Three resources rather than one for_each over a merged map. The dimensions differ in shape —
# one key, a different key, none at all — and keeping them apart keeps the outputs keyed by
# what the caller passed in rather than by a synthetic composite key.

# --- One alarm per Capacity Reservation ---------------------------------------

resource "aws_cloudwatch_metric_alarm" "capacity_reservation" {
  for_each = toset(var.capacity_reservation_ids)

  alarm_name        = "${local.name}-${each.key}"
  alarm_description = "Capacity Reservation ${each.key} has had more than ${var.unused_threshold} unused slot(s) for ${var.evaluation_hours} hour(s). Unused reserved capacity is billed at the On-Demand rate. A common cause is a targeted reservation next to instances whose launch template does not name it: preference open does not match a targeted reservation."

  namespace   = "AWS/EC2CapacityReservations"
  metric_name = "AvailableInstanceCount"
  dimensions = {
    CapacityReservationId = each.key
  }

  statistic           = "Minimum"
  period              = local.period_seconds
  evaluation_periods  = var.evaluation_hours
  datapoints_to_alarm = var.evaluation_hours
  threshold           = var.unused_threshold
  comparison_operator = "GreaterThanThreshold"

  # A cancelled or expired reservation stops publishing. notBreaching lets its alarm go to OK
  # instead of sitting in INSUFFICIENT_DATA forever; delete the ID from the list to remove it.
  treat_missing_data = var.treat_missing_data

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(var.tags, {
    Name = "${local.name}-${each.key}"
  })
}

# --- One alarm per instance type, across every reservation of that type ------

resource "aws_cloudwatch_metric_alarm" "instance_type" {
  for_each = toset(var.instance_types)

  # Dots are legal in an alarm name, but dashes keep the name consistent with the others and
  # safe to paste into a shell without quoting.
  alarm_name        = "${local.name}-type-${replace(each.key, ".", "-")}"
  alarm_description = "Capacity Reservations of type ${each.key} in this account and region have had more than ${var.unused_threshold} unused slot(s) in total for ${var.evaluation_hours} hour(s). Covers reservations created after this alarm without a Terraform change; does not say which reservation is idle."

  namespace   = "AWS/EC2CapacityReservations"
  metric_name = "AvailableInstanceCount"
  dimensions = {
    InstanceType = each.key
  }

  statistic           = "Minimum"
  period              = local.period_seconds
  evaluation_periods  = var.evaluation_hours
  datapoints_to_alarm = var.evaluation_hours
  threshold           = var.unused_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = var.treat_missing_data

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(var.tags, {
    Name = "${local.name}-type-${replace(each.key, ".", "-")}"
  })
}

# --- One alarm for every reservation in the account and region ---------------

resource "aws_cloudwatch_metric_alarm" "account" {
  count = var.create_account_wide_alarm ? 1 : 0

  alarm_name        = "${local.name}-all"
  alarm_description = "All Capacity Reservations in this account and region together have had more than ${var.unused_threshold} unused slot(s) for ${var.evaluation_hours} hour(s). Widest net, least detail: use the per-reservation alarms to find which one."

  # No dimensions: the metric with no dimension aggregates every reservation in the account
  # and region.
  namespace   = "AWS/EC2CapacityReservations"
  metric_name = "AvailableInstanceCount"

  statistic           = "Minimum"
  period              = local.period_seconds
  evaluation_periods  = var.evaluation_hours
  datapoints_to_alarm = var.evaluation_hours
  threshold           = var.unused_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = var.treat_missing_data

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = merge(var.tags, {
    Name = "${local.name}-all"
  })
}
