variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "queues" {
  description = "Map of queues to monitor"
  type = map(object({
    name         = string
    service_name = string # For unified service tagging
    queue_name   = string
    dlq_name     = optional(string)
    thresholds = object({
      age_threshold   = number
      depth_threshold = number
      dlq_threshold   = optional(number)
    })
    alert_settings = object({
      priority     = string
      include_tags = bool
    })
    tags = map(string)
  }))
}

variable "notification_channels" {
  description = "Notification channel configuration"
  type = object({
    infrastructure = map(string)
    messaging      = map(string)
    application    = map(string)
    logs           = string
    default        = string
  })
}

variable "tags" {
  description = "Common tags to apply to all monitors"
  type        = map(string)
  default     = {}
}
