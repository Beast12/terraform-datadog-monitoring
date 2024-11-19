variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb" { # Add this variable declaration
  description = "Map of ALB configurations"
  type = map(object({
    name         = string
    alb_name     = string
    service_name = string
    thresholds = object({
      request_count = optional(number)
      latency       = optional(number)
      error_rate    = optional(number)
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
