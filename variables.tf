# --- Naming and tagging ------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for every resource name this module creates. Names are derived as <name_prefix>-odcr-unused-<scope>."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,40}$", var.name_prefix))
    error_message = "name_prefix must start with a lowercase letter, contain only lowercase letters, digits and dashes, and be 41 characters or fewer. The binding limit is the EventBridge rule, whose name appends -odcr-underutilization and may be at most 64 characters."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource. Merged with a Name tag the module sets itself, which takes precedence."
  type        = map(string)
  default     = {}
}

# --- What to alarm on --------------------------------------------------------

variable "capacity_reservation_ids" {
  description = "Capacity Reservations to alarm on, one alarm each. The most precise option: the alarm names the idle reservation. The cost is that a reservation created later is not covered until its ID is added here — instance_types and create_account_wide_alarm close that gap."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.capacity_reservation_ids : can(regex("^cr-[0-9a-f]{17}$", id))])
    error_message = "Every entry in capacity_reservation_ids must look like cr- followed by 17 hexadecimal characters."
  }
}

variable "instance_types" {
  description = "Instance types to alarm on, one alarm each, summing every reservation of that type in the account and region. Covers reservations created after apply without a Terraform change, and does not say which reservation is idle."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for t in var.instance_types : can(regex("^[a-z0-9-]+\\.[a-z0-9-]+$", t))])
    error_message = "Every entry in instance_types must be an EC2 instance type such as m8id.16xlarge."
  }
}

variable "create_account_wide_alarm" {
  description = "Whether to create one alarm on the dimensionless metric, which aggregates every reservation in the account and region. The widest net, and the one that fires for a reservation nobody told Terraform about."
  type        = bool
  default     = false
}

# --- How the alarms evaluate -------------------------------------------------

variable "unused_threshold" {
  description = "Unused slots tolerated before the alarm fires. The alarm fires when the minimum AvailableInstanceCount stays above this for evaluation_hours. Zero means any idle slot alarms. Raise it for reservations deliberately sized with headroom, such as one spare per AZ for node replacement."
  type        = number
  default     = 0

  validation {
    condition     = var.unused_threshold >= 0 && floor(var.unused_threshold) == var.unused_threshold
    error_message = "unused_threshold must be a whole number of zero or more."
  }
}

variable "evaluation_hours" {
  description = "Consecutive hours a slot must stay unused before the alarm fires. Each hour is evaluated on its Minimum, so a slot freed for a few minutes during a rolling node replacement does not count. CloudWatch caps period times evaluation periods at seven days."
  type        = number
  default     = 6

  validation {
    condition     = var.evaluation_hours >= 1 && var.evaluation_hours <= 168 && floor(var.evaluation_hours) == var.evaluation_hours
    error_message = "evaluation_hours must be a whole number from 1 to 168. CloudWatch rejects an alarm whose period times evaluation periods exceeds seven days."
  }
}

variable "treat_missing_data" {
  description = "How the alarms treat periods with no data. notBreaching suits this metric: a reservation that is cancelled or expired stops publishing, and its alarm should settle in OK rather than sit in INSUFFICIENT_DATA."
  type        = string
  default     = "notBreaching"

  validation {
    condition     = contains(["breaching", "notBreaching", "ignore", "missing"], var.treat_missing_data)
    error_message = "treat_missing_data must be one of breaching, notBreaching, ignore or missing."
  }
}

# --- Notifications -----------------------------------------------------------

variable "create_sns_topic" {
  description = "Whether this module creates the SNS topic the alarms and the Health rule publish to. Set false with sns_topic_arn to use a topic someone else owns; that topic's policy must already allow cloudwatch.amazonaws.com, and events.amazonaws.com if create_health_event_rule is true."
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "Existing SNS topic to publish to. Required when create_sns_topic is false, ignored otherwise."
  type        = string
  default     = null

  validation {
    condition     = var.create_sns_topic || var.sns_topic_arn != null
    error_message = "create_sns_topic is false, so sns_topic_arn must name the topic to publish to."
  }
}

variable "sns_kms_master_key_id" {
  description = "KMS key encrypting the topic this module creates. Null leaves it unencrypted. Do not use alias/aws/sns: its key policy cannot be changed to let CloudWatch and EventBridge use it, so publishes fail and nothing reports the failure. A customer-managed key must grant cloudwatch.amazonaws.com and events.amazonaws.com kms:GenerateDataKey* and kms:Decrypt."
  type        = string
  default     = null

  validation {
    condition     = var.sns_kms_master_key_id == null || !can(regex("alias/aws/sns$", coalesce(var.sns_kms_master_key_id, "-")))
    error_message = "sns_kms_master_key_id must not be the AWS-managed alias/aws/sns key: CloudWatch alarms and EventBridge cannot publish to a topic encrypted with it."
  }
}

variable "email_subscriptions" {
  description = "Email addresses subscribed to the topic. Each stays PendingConfirmation until its owner clicks the link AWS sends, and receives nothing until then — Terraform reports success either way."
  type        = list(string)
  default     = []
}

variable "additional_alarm_actions" {
  description = "Further action ARNs on every alarm, for example a Lambda function or a second topic. CloudWatch allows five actions per state and the topic takes one."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.additional_alarm_actions) <= 4
    error_message = "additional_alarm_actions may hold at most four ARNs: CloudWatch allows five alarm actions and the module's topic is one of them."
  }
}

variable "send_ok_notifications" {
  description = "Whether alarms also notify on the transition back to OK. On by default, because \"the reservation is used again\" is the confirmation that a launch template fix worked."
  type        = bool
  default     = true
}

# --- AWS Health --------------------------------------------------------------

variable "create_health_event_rule" {
  description = "Whether to forward AWS Health's EC2 ODCR underutilization events to the topic. Those fire only below 20 percent utilization, so they miss a partly used reservation the alarms catch, but they cover every reservation in the region without listing any. Off by default because the account's root email already receives them."
  type        = bool
  default     = false
}
