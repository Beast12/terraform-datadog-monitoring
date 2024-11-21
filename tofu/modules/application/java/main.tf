locals {
  monitor_tags = [
    for k, v in var.tags : "${k}:${v}"
  ]

  slack_channel = try(
    var.notification_channels.application["java"],
    var.notification_channels.default
  )
}

# JVM Memory Usage Monitor
resource "datadog_monitor" "jvm_memory_usage" {
  for_each = var.java_services

  name    = "[${var.environment}] JVM Memory Usage Anomaly - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Significant JVM Memory Usage Anomaly detected for ${each.value.name}

    Current Memory Usage: {{value}} bytes
    Expected range: {{threshold}} bytes
    
    This represents a major deviation (4+ standard deviations) from normal behavior:
    * Based on 1 week of historical data
    * Trigger: Anomaly sustained for 2 hours
    * Recovery: Normal behavior for 3 hours

    Investigation Priority Steps:
    1. Compare with last week's memory patterns
    2. Review heap usage trends
    3. Check for memory leaks

    @${local.slack_channel}
  EOT

  query = "avg(last_2h):anomalies(avg:jvm.heap_memory{service:${each.value.service_name},env:${var.environment}}, 'agile', 4, direction='above', alert_window='last_2h', interval=300, count_default_zero='true', seasonality='weekly', learning_duration='1w', trend='linear') >= 1"

  monitor_thresholds {
    critical = 1.0 # Only triggers on severe anomalies (4+ standard deviations)
  }

  monitor_threshold_windows {
    trigger_window  = "last_2h"
    recovery_window = "last_3h"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 1800 # 30 minutes delay to ensure data stability
  notify_audit        = false
  no_data_timeframe   = 180 # Only alert on no data after 3 hours

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}",
      "monitor_type:memory_anomaly",
      "alert_type:capacity"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}
