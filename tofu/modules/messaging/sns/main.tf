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
    
    Time window: {{timeframe}}
    Alert triggering value: {{value}}
    Warning threshold: ${each.value.thresholds.message_count_threshold * 0.8}
    
    This could indicate:
    * High message volume
    * Unprocessed messages
    * Consumer scaling issues
    
    Please investigate:
    * Consumer logs
    * Processing rate
    * Input rate
    
    Alert Context:
    * Environment: ${var.environment}
    * Topic: ${each.value.topic_name}
    * Service: ${each.value.service_name}
    
    @${local.slack_channel}
  EOT

  query = "avg(last_15m):sum:aws.sns.number_of_messages_published{topicname:${each.value.topic_name}}.as_rate().rollup(avg, 900) > ${each.value.thresholds.message_count_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.message_count_threshold
    critical_recovery = floor(each.value.thresholds.message_count_threshold * 0.7)
    warning           = floor(each.value.thresholds.message_count_threshold * 0.8)
    warning_recovery  = floor(each.value.thresholds.message_count_threshold * 0.6)
  }


  include_tags        = true
  no_data_timeframe   = 20
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "topic:${each.value.name}",
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}"
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

  query = "avg(last_10m):avg:aws.sns.oldest_message_age{topicname:${each.value.topic_name}} > ${each.value.thresholds.age_threshold}"

  monitor_thresholds {
    critical          = each.value.thresholds.age_threshold
    critical_recovery = each.value.thresholds.age_threshold * 0.6
    warning           = each.value.thresholds.age_threshold * 0.7
    warning_recovery  = each.value.thresholds.age_threshold * 0.5
  }


  include_tags        = true
  no_data_timeframe   = 20
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "topic:${each.value.name}",
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

# Monitor for failed message deliveries
resource "datadog_monitor" "failed_deliveries" {
  for_each = var.topics

  name    = "[${var.environment}] SNS ${each.value.name} - Failed Message Deliveries"
  type    = "metric alert"
  message = <<-EOT
    ## Topic ${each.value.name} has failed message deliveries

    Current failure rate: {{value}}%
    Time window: {{timeframe}}

    This could indicate:
    * Subscriber endpoint issues
    * Network connectivity problems
    * Permission/authentication failures

    Please investigate:
    * Subscriber endpoint health
    * SNS delivery logs
    * Network connectivity
    * IAM permissions

    Alert Context:
    * Environment: ${var.environment}
    * Topic: ${each.value.topic_name}
    * Service: ${each.value.service_name}

    @${local.slack_channel}
  EOT

  query = "sum(last_10m):( sum:aws.sns.number_of_notifications_failed{topicname:${each.value.topic_name}} / ( sum:aws.sns.number_of_notifications_delivered{topicname:${each.value.topic_name}} + sum:aws.sns.number_of_notifications_failed{topicname:${each.value.topic_name}} + 1 )) * 100 > 5"

  monitor_thresholds {
    critical          = 5 # 5% failure rate
    critical_recovery = 3
    warning           = 3
    warning_recovery  = 1
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900
  renotify_interval   = 60
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "topic:${each.value.name}",
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

# Monitor for sudden drops in message volume
resource "datadog_monitor" "message_volume_drop" {
  for_each = var.topics

  name    = "[${var.environment}] SNS ${each.value.name} - Message Volume Drop"
  type    = "query alert"
  message = <<-EOT
    ## Topic ${each.value.name} has experienced a significant drop in message volume

    Current change in volume: {{value}}%
    Time window: {{timeframe}}

    This could indicate:
    * Publisher service issues
    * Network connectivity problems
    * Infrastructure problems
    * Unexpected application behavior

    Please investigate:
    * Publisher service health
    * Application logs
    * Recent deployments
    * Infrastructure status

    Alert Context:
    * Environment: ${var.environment}
    * Topic: ${each.value.topic_name}
    * Service: ${each.value.service_name}

    @${local.slack_channel}
  EOT

  # Comparing current 15min to previous 4 hours, alerting on 70% drop
  query = "pct_change(avg(last_15m),last_4h):sum:aws.sns.number_of_messages_published{topicname:${each.value.topic_name}}.rollup(sum, 900) < -70"

  monitor_thresholds {
    critical          = -70 # 70% drop
    critical_recovery = -50 # Recover when drop is less than 50%
    warning           = -50 # Warn at 50% drop
    warning_recovery  = -30 # Recover warning when drop is less than 30%
  }

  include_tags        = true
  notify_no_data      = true
  no_data_timeframe   = 30
  require_full_window = false
  evaluation_delay    = 900
  renotify_interval   = 60
  timeout_h           = 24

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "topic:${each.value.name}",
      "cluster:${each.value.cluster}",
      "ecs-service:${each.value.service_name}",
      "service:${each.value.name}"
    ]
  )

  priority = each.value.alert_settings.priority
}
