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

  # Queries using dynamic metric paths with working configuration
  error_anomaly_queries = {
    for service, config in var.apm_services :
    service => "avg(last_2w):anomalies(sum:${local.metric_paths[service].error}{service:${config.service_name},env:${var.environment}}.as_rate() / sum:${local.metric_paths[service].hits}{service:${config.service_name},env:${var.environment}}.as_rate() * 100, 'agile', 5, direction='above', interval=21600, alert_window='last_1w', seasonality='weekly', count_default_zero='true', timezone='utc') >= 1"
  }
}

resource "datadog_monitor" "apm_latency" {
  for_each = var.apm_services

  name    = "[${var.environment}] APM Latency Anomaly - ${each.value.name}"
  type    = "query alert"
  message = <<-EOT
    ## Significant Latency Anomaly Detected for ${each.value.name}

    Current Latency: {{value}} ms
    Expected Range: {{threshold}} ms
    
    This represents a major deviation (5+ standard deviations) from normal behavior:
    * Based on 2 weeks of historical data
    * Trigger: Anomaly sustained for 1 week
    * Recovery: Normal behavior for 30 minutes

    This severe anomaly could indicate:
    * Unusual response times from dependencies
    * Unexpected workload patterns
    * Performance degradation
    * Resource constraints

    Investigation Priority Steps:
    1. Compare with last week's latency patterns
    2. Check dependencies' performance
    3. Review resource utilization
    4. Analyze current traffic patterns
    5. Check recent deployments
    6. Review database performance

    @${local.slack_channel}
  EOT

  query = "avg(last_2w):anomalies(avg:${local.metric_paths[each.key].request}{service:${each.value.service_name},env:${var.environment}}, 'agile', 5, direction='above', interval=21600, alert_window='last_1w', seasonality='weekly', count_default_zero='true', timezone='utc') >= 1"

  monitor_thresholds {
    critical = 1.0
  }

  monitor_threshold_windows {
    trigger_window  = "last_1w"
    recovery_window = "last_30m"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 900 # 15 minutes
  notify_audit        = false
  new_host_delay      = 300

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

resource "datadog_monitor" "error_rate_monitor" {
  for_each = var.apm_services

  name    = "[${var.environment}] APM Error Rate Anomaly - ${each.value.service_name}"
  type    = "query alert"
  message = <<-EOT
    ## Significant Error Rate Anomaly Detected for ${each.value.service_name}

    Current Error Rate Pattern: {{value}}%
    Expected Range: {{threshold}}%
    
    This represents a major deviation (5+ standard deviations) from normal behavior:
    * Based on 2 weeks of historical data
    * Trigger: Anomaly sustained for 1 week
    * Recovery: Normal behavior for 30 minutes

    This severe anomaly could indicate:
    * Deployment issues
    * Service dependencies failing
    * System resource constraints
    * External service integration problems
    * Database connection issues
    * Configuration errors

    Investigation Priority Steps:
    1. Compare with last week's error patterns
    2. Check recent deployments or changes
    3. Review error logs and stack traces
    4. Check downstream dependencies
    5. Verify external service status
    6. Monitor system resources

    Additional Context:
    * Service Type: ${each.value.service_type}
    * Environment: ${var.environment}
    * Detection Window: 1 week of sustained anomalous behavior

    @${local.slack_channel}
  EOT

  query = local.error_anomaly_queries[each.key]

  monitor_thresholds {
    critical = 1.0
  }

  monitor_threshold_windows {
    trigger_window  = "last_1w"
    recovery_window = "last_30m"
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 900 # 15 minutes
  notify_audit        = false
  new_host_delay      = 300

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

  query = "sum(last_2w):sum:${local.metric_paths[each.key].hits}{service:${each.value.service_name},env:${var.environment}}.as_count().rollup(sum, 300) < 0"

  monitor_thresholds {
    critical          = 0 # No data should trigger critical alert
    critical_recovery = 1 # Any data received will clear the alert
  }

  include_tags      = true
  notify_no_data    = false
  no_data_timeframe = 20
  timeout_h         = 1
  renotify_interval = 60

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
