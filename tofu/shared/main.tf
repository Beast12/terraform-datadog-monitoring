provider "datadog" {
  api_key  = var.datadog_api_key
  app_key  = var.datadog_app_key
  api_url  = "https://api.datadoghq.eu/"
  validate = false # Temporarily disable validation for debugging
}

module "ecs_monitoring" {
  source = "../../modules/infrastructure/ecs"

  project_name          = var.project_name
  services              = var.services
  notification_channels = var.notification_channels
  tags                  = var.tags
  environment           = var.environment
}

module "alb_monitoring" {
  source = "../../modules/infrastructure/alb"

  project_name          = var.project_name
  alb                   = var.alb
  notification_channels = var.notification_channels
  tags                  = var.tags
  environment           = var.environment
}

module "db_monitoring" {
  source = "../../modules/infrastructure/db"

  project_name          = var.project_name
  environment           = var.environment
  databases             = var.databases
  notification_channels = var.notification_channels
  tags                  = var.tags
}

module "sqs_monitoring" {
  source = "../../modules/messaging/sqs"

  project_name          = var.project_name
  environment           = var.environment
  queues                = var.queues
  notification_channels = var.notification_channels
  tags                  = var.tags
}

module "sns_monitoring" {
  source = "../../modules/messaging/sns"

  project_name          = var.project_name
  environment           = var.environment
  topics                = var.topics
  notification_channels = var.notification_channels
  tags                  = var.tags
}

module "java_monitoring" {
  source = "../../modules/application/java"

  project_name          = var.project_name
  environment           = var.environment
  java_services         = var.java_services
  notification_channels = var.notification_channels
  tags                  = var.tags
}

module "node_monitoring" {
  source = "../../modules/application/node"

  project_name          = var.project_name
  environment           = var.environment
  node_services         = var.node_services
  notification_channels = var.notification_channels
  tags                  = var.tags
}

module "apm_monitoring" {
  source = "../../modules/application/apm"

  project_name          = var.project_name
  environment           = var.environment
  apm_services          = var.apm_services
  notification_channels = var.notification_channels
  tags                  = var.tags
}

module "logs_monitoring" {
  source = "../../modules/logs"

  project_name          = var.project_name
  environment           = var.environment
  logs                  = var.logs
  notification_channels = var.notification_channels
  tags                  = var.tags
}
