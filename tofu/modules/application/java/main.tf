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
    ## Significant JVM Memory Usage Anomaly Detected for ${each.value.name}

    Current JVM Heap Memory Used: {{value}} bytes
    Expected Range: {{threshold}} bytes
    
    This represents a major deviation (4+ standard deviations) from normal behavior,
    sustained over a 2-hour period.

    This severe anomaly could indicate:
    * Significant memory leak
    * Unusual memory allocation patterns
    * Potential service degradation
    * Heap space exhaustion risk

    Investigation Priority Steps:
    1. Check if recent deployment coincides with memory increase
    2. Review memory trend over past 24 hours
    3. Analyze heap dumps if available
    4. Check GC patterns in logs
    5. Review large object allocations

    Additional Context:
    * Service: ${each.value.service_name}
    * Environment: ${var.environment}
    * Alert Duration: Sustained for 120+ minutes
    * Deviation: Exceeds 4 standard deviations from normal
    * Detection Window: 2 hours of continuous anomalous behavior

    @${local.slack_channel}
  EOT

  query = "avg(last_2h):anomalies(avg:jvm.heap_memory{service:${each.value.service_name},env:${var.environment}}, 'robust', 4, direction='above', alert_window='last_2h', interval=300, count_default_zero='true', seasonality='weekly', trend='linear') >= 1"

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
  timeout_h           = 0
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

# JVM GC Time Monitor
resource "datadog_monitor" "jvm_minor_gc_time" {
  for_each = var.java_services

  name    = "[${var.environment}] JVM Minor GC Time Anomaly - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Significant JVM Minor GC Time Anomaly detected for ${each.value.name}

    Current Minor GC Time: {{value}} ms
    Expected range: {{threshold}} ms
    
    This represents a major deviation (4+ standard deviations) from normal behavior over a sustained period.

    This severe anomaly could indicate:
    * Significant spike in minor GCs
    * Major changes in memory allocation patterns
    * Potential service degradation

    Recommended investigation steps:
    1. Check for recent deployments or config changes
    2. Review memory allocation patterns
    3. Monitor application performance metrics
    4. Analyze application logs for errors

    @${local.slack_channel}
  EOT

  query = "avg(last_30m):anomalies(sum:jvm.gc.minor_collection_time{service:${each.value.service_name},env:${var.environment}}.as_rate() / sum:jvm.gc.minor_collection_count{service:${each.value.service_name},env:${var.environment}}.as_rate(), 'robust', 4, direction='above', alert_window='last_30m', interval=300, count_default_zero='true', seasonality='weekly') >= 1"

  monitor_thresholds {
    critical = 1.0 # Only triggers on severe anomalies (4+ standard deviations)
  }

  monitor_threshold_windows {
    trigger_window  = "last_30m"
    recovery_window = "last_1h"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900 # 15 minutes delay to ensure data stability
  notify_audit        = false
  timeout_h           = 0
  no_data_timeframe   = 60 # Only alert on no data after 60 minutes

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}",
      "monitor_type:gc_time_anomaly"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}

resource "datadog_monitor" "jvm_major_gc_time" {
  for_each = var.java_services

  name    = "[${var.environment}] JVM Major GC Time Anomaly - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## Significant JVM Major GC Time Anomaly detected for ${each.value.name}

    Current Major GC Time: {{value}} ms
    Expected range: {{threshold}} ms
    
    This represents a major deviation (4+ standard deviations) from normal behavior over a sustained period.

    This severe anomaly could indicate:
    * Significant spike in major GCs
    * Potential severe memory leak
    * Critical old generation pressure

    Recommended investigation steps:
    1. Review heap usage trends
    2. Check for memory leaks
    3. Analyze old generation metrics
    4. Review application logs for error patterns
    5. Check if heap size adjustment is needed

    @${local.slack_channel}
  EOT

  query = "avg(last_30m):anomalies(sum:jvm.gc.major_collection_time{service:${each.value.service_name},env:${var.environment}}.as_rate() / sum:jvm.gc.major_collection_count{service:${each.value.service_name},env:${var.environment}}.as_rate(), 'robust', 4, direction='above', alert_window='last_30m', interval=300, count_default_zero='true', seasonality='weekly') >= 1"

  monitor_thresholds {
    critical = 1.0 # Only triggers on severe anomalies (4+ standard deviations)
  }

  monitor_threshold_windows {
    trigger_window  = "last_30m"
    recovery_window = "last_1h"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900 # 15 minutes delay to ensure data stability
  notify_audit        = false
  timeout_h           = 0
  no_data_timeframe   = 60 # Only alert on no data after 60 minutes

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}",
      "monitor_type:gc_time_anomaly"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    ["service:${each.value.service_name}"]
  )

  priority = each.value.alert_settings.priority
}
