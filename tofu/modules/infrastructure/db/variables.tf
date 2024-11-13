variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "databases" {
  description = "Map of databases to monitor"
  type = map(object({
    name         = string
    type         = string # "aurora" or "rds"
    identifier   = string # cluster identifier for Aurora, instance identifier for RDS
    service_name = string
    thresholds = object({
      cpu_percent          = number
      memory_threshold     = number
      connection_threshold = number
      iops_threshold       = number
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
