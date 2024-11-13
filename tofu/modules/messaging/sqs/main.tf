locals {
  monitor_tags = concat(
    [for k, v in var.tags : "${k}:${v}"],
    [
      "service_type:sqs",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ]
  )

  slack_channel = try(
    var.notification_channels.messaging["sqs"],
    var.notification_channels.default
  )
}

# Age of oldest message monitor
resource "datadog_monitor" "age_of_oldest_message" {
  for_each = var.queues

  name    = "[${var.environment}] SQS ${each.value.name} - Messages Too Old"
  type    = "metric alert"
  message = <<-EOT
    ## Queue ${each.value.name} has messages that are too old

    Current oldest message age: {{value}} seconds
    Threshold: ${each.value.thresholds.age_threshold} seconds

    This could indicate:
    * Consumer issues
    * Processing delays
    * Dead letter scenarios
    * Infrastructure problems

    Please investigate:
    * Consumer logs and metrics
    * Message processing patterns
    * DLQ status
    * Infrastructure health

    @${local.slack_channel}
  EOT

  query = "max(last_5m):max:aws.sqs.approximate_age_of_oldest_message{queuename:${each.value.queue_name}} > ${each.value.thresholds.age_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.age_threshold
    critical_recovery = each.value.thresholds.age_threshold * 0.6
    warning           = each.value.thresholds.age_threshold * 0.7
    warning_recovery  = each.value.thresholds.age_threshold * 0.5
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}" # Unified service tagging
    ]
  )

  priority = each.value.alert_settings.priority
}

# Queue depth monitor
resource "datadog_monitor" "queue_depth" {
  for_each = var.queues

  name    = "[${var.environment}] SQS ${each.value.name} - Queue Too Deep"
  type    = "metric alert"
  message = <<-EOT
    ## Queue ${each.value.name} has too many messages

    Current queue depth: {{value}} messages
    Threshold: ${each.value.thresholds.depth_threshold} messages

    This could indicate:
    * Processing bottleneck
    * Consumer scaling issues
    * Sudden message influx
    * Consumer failures

    Please investigate:
    * Consumer scaling
    * Processing rate
    * Message input rate
    * Consumer health

    @${local.slack_channel}
  EOT

  query = "max(last_5m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:${each.value.queue_name}} > ${each.value.thresholds.depth_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.depth_threshold
    critical_recovery = each.value.thresholds.depth_threshold * 0.6
    warning           = each.value.thresholds.depth_threshold * 0.7
    warning_recovery  = each.value.thresholds.depth_threshold * 0.5
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}" # Unified service tagging
    ]
  )

  priority = each.value.alert_settings.priority
}

# DLQ messages monitor
resource "datadog_monitor" "dlq_messages" {
  for_each = {
    for name, queue in var.queues :
    name => queue
    if queue.dlq_name != null
  }

  name    = "[${var.environment}] SQS ${each.value.name} - DLQ Has Messages"
  type    = "metric alert"
  message = <<-EOT
    ## Dead Letter Queue for ${each.value.name} has messages

    Current DLQ messages: {{value}}
    Threshold: ${each.value.thresholds.dlq_threshold}

    This indicates failed message processing:
    * Processing errors
    * Message format issues
    * Business logic failures
    * Infrastructure problems

    Immediate actions needed:
    * Check error patterns in DLQ
    * Review consumer logs
    * Verify message format
    * Check processing logic

    @${local.slack_channel}
  EOT

  query = "max(last_5m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:${each.value.dlq_name}} > ${each.value.thresholds.dlq_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.dlq_threshold
    critical_recovery = each.value.thresholds.dlq_threshold * 0.7
    warning           = each.value.thresholds.dlq_threshold * 0.5
    warning_recovery  = each.value.thresholds.dlq_threshold * 0.3
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}", # Unified service tagging
      "queue_type:dlq"
    ]
  )

  priority = each.value.alert_settings.priority
}
