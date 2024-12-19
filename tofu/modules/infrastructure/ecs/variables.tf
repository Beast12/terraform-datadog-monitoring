variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "services" {
  description = "Map of services to monitor"
  type = map(object({
    name         = string
    service_name = string
    task_name    = string
    cluster      = string
    thresholds = object({
      cpu_percent      = number
      memory_percent   = number # Critical threshold level in percent
      memory_available = number # Total memory allocated to the service (in MB)
      network_errors   = number
      desired_count    = number
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
