variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
}

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
    cluster      = string
    service_name = string
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

variable "alb" {
  description = "Configuration for ALB services"
  type = map(object({
    name         = string
    alb_name     = string
    service_name = string
    thresholds = object({
      request_count = number
      latency       = number
      error_rate    = number
    })
    alert_settings = object({
      priority     = string
      include_tags = bool
    })
    tags = map(string)
  }))
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

variable "topics" {
  description = "Map of SNS topics to monitor"
  type = map(object({
    name         = string
    service_name = string # For unified service tagging
    topic_name   = string
    thresholds = object({
      message_count_threshold = number
      age_threshold           = number
    })
    alert_settings = object({
      priority     = string
      include_tags = bool
    })
    tags = map(string)
  }))
}

variable "java_services" {
  description = "Configuration for Java services"
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

variable "apm_services" {
  description = "APM service configurations for monitoring"
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
