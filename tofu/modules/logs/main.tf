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
    var.notification_channels.logs,
    var.notification_channels.default
  )
}

resource "datadog_monitor" "log_monitor" {
  for_each = { for log, config in var.logs : log => config }

  name    = "[${var.environment}] LOGS - ${each.value.name}"
  type    = "log alert"
  message = <<-EOT
    ## Log Alert: ${each.value.name}

    Detected increase in log entries. 
    Current log count: {{value}}
    Evaluation window: {{timeframe}}
    Alert threshold: ${each.value.thresholds.critical}

    Context:
    * Service: ${each.key}
    * Environment: ${var.environment}
    * Log Pattern: ${each.value.query}

    Immediate actions required:
    * Investigate error logs and potential issues
    * Monitor patterns in logs for stability
    * Check recent deployments or changes
    * Review application metrics for correlation
    * Analyze the root cause if needed

    {{#is_alert}}
    Alert Details:
    * Triggered at: {{last_triggered_at}}
    * Status: Alert (Above {{threshold}})
    {{/is_alert}}
    
    {{#is_warning}}
    Warning Details:
    * Triggered at: {{last_triggered_at}}
    * Status: Warning (Above {{warn_threshold}})
    {{/is_warning}}
    
    @${local.slack_channel}
  EOT

  query = each.value.query

  monitor_thresholds {
    critical          = each.value.thresholds.critical
    critical_recovery = each.value.thresholds.critical_recovery
    warning           = each.value.thresholds.warning
    warning_recovery  = each.value.thresholds.warning_recovery
  }

  include_tags        = each.value.alert_settings.include_tags
  notify_no_data      = false
  no_data_timeframe   = 20
  require_full_window = false
  evaluation_delay    = 300
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [
      "service:${each.key}",
      "env:${var.environment}",
      "product:logs",
      "alert_type:log",
      "monitor_type:threshold"
    ]
  )

  priority = each.value.alert_settings.priority
}
