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

  name    = "[${var.environment}] ${each.value.name} - ${each.value.query}"
  type    = "log alert"
  message = <<-EOT
    ## Log Alert: ${each.value.name}

    Detected increase in log entries. Current log count: {{value}}.

    Immediate actions required:
    * Investigate error logs and potential issues
    * Monitor patterns in logs for stability
    * Analyze the root cause if needed
    
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
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [
      "service:${each.key}",
      "env:${var.environment}",
      "product:logs"
    ]
  )

  priority = each.value.alert_settings.priority
}
