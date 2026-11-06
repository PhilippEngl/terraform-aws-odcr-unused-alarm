variable "region" {
  description = "Region the reservations live in. Capacity Reservation metrics are regional, so the alarms must be created where the reservations are."
  type        = string
  default     = "eu-central-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name the module creates"
  type        = string
  default     = "demo"
}

variable "capacity_reservation_ids" {
  description = "Reservations to alarm on individually"
  type        = list(string)
  default = [
    "cr-00000000000000001",
    "cr-00000000000000002",
  ]
}

variable "instance_types" {
  description = "Instance types to alarm on in aggregate"
  type        = list(string)
  default     = ["m8id.16xlarge"]
}

variable "email_subscriptions" {
  description = "Addresses to notify. Each must confirm the subscription before it receives anything."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every taggable resource"
  type        = map(string)
  default     = {}
}
