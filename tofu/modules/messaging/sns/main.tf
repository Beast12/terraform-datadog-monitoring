locals {
  monitor_tags = concat(
    [for k, v in var.tags : "${k}:${v}"],
    [
      "service_type:sns",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ]
  )

  slack_channel = try(
    var.notification_channels.messaging["sns"],
    var.notification_channels.default
  )
}

# Monitor message count
resource "datadog_monitor" "message_count" {
  for_each = var.topics

  name    = "[${var.environment}] SNS ${each.value.name} - Message Count"
  type    = "metric alert"
  message = <<-EOT
    ## Topic ${each.value.name} has too many messages

    Current message count: {{value}} messages
    Threshold: ${each.value.thresholds.message_count_threshold} messages

    This could indicate:
    * High message volume
    * Unprocessed messages
    * Consumer scaling issues

    Please investigate:
    * Consumer logs
    * Processing rate
    * Input rate

    @${local.slack_channel}
  EOT

  query = "max(last_5m):sum:aws.sns.number_of_messages_delivered{topicname:${each.value.topic_name}} > ${each.value.thresholds.message_count_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.message_count_threshold
    critical_recovery = each.value.thresholds.message_count_threshold * 0.7
    warning           = each.value.thresholds.message_count_threshold * 0.8
    warning_recovery  = each.value.thresholds.message_count_threshold * 0.6
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "topic:${each.value.name}",
      "service:${each.value.service_name}" # Unified service tagging
    ]
  )

  priority = each.value.alert_settings.priority
}

# Monitor age of oldest message
resource "datadog_monitor" "oldest_message_age" {
  for_each = var.topics

  name    = "[${var.environment}] SNS ${each.value.name} - Oldest Message Age"
  type    = "metric alert"
  message = <<-EOT
    ## Topic ${each.value.name} has old messages

    Current oldest message age: {{value}} seconds
    Threshold: ${each.value.thresholds.age_threshold} seconds

    This could indicate:
    * Processing delays
    * Consumer issues

    Please investigate:
    * Consumer performance
    * Message processing patterns

    @${local.slack_channel}
  EOT

  query = "max(last_5m):max:aws.sns.oldest_message_age{topicname:${each.value.topic_name}} > ${each.value.thresholds.age_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.age_threshold
    critical_recovery = each.value.thresholds.age_threshold * 0.7
    warning           = each.value.thresholds.age_threshold * 0.8
    warning_recovery  = each.value.thresholds.age_threshold * 0.6
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "topic:${each.value.name}",
      "service:${each.value.service_name}" # Unified service tagging
    ]
  )

  priority = each.value.alert_settings.priority
}
