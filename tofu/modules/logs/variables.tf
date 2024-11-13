variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "logs" {
  description = "Log monitoring configurations for each service"
  type = map(object({
    name         = string
    query        = string
    service_name = string
    alert_settings = object({
      priority     = string
      include_tags = bool
    })
    thresholds = object({
      critical          = number
      critical_recovery = number
      warning           = number
      warning_recovery  = number
    })
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
