mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:eu-central-1:111122223333:demo-odcr-unused"
    }
  }
}

variables {
  capacity_reservation_ids = ["cr-00fdff2791968ad98", "cr-0f3bcc4d551ccdac0"]
}


run "one_alarm_per_reservation_on_the_right_metric" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.capacity_reservation) == 2
    error_message = "Expected one alarm per entry in capacity_reservation_ids."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.capacity_reservation["cr-00fdff2791968ad98"].dimensions["CapacityReservationId"] == "cr-00fdff2791968ad98"
    error_message = "Each per-reservation alarm must be scoped to its own reservation."
  }

  assert {
    condition = alltrue([
      for a in aws_cloudwatch_metric_alarm.capacity_reservation :
      a.namespace == "AWS/EC2CapacityReservations" && a.metric_name == "AvailableInstanceCount"
    ])
    error_message = "Alarms must watch AWS/EC2CapacityReservations AvailableInstanceCount."
  }
}

run "a_brief_gap_does_not_alarm" {
  command = plan

  # Minimum over one-hour periods, every period breaching: a slot freed for minutes during a
  # node replacement never makes an hour's minimum non-zero.
  assert {
    condition = alltrue([
      for a in aws_cloudwatch_metric_alarm.capacity_reservation :
      a.statistic == "Minimum" && a.period == 3600 && a.evaluation_periods == 6 && a.datapoints_to_alarm == 6
    ])
    error_message = "Defaults must be Minimum over six consecutive one-hour periods."
  }

  assert {
    condition = alltrue([
      for a in aws_cloudwatch_metric_alarm.capacity_reservation :
      a.comparison_operator == "GreaterThanThreshold" && a.threshold == 0
    ])
    error_message = "The default must alarm on any unused slot."
  }
}

run "nothing_optional_is_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.instance_type) == 0 && length(aws_cloudwatch_metric_alarm.account) == 0
    error_message = "Instance-type and account-wide alarms must be opt-in."
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.health) == 0
    error_message = "The Health rule must be opt-in."
  }

  assert {
    condition     = length(aws_sns_topic.this) == 1
    error_message = "The module creates its own topic by default."
  }
}

run "instance_type_alarm_names_are_shell_safe" {
  command = plan

  variables {
    instance_types = ["m8id.16xlarge"]
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.instance_type["m8id.16xlarge"].alarm_name == "demo-odcr-unused-type-m8id-16xlarge"
    error_message = "Dots in the instance type must become dashes in the alarm name."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.instance_type["m8id.16xlarge"].dimensions["InstanceType"] == "m8id.16xlarge"
    error_message = "The dimension value must keep the real instance type."
  }
}

run "account_wide_alarm_has_no_dimensions" {
  command = plan

  variables {
    create_account_wide_alarm = true
  }

  assert {
    condition     = try(length(aws_cloudwatch_metric_alarm.account[0].dimensions), 0) == 0
    error_message = "The account-wide alarm must use the dimensionless metric."
  }
}

run "ok_notifications_can_be_turned_off" {
  command = plan

  variables {
    send_ok_notifications = false
  }

  assert {
    condition = alltrue([
      for a in aws_cloudwatch_metric_alarm.capacity_reservation : length(a.ok_actions) == 0
    ])
    error_message = "ok_actions must be empty when send_ok_notifications is false."
  }
}

run "an_existing_topic_replaces_the_module_topic" {
  command = plan

  variables {
    create_sns_topic         = false
    sns_topic_arn            = "arn:aws:sns:eu-central-1:111122223333:existing"
    create_health_event_rule = true
  }

  assert {
    condition     = length(aws_sns_topic.this) == 0
    error_message = "No topic may be created when create_sns_topic is false."
  }

  assert {
    condition     = output.sns_topic_arn == "arn:aws:sns:eu-central-1:111122223333:existing"
    error_message = "Alarms must publish to the supplied topic."
  }

  assert {
    condition     = aws_cloudwatch_event_target.health_sns[0].arn == "arn:aws:sns:eu-central-1:111122223333:existing"
    error_message = "The Health rule must target the supplied topic."
  }
}

run "no_topic_and_no_arn_is_rejected" {
  command = plan

  variables {
    create_sns_topic = false
  }

  expect_failures = [var.sns_topic_arn]
}

run "aws_managed_sns_key_is_rejected" {
  command = plan

  variables {
    sns_kms_master_key_id = "alias/aws/sns"
  }

  expect_failures = [var.sns_kms_master_key_id]
}

run "evaluation_longer_than_seven_days_is_rejected" {
  command = plan

  variables {
    evaluation_hours = 169
  }

  expect_failures = [var.evaluation_hours]
}

run "malformed_reservation_id_is_rejected" {
  command = plan

  variables {
    capacity_reservation_ids = ["cr-123"]
  }

  expect_failures = [var.capacity_reservation_ids]
}

run "too_many_alarm_actions_is_rejected" {
  command = plan

  variables {
    additional_alarm_actions = [
      "arn:aws:sns:eu-central-1:111122223333:a",
      "arn:aws:sns:eu-central-1:111122223333:b",
      "arn:aws:sns:eu-central-1:111122223333:c",
      "arn:aws:sns:eu-central-1:111122223333:d",
      "arn:aws:sns:eu-central-1:111122223333:e",
    ]
  }

  expect_failures = [var.additional_alarm_actions]
}

run "the_longest_prefix_fits_the_rule_name" {
  command = plan

  variables {
    name_prefix              = "aaaaaaaaaa-bbbbbbbbbb-cccccccccc-dddddddd" # 41 characters
    create_health_event_rule = true
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.health[0].name) <= 64
    error_message = "EventBridge rule names may be at most 64 characters."
  }
}

run "too_long_a_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "aaaaaaaaaa-bbbbbbbbbb-cccccccccc-ddddddddd" # 42 characters
  }

  expect_failures = [var.name_prefix]
}
