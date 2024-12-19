locals {
  monitor_tags = concat(
    [for k, v in var.tags : "${k}:${v}"],
    [
      "service_type:ecs",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ]
  )

  slack_channel = try(
    var.notification_channels.infrastructure["ecs"],
    var.notification_channels.default
  )
}

# CPU Usage Monitor
resource "datadog_monitor" "cpu_usage" {
  for_each = var.services

  name    = "[${var.environment}] ECS Service ${each.value.service_name} - High CPU Usage"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.service_name} is experiencing high CPU usage

    Current CPU Usage: {{value}}%
    Threshold: ${each.value.thresholds.cpu_percent}%

    This could indicate:
    * Resource constraints
    * High application load
    * Potential memory leaks
    * Long-running operations

    Please investigate:
    * Application metrics and logs
    * Recent code deployments
    * Current service load
    * Resource allocation

    @${local.slack_channel}
  EOT

  query = "avg(last_4h):avg:ecs.fargate.cpu.percent{cluster_name:${each.value.cluster},service:${each.value.service_name}*}.rollup(max, 120) >= ${each.value.thresholds.cpu_percent}"

  monitor_thresholds {
    critical          = each.value.thresholds.cpu_percent
    critical_recovery = each.value.thresholds.cpu_percent * 0.9
  }


  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 30
  require_full_window = false
  evaluation_delay    = 900

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}",
      "task_name:${each.value.task_name}"
    ]
  )
  priority = each.value.alert_settings.priority
}

# Memory Usage Monitor
resource "datadog_monitor" "memory_usage" {
  for_each = var.services

  name    = "[${var.environment}] ECS Service ${each.value.service_name} - High Memory Usage"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.service_name} is approaching Out of Memory condition

    Current Memory Usage: {{value}}%
    Memory Threshold: ${each.value.thresholds.memory_percent}% of ${format("%.2f", each.value.thresholds.memory_available / 1024)} GB

    This indicates the service is close to running out of memory!

    Immediate actions required:
    * Check for memory leaks
    * Review recent deployments
    * Check for unusual load patterns
    * Consider emergency scaling

    Critical System Impact:
    * Service might experience OOM kills
    * Performance degradation
    * Potential service disruption

    @${local.slack_channel}
  EOT

  # Query to calculate memory usage as a percentage of memory_available in GB
  query = "avg(last_5m):avg:ecs.fargate.mem.usage{cluster_name:${each.value.cluster},service:${each.value.service_name}*} > ${(each.value.thresholds.memory_available * 1024 * 1024) * (each.value.thresholds.memory_percent / 100)}"

  monitor_thresholds {
    critical          = (each.value.thresholds.memory_available * 1024 * 1024) * (each.value.thresholds.memory_percent / 100)
    critical_recovery = (each.value.thresholds.memory_available * 1024 * 1024) * ((each.value.thresholds.memory_percent - 10) / 100)
    warning           = (each.value.thresholds.memory_available * 1024 * 1024) * ((each.value.thresholds.memory_percent - 5) / 100)
    warning_recovery  = (each.value.thresholds.memory_available * 1024 * 1024) * ((each.value.thresholds.memory_percent - 15) / 100)
  }

  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 10
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}",
      "task_name:${each.value.task_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}


# Network Errors Monitor
resource "datadog_monitor" "network_errors" {
  for_each = var.services

  name    = "[${var.environment}] ECS Service ${each.value.service_name} - Network Errors Detected"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.service_name} is experiencing network errors

    Current Error Rate: {{value}}
    Threshold: ${each.value.thresholds.network_errors}

    This could indicate:
    * Network connectivity issues
    * Service mesh problems
    * DNS resolution failures
    * Application network issues

    Please investigate:
    * Network connectivity
    * DNS resolution
    * Security groups and NACLs
    * Application logs for connection errors

    @${local.slack_channel}
  EOT

  query = <<EOT
    avg(last_15m):(
      sum:ecs.fargate.net.rcvd_errors{cluster_name:${each.value.cluster},service:${each.value.service_name}*}.as_rate() +
      sum:ecs.fargate.net.sent_errors{cluster_name:${each.value.cluster},service:${each.value.service_name}*}.as_rate()
    ) > ${each.value.thresholds.network_errors}
    EOT

  monitor_thresholds {
    critical          = each.value.thresholds.network_errors
    critical_recovery = floor(each.value.thresholds.network_errors * 0.6)
    warning           = floor(each.value.thresholds.network_errors * 0.7)
    warning_recovery  = floor(each.value.thresholds.network_errors * 0.5)
  }


  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 20
  require_full_window = false
  evaluation_delay    = 300

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}",
      "task_name:${each.value.task_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

