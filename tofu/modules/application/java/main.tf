locals {
  monitor_tags = concat(
    [for k, v in var.tags : "${k}:${v}"],
    [
      "service_type:java",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ]
  )

  slack_channel = try(
    var.notification_channels.application["java"],
    var.notification_channels.default
  )
}

# JVM Memory Usage Monitor
resource "datadog_monitor" "jvm_memory_usage" {
  for_each = var.java_services

  name    = "[${var.environment}] JVM Memory Usage - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## JVM Heap Memory Usage for ${each.value.name}

    Current Average JVM Heap Memory Used: {{value}} MB
    Threshold: ${each.value.thresholds.jvm_memory_used} MB

    This could indicate:
    * Memory leaks
    * Insufficient heap space

    Please investigate:
    * Application logs
    * Memory allocation patterns
    * Heap dump analysis

    @${local.slack_channel}
  EOT

  query = "avg(last_30m):avg:jvm.heap_memory{service:${each.value.service_name},env:${var.environment}} > ${each.value.thresholds.jvm_memory_used * 1024 * 1024}" # Convert MB to bytes

  monitor_thresholds {
    critical          = each.value.thresholds.jvm_memory_used * 1024 * 1024
    critical_recovery = each.value.thresholds.jvm_memory_used * 0.8 * 1024 * 1024
    warning           = each.value.thresholds.jvm_memory_used * 0.75 * 1024 * 1024
    warning_recovery  = each.value.thresholds.jvm_memory_used * 0.6 * 1024 * 1024
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = true
  evaluation_delay    = 600 # Wait for 10 minutes before evaluating the monitor

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.service_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}


# JVM GC Time Monitor
resource "datadog_monitor" "jvm_minor_gc_time" {
  for_each = var.java_services

  name    = "[${var.environment}] JVM Minor GC Time - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## JVM Minor GC Time for ${each.value.name}

    Current Minor GC Time: {{value}} ms
    Threshold: ${each.value.thresholds.minor_gc_time} ms

    This could indicate:
    * High frequency of minor GCs
    * Insufficient heap space

    Please investigate:
    * Application logs
    * Memory allocation patterns

    @${local.slack_channel}
  EOT

  query = "avg(last_15m):( sum:jvm.gc.minor_collection_time{service:${each.value.service_name},env:${var.environment}}.as_rate() / sum:jvm.gc.minor_collection_count{service:${each.value.service_name},env:${var.environment}}.as_rate() ) > ${each.value.thresholds.minor_gc_time}"

  monitor_thresholds {
    critical          = each.value.thresholds.minor_gc_time
    critical_recovery = each.value.thresholds.minor_gc_time * 0.8
    warning           = each.value.thresholds.minor_gc_time * 0.85
    warning_recovery  = each.value.thresholds.minor_gc_time * 0.7
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 300

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.service_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

resource "datadog_monitor" "jvm_major_gc_time" {
  for_each = var.java_services

  name    = "[${var.environment}] JVM Major GC Time - ${each.value.name}"
  type    = "metric alert"
  message = <<-EOT
    ## JVM Major GC Time for ${each.value.name}

    Current Major GC Time: {{value}} ms
    Threshold: ${each.value.thresholds.major_gc_time} ms

    This could indicate:
    * High frequency of major GCs
    * Insufficient heap space

    Please investigate:
    * Application logs
    * Memory allocation patterns

    @${local.slack_channel}
  EOT

  query = "avg(last_15m):( sum:jvm.gc.major_collection_time{service:${each.value.service_name},env:${var.environment}}.as_rate() / sum:jvm.gc.major_collection_count{service:${each.value.service_name},env:${var.environment}}.as_rate() ) > ${each.value.thresholds.major_gc_time}"

  monitor_thresholds {
    critical          = each.value.thresholds.major_gc_time
    critical_recovery = each.value.thresholds.major_gc_time * 0.7
    warning           = each.value.thresholds.major_gc_time * 0.75
    warning_recovery  = each.value.thresholds.major_gc_time * 0.5
  }


  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 300

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "service:${each.value.service_name}"
    ]
  )

  priority = each.value.alert_settings.priority
}

