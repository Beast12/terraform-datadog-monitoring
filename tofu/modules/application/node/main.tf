locals {
  monitor_tags = [
    for k, v in var.tags : "${k}:${v}"
  ]

  slack_channel = try(
    var.notification_channels.application["node"],
    var.notification_channels.default
  )
}

# Total CPU Usage Monitor
resource "datadog_monitor" "node_cpu_total_usage" {
  for_each = var.node_services

  name    = "[${var.environment}] Node.js CPU Total Usage - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Node.js CPU Total Usage for ${each.value.name}

    Current CPU Total Usage: {{value}}%
    Threshold: ${each.value.thresholds.cpu_total_usage}%

    This may indicate CPU-intensive operations or blocking tasks.

    Please investigate:
    * Application performance issues
    * CPU-bound processes or tasks

    @${local.slack_channel}
  EOT

  query = "avg(last_15m):avg:runtime.node.cpu.total{service:${each.value.service_name},env:${var.environment}} > ${each.value.thresholds.cpu_total_usage}"

  monitor_thresholds {
    critical          = each.value.thresholds.cpu_total_usage
    critical_recovery = each.value.thresholds.cpu_total_usage * 0.8
    warning           = each.value.thresholds.cpu_total_usage * 0.85
    warning_recovery  = each.value.thresholds.cpu_total_usage * 0.7
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 300

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}

# Heap Memory Usage Monitor
resource "datadog_monitor" "node_heap_memory_usage" {
  for_each = var.node_services

  name    = "[${var.environment}] Node.js Heap Memory Usage - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Node.js Heap Memory Usage for ${each.value.name}

    Current Heap Memory Usage: {{value}} bytes
    Threshold: ${each.value.thresholds.heap_memory_usage} bytes

    This may indicate memory leaks or excessive memory consumption.

    Please investigate:
    * Memory-intensive operations
    * Potential memory leaks

    @${local.slack_channel}
  EOT

  query = "avg(last_5m):avg:runtime.node.mem.heap_used{service:${each.value.service_name},env:${var.environment}} > ${each.value.thresholds.heap_memory_usage * 1024 * 1024}"

  monitor_thresholds {
    critical = each.value.thresholds.heap_memory_usage * 1024 * 1024        # Convert MB to bytes
    warning  = each.value.thresholds.heap_memory_usage * 0.75 * 1024 * 1024 # Convert MB to bytes for warning
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}

# Event Loop Delay Monitor
resource "datadog_monitor" "node_event_loop_delay" {
  for_each = var.node_services

  name    = "[${var.environment}] Node.js Event Loop Delay - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Node.js Event Loop Delay for ${each.value.name}

    Current Average Event Loop Delay: {{value}} ns
    Threshold: ${each.value.thresholds.event_loop_delay} ns

    High event loop delay can indicate blocking tasks affecting responsiveness.

    Please investigate:
    * Long-running operations
    * Potential event loop blocking

    @${local.slack_channel}
  EOT

  query = "avg(last_5m):avg:runtime.node.event_loop.delay.avg{service:${each.value.service_name},env:${var.environment}} > ${each.value.thresholds.event_loop_delay}"

  monitor_thresholds {
    critical          = each.value.thresholds.event_loop_delay
    critical_recovery = each.value.thresholds.event_loop_delay * 0.7
    warning           = each.value.thresholds.event_loop_delay * 0.8
    warning_recovery  = each.value.thresholds.event_loop_delay * 0.6
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}
