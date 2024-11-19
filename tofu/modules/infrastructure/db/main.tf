locals {
  monitor_tags = concat(
    [for k, v in var.tags : "${k}:${v}"],
    [
      "service_type:database",
      "environment:${var.environment}",
      "env:${var.environment}",
      "projectname:${var.project_name}"
    ]
  )

  slack_channel = try(
    var.notification_channels.infrastructure["rds"],
    var.notification_channels.default
  )
}

# CPU Usage Monitor
resource "datadog_monitor" "cpu_usage" {
  for_each = var.databases

  name    = "[${var.environment}] RDS ${each.value.name} - High CPU Usage"
  type    = "metric alert"
  message = <<-EOT
    ## Database ${each.value.name} is experiencing high CPU usage

    Current CPU Usage: {{value}}%
    Threshold: ${each.value.thresholds.cpu_percent}%

    This could indicate:
    * Long-running queries
    * High connection count
    * Query performance issues
    * Background processes (vacuum, analyze)

    Please investigate:
    * Active queries and their duration
    * Connection count
    * Slow query logs
    * Recent schema changes

    @${local.slack_channel}
  EOT

  query = format(
    "min(last_1h):avg:%s{db%sidentifier:%s} > %d",
    each.value.type == "aurora" ? "aws.rds.cpuutilization" : "aws.rds.cpuutilization",
    each.value.type == "aurora" ? "cluster" : "instance",
    each.value.identifier,
    each.value.thresholds.cpu_percent
  )

  monitor_thresholds {
    critical          = each.value.thresholds.cpu_percent
    critical_recovery = each.value.thresholds.cpu_percent * 0.8
    warning           = each.value.thresholds.cpu_percent * 0.85
    warning_recovery  = each.value.thresholds.cpu_percent * 0.75
  }


  include_tags      = true
  notify_no_data    = true
  no_data_timeframe = 20
  evaluation_delay  = 900

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "database:${each.value.name}",
      "type:${each.value.type}",
      "service:${each.value.service_name}",
    ]
  )

  priority = each.value.alert_settings.priority
}

# Memory Usage (Freeable Memory) Monitor
resource "datadog_monitor" "memory_usage" {
  for_each = var.databases

  name    = "[${var.environment}] RDS ${each.value.name} - Low Freeable Memory"
  type    = "metric alert"
  message = <<-EOT
    ## Database ${each.value.name} is running low on freeable memory

    Current Freeable Memory: {{value}} MB
    Threshold: ${each.value.thresholds.memory_threshold} MB

    This could indicate:
    * Memory pressure
    * Large query operations
    * Too many connections
    * Inefficient queries

    Please investigate:
    * Current query operations
    * Connection count
    * Query plans
    * Buffer cache usage

    @${local.slack_channel}
  EOT

  query = format(
    "min(last_1h):avg:%s{db%sidentifier:%s} < %d",
    each.value.type == "aurora" ? "aws.rds.freeable_memory" : "aws.rds.freeable_memory",
    each.value.type == "aurora" ? "cluster" : "instance",
    each.value.identifier,
    each.value.thresholds.memory_threshold * 1048576
  )

  monitor_thresholds {
    critical          = each.value.thresholds.memory_threshold * 1048576
    critical_recovery = each.value.thresholds.memory_threshold * 1.2 * 1048576 # 20% above critical
    warning           = each.value.thresholds.memory_threshold * 1.4 * 1048576 # 40% above critical
    warning_recovery  = each.value.thresholds.memory_threshold * 1.6 * 1048576 # 60% above critical
  }

  include_tags        = true
  notify_no_data      = false
  require_full_window = false
  evaluation_delay    = 900

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "database:${each.value.name}",
      "type:${each.value.type}",
      "service:${each.value.service_name}",
    ]
  )

  priority = each.value.alert_settings.priority
}

# Connection Count Monitor
resource "datadog_monitor" "connections" {
  for_each = var.databases

  name    = "[${var.environment}] RDS ${each.value.name} - High Connection Count"
  type    = "metric alert"
  message = <<-EOT
    ## Database ${each.value.name} has a high number of connections

    Current Connections: {{value}}
    Threshold: ${each.value.thresholds.connection_threshold}

    This could indicate:
    * Connection leaks
    * Missing connection pooling
    * Application issues
    * High load

    Please investigate:
    * Active connections and their states
    * Connection pooling settings
    * Application connection handling
    * Max connections setting

    @${local.slack_channel}
  EOT

  query = format(
    "avg(last_1h):avg:%s{db%sidentifier:%s} > %d",
    each.value.type == "aurora" ? "aws.rds.database_connections" : "aws.rds.database_connections",
    each.value.type == "aurora" ? "cluster" : "instance",
    each.value.identifier,
    each.value.thresholds.connection_threshold
  )

  monitor_thresholds {
    critical          = each.value.thresholds.connection_threshold
    critical_recovery = floor(each.value.thresholds.connection_threshold * 0.8)
    warning           = floor(each.value.thresholds.connection_threshold * 0.85)
    warning_recovery  = floor(each.value.thresholds.connection_threshold * 0.75)
  }


  include_tags      = true
  notify_no_data    = true
  no_data_timeframe = 20
  evaluation_delay  = 900

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "database:${each.value.name}",
      "type:${each.value.type}",
      "service:${each.value.service_name}",
    ]
  )

  priority = each.value.alert_settings.priority
}

# IOPS Monitor
resource "datadog_monitor" "iops_usage" {
  for_each = var.databases

  name    = "[${var.environment}] RDS ${each.value.name} - High IOPS Usage"
  type    = "metric alert"
  message = <<-EOT
    ## Database ${each.value.name} is experiencing high IOPS usage

    Current IOPS: {{value}}
    Threshold: ${each.value.thresholds.iops_threshold}

    This could indicate:
    * Heavy write operations
    * Missing indexes
    * Table scans
    * Inefficient queries

    Please investigate:
    * Slow query logs
    * Query plans
    * Index usage
    * I/O statistics

    @${local.slack_channel}
  EOT

  query = format(
    "avg(last_1h):(avg:aws.rds.write_iops{db%sidentifier:%s} + avg:aws.rds.read_iops{db%sidentifier:%s}) > %d",
    each.value.type == "aurora" ? "cluster" : "instance",
    each.value.identifier,
    each.value.type == "aurora" ? "cluster" : "instance",
    each.value.identifier,
    each.value.thresholds.iops_threshold
  )

  monitor_thresholds {
    critical          = each.value.thresholds.iops_threshold
    critical_recovery = floor(each.value.thresholds.iops_threshold * 0.8)
    warning           = floor(each.value.thresholds.iops_threshold * 0.85)
    warning_recovery  = floor(each.value.thresholds.iops_threshold * 0.75)
  }

  include_tags      = true
  notify_no_data    = true
  no_data_timeframe = 20
  evaluation_delay  = 900
  renotify_interval = 60

  tags = concat(
    local.monitor_tags,
    [for k, v in each.value.tags : "${k}:${v}"],
    [
      "database:${each.value.name}",
      "type:${each.value.type}",
      "service:${each.value.service_name}",
    ]
  )

  priority = each.value.alert_settings.priority
}
