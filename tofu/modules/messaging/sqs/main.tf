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
    Time window: {{timeframe}}

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
    * Recent deployments or config changes

    Queue Details:
    * Environment: ${var.environment}
    * Queue: ${each.value.queue_name}
    * Service: ${each.value.service_name}

    @${local.slack_channel}
  EOT

  query = "avg(last_10m):max:aws.sqs.approximate_age_of_oldest_message{queuename:${each.value.queue_name}} > ${each.value.thresholds.age_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.age_threshold
    critical_recovery = each.value.thresholds.age_threshold * 0.7
    warning           = each.value.thresholds.age_threshold * 0.8
    warning_recovery  = each.value.thresholds.age_threshold * 0.6
  }

  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 20
  require_full_window = false
  evaluation_delay    = 900
  renotify_interval   = 120
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}"
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
    Time window: {{timeframe}}

    This could indicate:
    * Processing bottleneck
    * Consumer scaling issues
    * Sudden message influx
    * Consumer failures

    Please investigate:
    * Consumer scaling status
    * Processing rate vs input rate
    * Consumer health and logs
    * Recent traffic patterns

    Queue Details:
    * Environment: ${var.environment}
    * Queue: ${each.value.queue_name}
    * Service: ${each.value.service_name}

    @${local.slack_channel}
  EOT

  query = "avg(last_15m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:${each.value.queue_name}} > ${each.value.thresholds.depth_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.depth_threshold
    critical_recovery = each.value.thresholds.depth_threshold * 0.7
    warning           = each.value.thresholds.depth_threshold * 0.8
    warning_recovery  = each.value.thresholds.depth_threshold * 0.6
  }

  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 20
  require_full_window = false
  evaluation_delay    = 900
  renotify_interval   = 60
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}"
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
    Time window: {{timeframe}}

    This indicates failed message processing:
    * Processing errors
    * Message format issues
    * Business logic failures
    * Infrastructure problems

    Immediate actions needed:
    * Check error patterns in DLQ messages
    * Review consumer logs and errors
    * Verify message format and validation
    * Check processing logic and dependencies
    * Review recent deployments or changes

    Queue Details:
    * Environment: ${var.environment}
    * Main Queue: ${each.value.queue_name}
    * DLQ: ${each.value.dlq_name}
    * Service: ${each.value.service_name}

    @${local.slack_channel}
  EOT

  query = "avg(last_10m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:${each.value.dlq_name}} > ${each.value.thresholds.dlq_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.dlq_threshold
    critical_recovery = max(1, floor(each.value.thresholds.dlq_threshold * 0.3))
    warning           = max(2, floor(each.value.thresholds.dlq_threshold * 0.5)) # Changed from 1 to 2 in max()
    warning_recovery  = max(1, floor(each.value.thresholds.dlq_threshold * 0.2))
  }

  include_tags        = true
  notify_no_data      = false
  no_data_timeframe   = 20
  require_full_window = false
  evaluation_delay    = 600
  renotify_interval   = 30
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}",
      "queue_type:dlq"
    ]
  )

  priority = each.value.alert_settings.priority
}

# DLQ message age monitor
resource "datadog_monitor" "dlq_message_age" {
  for_each = {
    for name, queue in var.queues :
    name => queue
    if queue.dlq_name != null
  }

  name    = "[${var.environment}] SQS ${each.value.name} - DLQ Message Age"
  type    = "metric alert"
  message = <<-EOT
    ## Dead Letter Queue for ${each.value.name} has old messages

    Current oldest DLQ message age: {{value}} seconds
    Time window: {{timeframe}}

    This indicates stale failed messages that need attention:
    * Unhandled failure scenarios
    * Messages requiring manual intervention
    * Potential data loss risks

    Required actions:
    * Review and analyze old messages
    * Document failure patterns
    * Plan message recovery or cleanup
    * Update error handling if needed

    Queue Details:
    * Environment: ${var.environment}
    * Main Queue: ${each.value.queue_name}
    * DLQ: ${each.value.dlq_name}
    * Service: ${each.value.service_name}

    @${local.slack_channel}
  EOT

  query = "avg(last_10m):max:aws.sqs.approximate_age_of_oldest_message{queuename:${each.value.dlq_name}} > 3600"

  monitor_thresholds {
    critical          = 3600 # 1 hour
    critical_recovery = 1800 # 30 minutes
    warning           = 2700 # 45 minutes
    warning_recovery  = 1500 # 25 minutes
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 600
  renotify_interval   = 30
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "queue:${each.value.name}",
      "service:${each.value.service_name}",
      "queue_type:dlq"
    ]
  )

  priority = each.value.alert_settings.priority
}