# Container Health Monitor - Production Only
resource "datadog_monitor" "container_health" {
  # Only create this monitor when environment is "prd"
  for_each = var.environment == "prd" ? var.services : {}

  name    = "[${var.environment}] ECS Service ${each.value.service_name} - Container Health Check Failures"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.service_name} is experiencing container health check failures

    Current Running Task Count: {{value}}
    Minimum Expected Tasks: ${floor(each.value.thresholds.desired_count * 0.5)}
    
    This could indicate:
    * Application crashes
    * Deadlocks
    * Configuration issues
    * Resource exhaustion

    Please investigate:
    * Container logs
    * Health check configuration
    * Resource metrics
    * Recent deployments
    * ECS Events and Service status

    @${var.environment == "prd" ? "slack-dd-unhealthy-container-p1" : "slack-dd-unhealthy-container-p2"}
  EOT

  query = "sum(last_1h):avg:ecs.containerinsights.RunningTaskCount{clustername:${each.value.cluster},servicename:${each.value.service_name}} < 0.9"

  monitor_thresholds {
    critical          = 0.9 # Alert when less than 1 container is running
    critical_recovery = 1   # Recover when 1 container is running
  }

  include_tags      = true
  notify_no_data    = false
  no_data_timeframe = 20
  evaluation_delay  = 900

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}",
      "task_name:${each.value.task_name}"
    ]
  )

  priority = 1
}

# Unhealthy Tasks Monitor
resource "datadog_monitor" "unhealthy_tasks" {
  for_each = var.environment == "prd" ? var.services : {}

  name    = "[${var.environment}] ECS Service ${each.value.service_name} - Unhealthy Tasks Detected"
  type    = "query alert"
  message = <<-EOT
    ## Service ${each.value.name} has unhealthy tasks

    Desired Tasks: {{desired_value}}
    Running Tasks: {{running_value}}
    Missing Tasks: {{value}}

    This indicates tasks are not running as expected.

    Please investigate:
    * ECS Service Events
    * Container logs
    * Recent deployments
    * Resource constraints
    * Health check configurations

    @${var.environment == "prd" ? "slack-dd-unhealthy-container-p1" : "slack-dd-unhealthy-container-p2"}
  EOT

  query = "max(last_1m):avg:aws.ecs.service.desired{cluster:${each.value.cluster},service:${each.value.service_name}*} - avg:aws.ecs.service.running{cluster:${each.value.cluster},service:${each.value.service_name}*} > 0"

  monitor_thresholds {
    critical          = 0
    critical_recovery = -1
  }

  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 10
  require_full_window = false
  evaluation_delay    = 30

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}",
      "task_name:${each.value.task_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

# ECS Task Health Monitor
# ECS Task Health Monitor
resource "datadog_monitor" "ecs_task_health" {
  for_each = var.services

  name    = "[${var.environment}] ECS Service ${each.value.service_name} - Task Health Check"
  type    = "service check"
  message = <<-EOT
    ## Service ${each.value.name} has unhealthy or draining tasks

    At least one task is unhealthy or in a draining state.

    Please investigate:
    * ECS Service Events
    * Container logs
    * Recent deployments
    * Resource constraints
    * Health check configurations

    @${var.environment == "prd" ? "slack-dd-unhealthy-container-p1" : "slack-dd-unhealthy-container-p2"}
  EOT

  query = "\"fargate_check\".over(\"task_name:${each.value.task_name}\").by(\"*\").last(2).count_by_status()"

  monitor_thresholds {
    ok       = 1
    critical = 1
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 30

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}",
      "task_name:${each.value.task_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}
