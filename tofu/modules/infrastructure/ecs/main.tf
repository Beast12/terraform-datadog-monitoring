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

  name    = "[${var.environment}] ECS Service ${each.value.name} - High CPU Usage"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.name} is experiencing high CPU usage

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

  query = "avg(last_5m):avg:ecs.fargate.cpu.percent{cluster_name:${each.value.cluster},service:${each.value.name}} > ${each.value.thresholds.cpu_percent}"

  monitor_thresholds {
    critical          = each.value.thresholds.cpu_percent
    critical_recovery = each.value.thresholds.cpu_percent - 20
    warning           = each.value.thresholds.cpu_percent - 15
    warning_recovery  = each.value.thresholds.cpu_percent - 25
  }


  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 10
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.name}",
      "cluster:${each.value.cluster}",
      "service:${each.value.name}"
    ]
  )
  priority = each.value.alert_settings.priority
}

# Memory Usage Monitor
resource "datadog_monitor" "memory_usage" {
  for_each = var.services

  name    = "[${var.environment}] ECS Service ${each.value.name} - High Memory Usage"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.name} is approaching Out of Memory condition

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
  query = "avg(last_5m):avg:ecs.fargate.mem.usage{cluster_name:${each.value.cluster},service:${each.value.name}} > ${(each.value.thresholds.memory_available * 1024 * 1024) * (each.value.thresholds.memory_percent / 100)}"

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
      "service:${each.value.name}",
      "cluster:${each.value.cluster}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}


# Network Errors Monitor
resource "datadog_monitor" "network_errors" {
  for_each = var.services

  name    = "[${var.environment}] ECS Service ${each.value.name} - Network Errors Detected"
  type    = "metric alert"
  message = <<-EOT
    ## Service ${each.value.name} is experiencing network errors

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

  query = "sum(last_5m):(avg:ecs.fargate.net.rcvd_errors{cluster_name:${each.value.cluster},service:${each.value.name}} + avg:ecs.fargate.net.sent_errors{cluster_name:${each.value.cluster},service:${each.value.name}}) > ${each.value.thresholds.network_errors}"

  monitor_thresholds {
    critical          = each.value.thresholds.network_errors
    critical_recovery = each.value.thresholds.network_errors * 0.7
    warning           = each.value.thresholds.network_errors / 2
    warning_recovery  = each.value.thresholds.network_errors * 0.3
  }


  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 10
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.name}",
      "cluster:${each.value.cluster}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}
