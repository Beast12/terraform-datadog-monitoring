locals {
  monitor_tags = [
    for k, v in var.tags : "${k}:${v}"
  ]

  slack_channel = try(
    var.notification_channels.application["node"],
    var.notification_channels.default
  )
}

resource "datadog_monitor" "node_cpu_total_usage" {
  for_each = var.node_services

  name    = "[${var.environment}] Node.js CPU Usage Anomaly - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Significant Node.js CPU Usage Anomaly for ${each.value.name}

    Current CPU Usage: {{value}}%
    Expected Range: {{threshold}}%
    
    This represents a major deviation (4+ standard deviations) from normal behavior:
    * Based on 1 week of historical data
    * Trigger: Anomaly sustained for 30 minutes
    * Recovery: Normal behavior for 1 hour

    This severe anomaly could indicate:
    * CPU-intensive operations or blocking tasks
    * Unusual workload patterns
    * Performance degradation
    * Resource constraints

    Investigation Priority Steps:
    1. Compare with last week's CPU patterns
    2. Check recent deployments or configuration changes
    3. Review application performance metrics
    4. Analyze CPU-bound processes
    5. Check for unusual traffic patterns
    6. Review system resource allocation

    @${local.slack_channel}
  EOT

  query = "avg(last_30m):anomalies(avg:runtime.node.cpu.total{service:${each.value.service_name},env:${var.environment}}, 'agile', 4, direction='above', alert_window='last_30m', interval=300, count_default_zero='true', seasonality='weekly', learning_duration='1w') >= 1"

  monitor_thresholds {
    critical = 1.0
  }

  monitor_threshold_windows {
    trigger_window  = "last_30m"
    recovery_window = "last_1h"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 900 # 15 minutes delay
  notify_audit        = false
  no_data_timeframe   = 120 # Alert on no data after 2 hours

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}",
      "monitor_type:anomaly",
      "analysis_period:weekly"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}

resource "datadog_monitor" "node_heap_memory_usage" {
  for_each = var.node_services

  name    = "[${var.environment}] Node.js Heap Memory Anomaly - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Significant Node.js Heap Memory Anomaly for ${each.value.name}

    Current Heap Memory Usage: {{value}} bytes
    Expected Range: {{threshold}} bytes
    
    This represents a major deviation (4+ standard deviations) from normal behavior:
    * Based on 1 week of historical data
    * Trigger: Anomaly sustained for 2 hours
    * Recovery: Normal behavior for 3 hours

    This severe anomaly could indicate:
    * Memory leaks
    * Unusual memory allocation patterns
    * Resource exhaustion risk
    * Application performance issues

    Investigation Priority Steps:
    1. Compare with last week's memory patterns
    2. Review memory trend over past 24 hours
    3. Check for memory leaks
    4. Analyze heap snapshots
    5. Review recent deployment changes
    6. Check application logs for errors

    @${local.slack_channel}
  EOT

  query = "avg(last_2h):anomalies(avg:runtime.node.mem.heap_used{service:${each.value.service_name},env:${var.environment}}, 'agile', 4, direction='above', alert_window='last_2h', interval=300, count_default_zero='true', seasonality='weekly', learning_duration='1w', trend='linear') >= 1"

  monitor_thresholds {
    critical = 1.0
  }

  monitor_threshold_windows {
    trigger_window  = "last_2h"
    recovery_window = "last_3h"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 1800 # 30 minutes delay
  notify_audit        = false
  no_data_timeframe   = 180 # Alert on no data after 3 hours

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}",
      "monitor_type:anomaly",
      "analysis_period:weekly"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}

resource "datadog_monitor" "node_event_loop_delay" {
  for_each = var.node_services

  name    = "[${var.environment}] Node.js Event Loop Delay Anomaly - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Significant Node.js Event Loop Delay Anomaly for ${each.value.name}

    Current Event Loop Delay: {{value}} ns
    Expected Range: {{threshold}} ns
    
    This represents a major deviation (4+ standard deviations) from normal behavior:
    * Based on 1 week of historical data
    * Trigger: Anomaly sustained for 15 minutes
    * Recovery: Normal behavior for 30 minutes

    This severe anomaly could indicate:
    * Blocking operations in event loop
    * CPU-intensive tasks
    * I/O bottlenecks
    * Service responsiveness issues

    Investigation Priority Steps:
    1. Compare with last week's event loop patterns
    2. Check for blocking operations
    3. Review CPU utilization
    4. Analyze application logs
    5. Check for long-running operations
    6. Review recent code changes

    @${local.slack_channel}
  EOT

  query = "avg(last_15m):anomalies(avg:runtime.node.event_loop.delay.avg{service:${each.value.service_name},env:${var.environment}}, 'agile', 4, direction='above', alert_window='last_15m', interval=60, count_default_zero='true', seasonality='weekly', learning_duration='1w') >= 1"

  monitor_thresholds {
    critical = 1.0
  }

  monitor_threshold_windows {
    trigger_window  = "last_15m"
    recovery_window = "last_30m"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 300 # 5 minutes delay
  notify_audit        = false
  no_data_timeframe   = 60 # Alert on no data after 1 hour

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}",
      "monitor_type:anomaly",
      "analysis_period:weekly"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}
