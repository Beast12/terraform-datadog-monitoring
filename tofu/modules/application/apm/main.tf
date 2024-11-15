locals {
  monitor_tags = [
    for k, v in var.tags : "${k}:${v}"
  ]

  slack_channel = try(
    var.notification_channels.application["apm"],
    var.notification_channels.default
  )

  # Define metric paths based on service type
  metric_paths = {
    for service, config in var.apm_services :
    service => {
      request = lookup(config, "service_type", "java") == "node" ? "trace.next.request" : "trace.servlet.request"
      error   = lookup(config, "service_type", "java") == "node" ? "trace.next.request.errors" : "trace.servlet.request.errors"
      hits    = lookup(config, "service_type", "java") == "node" ? "trace.next.request.hits" : "trace.servlet.request.hits"
    }
  }

  # Updated queries using dynamic metric paths
  queries = {
    for service, config in var.apm_services :
    service => "change(avg(last_15m),last_4h):sum:${local.metric_paths[service].error}{service:${config.service_name},env:${var.environment}}.as_rate().rollup(sum, 300) > ${config.thresholds.error_rate}"
  }
}

resource "datadog_monitor" "apm_latency" {
  for_each = var.apm_services

  name    = "[${var.environment}] APM Latency - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## High Request Latency for ${each.value.name}

    Current Latency: {{value}} ms
    Threshold: ${each.value.thresholds.latency} ms

    This could indicate:
    * Slow response times from dependencies
    * High workload causing delays
    * Inefficient processing within the service

    Please investigate:
    * Application and dependency performance
    * Database or external service response times
    * Potential optimizations in the code

    @${local.slack_channel}
  EOT

  query = "avg(last_5m):avg:${local.metric_paths[each.key].request}{service:${each.value.service_name},env:${var.environment}} > ${each.value.thresholds.latency}"

  monitor_thresholds {
    critical          = each.value.thresholds.latency
    critical_recovery = each.value.thresholds.latency * 0.7
    warning           = each.value.thresholds.latency * 0.8
    warning_recovery  = each.value.thresholds.latency * 0.6
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900

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

resource "datadog_monitor" "error_rate_monitor" {
  for_each = var.apm_services

  name    = "[${var.environment}] APM Increased Error Rate - ${each.value.service_name}"
  type    = "query alert"
  message = <<-EOT
    ## Increased Error Rate Detected for ${each.value.service_name}

    Current Error Rate: {{value}}%
    Critical Threshold: ${each.value.thresholds.error_rate * 100}%

    Please investigate:
    * Recent deployments
    * Logs for unusual patterns
    * High latency or unexpected load

    This alert is set to trigger when the error rate exceeds the configured threshold.

    @${local.slack_channel}
  EOT

  query = local.queries[each.key]

  monitor_thresholds {
    critical          = each.value.thresholds.error_rate
    critical_recovery = each.value.thresholds.error_rate * 0.6
    warning           = each.value.thresholds.error_rate * 0.7
    warning_recovery  = each.value.thresholds.error_rate * 0.5
  }

  include_tags        = each.value.alert_settings.include_tags
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ],
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.service_name}",
      "env:${var.environment}",
      "product:apm"
    ]
  )

  priority = each.value.alert_settings.priority
}

resource "datadog_monitor" "apm_throughput" {
  for_each = var.apm_services

  name    = "[${var.environment}] APM Throughput - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## No Data Detected for ${each.value.name}

    No throughput data has been reported for the last 10 minutes, indicating that your service may have stopped running entirely. 

    Potential causes:
    * Service is down or unresponsive
    * Network connectivity issues
    * Infrastructure resource limitations

    Please investigate:
    * Check the service status in your deployment environment
    * Review network configurations and traffic flow
    * Monitor resources for potential bottlenecks

    @${local.slack_channel}
  EOT

  query = "sum(last_15m):sum:${local.metric_paths[each.key].hits}{service:${each.value.service_name},env:${var.environment}}.as_count().rollup(sum, 300) < 0"

  monitor_thresholds {
    critical          = 0 # No data should trigger critical alert
    critical_recovery = 1 # Any data received will clear the alert
  }

  include_tags      = true
  notify_no_data    = true
  no_data_timeframe = 20
  timeout_h         = 1

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

resource "datadog_monitor" "latency_anomaly_monitor" {
  for_each = var.apm_services

  name    = "[${var.environment}]  APM Abnormal Change in p75 Latency - ${each.value.service_name}"
  type    = "query alert"
  message = <<-EOT
    ## Latency Anomaly Detected for ${each.value.service_name} in ${var.environment}

    ${each.value.service_name} has an abnormal change in p75 latency for ${var.environment}. The 75th percentile latency has deviated significantly from expected patterns.

    Suggested actions:
    * Review latency patterns over the last 12 hours
    * Investigate recent deployments, traffic changes, or infrastructure issues
    * Check for dependencies affecting performance

    @${local.slack_channel}
  EOT

  query = "avg(last_12h):anomalies(p75:${local.metric_paths[each.key].request}{service:${each.value.service_name},env:${var.environment}}.as_count(), 'agile', 4, direction='both', interval=300, alert_window='last_1h', count_default_zero='true', seasonality='hourly', tolerance='med') >= 0.85"

  monitor_thresholds {
    critical          = 0.85
    critical_recovery = 0.25
    warning           = 0.65
    warning_recovery  = 0.15
  }

  notify_no_data      = false
  require_full_window = false
  renotify_interval   = 0

  monitor_threshold_windows {
    trigger_window  = "last_1h"
    recovery_window = "last_1h"
  }

  tags = concat(
    local.monitor_tags,
    [
      "service_type:${each.value.service_type}",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ],
    [
      "service:${each.value.service_name}",
      "env:${var.environment}",
      "product:apm"
    ]
  )

  priority = each.value.alert_settings.priority
}
