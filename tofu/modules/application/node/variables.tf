variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "node_services" {
  description = "Node.js service configurations for monitoring"
  type = map(object({
    name         = string
    service_name = string
    service_type = string
    alert_settings = object({
      priority     = string
      include_tags = bool
    })
    tags = map(string)
  }))
  default = {}
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
