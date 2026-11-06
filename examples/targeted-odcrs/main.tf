provider "aws" {
  region = var.region
}

module "odcr_unused_alarm" {
  source = "../.."

  name_prefix = var.name_prefix

  # Precise alarms for the reservations someone is actively trying to fill.
  capacity_reservation_ids = var.capacity_reservation_ids

  # And a net for any reservation of these types created later.
  instance_types = var.instance_types

  # Node group rolling replacements free a slot for minutes, not hours.
  evaluation_hours = 6

  email_subscriptions = var.email_subscriptions

  create_health_event_rule = true

  tags = var.tags
}
