locals {
  # Filter services that have ALB configuration and map them correctly
  alb_services = {
    for name, service in var.alb :
    name => service
    if service.alb_name != null && service.alb_name != "" &&
    try(service.thresholds.request_count, null) != null &&
    try(service.thresholds.latency, null) != null &&
    try(service.thresholds.error_rate, null) != null
  }

  monitor_tags = concat(
    [for k, v in var.tags : "${k}:${v}"],
    [
      "service_type:alb",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ]
  )

  slack_channel = try(
    var.notification_channels.infrastructure["alb"],
    var.notification_channels.default
  )
}

# Request Count Monitor
resource "datadog_monitor" "request_count" {
  for_each = local.alb_services

  name    = "[${var.environment}] ALB ${each.value.name} - High Request Count"
  type    = "metric alert"
  message = <<-EOT
    ## ALB ${each.value.name} is experiencing high request volume

    Current Request Count: {{value}}
    Threshold: ${each.value.thresholds.request_count}

    This could indicate:
    * Unusual traffic patterns
    * Potential DDoS
    * Application load spike

    Please investigate:
    * Traffic patterns
    * Source IPs
    * Request distribution
    * Application capacity

    @${local.slack_channel}
  EOT

  query = "sum(last_5m):sum:aws.applicationelb.request_count{loadbalancer:${each.value.alb_name}}.as_count() > ${each.value.thresholds.request_count}"

  monitor_thresholds {
    critical          = each.value.thresholds.request_count
    critical_recovery = floor(each.value.thresholds.request_count * 0.7)
    warning           = floor(each.value.thresholds.request_count * 0.8)
    warning_recovery  = floor(each.value.thresholds.request_count * 0.6)
  }

  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 10
  require_full_window = true
  evaluation_delay    = 600

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.name}",
      "loadbalancer:${each.value.alb_name}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

# Latency Monitor
resource "datadog_monitor" "latency" {
  for_each = local.alb_services

  name    = "[${var.environment}] ALB ${each.value.name} - High Latency"
  type    = "metric alert"
  message = <<-EOT
    ## ALB ${each.value.name} is experiencing high latency

    Current Average Latency: {{value}}ms
    Threshold: ${each.value.thresholds.latency}ms

    This could indicate:
    * Application performance issues
    * Backend service slowdown
    * Resource constraints
    * Network issues

    Please investigate:
    * Application performance metrics
    * Backend service health
    * Resource utilization
    * Network conditions

    @${local.slack_channel}
  EOT

  query = "avg(last_15m):avg:aws.applicationelb.target_response_time.average{loadbalancer:${each.value.alb_name}} > ${each.value.thresholds.latency}"

  monitor_thresholds {
    critical          = each.value.thresholds.latency
    critical_recovery = floor(each.value.thresholds.latency * 0.7)
    warning           = floor(each.value.thresholds.latency * 0.8)
    warning_recovery  = floor(each.value.thresholds.latency * 0.6)
  }


  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 10
  require_full_window = true

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.name}",
      "loadbalancer:${each.value.alb_name}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

# Error Rate Monitor
resource "datadog_monitor" "error_rate" {
  for_each = local.alb_services

  name    = "[${var.environment}] ALB ${each.value.name} - High Error Rate"
  type    = "metric alert"
  message = <<-EOT
    ## ALB ${each.value.name} is experiencing high error rate

    Current Error Rate: {{value}}%
    Threshold: ${each.value.thresholds.error_rate}%

    This could indicate:
    * Application errors
    * Failed health checks
    * Infrastructure issues
    * Configuration problems

    Please investigate:
    * Application logs
    * Target group health
    * Recent deployments
    * Infrastructure status

    @${local.slack_channel}
  EOT

  query = "sum(last_1h):sum:aws.applicationelb.httpcode_target_5xx{loadbalancer:${each.value.alb_name}}.as_count() / sum:aws.applicationelb.request_count{loadbalancer:${each.value.alb_name}}.as_count() * 100 > ${each.value.thresholds.error_rate}"

  monitor_thresholds {
    critical          = each.value.thresholds.error_rate
    critical_recovery = floor(each.value.thresholds.error_rate * 0.5)
    warning           = floor(each.value.thresholds.error_rate * 0.7)
    warning_recovery  = floor(each.value.thresholds.error_rate * 0.4)
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
      "loadbalancer:${each.value.alb_name}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}
