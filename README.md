<div align="center">

# 🎯 Terraform Datadog Monitoring

[![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Datadog](https://img.shields.io/badge/datadog-%23632CA6.svg?style=for-the-badge&logo=datadog&logoColor=white)](https://www.datadoghq.com/)

*A comprehensive Terraform solution for automated Datadog monitoring across AWS services*

</div>

---
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support%20me-FFDD00?style=flat&logo=buy-me-a-coffee)](https://buymeacoffee.com/koen1203)
## 🌟 Features

### 🌐 AWS Service Monitoring

- 🐳 **ECS (Elastic Container Service)**: Container-level metrics and health monitoring
- 🗄️ **RDS/Aurora**: Database performance and health metrics
- ⚖️ **Application Load Balancer**: Request metrics and latency monitoring
- 📨 **SQS/SNS**: Message queue monitoring and dead letter queue alerts

### 📊 Application Monitoring

- 🔍 **APM Integration**: Full application performance monitoring
- 💻 **Language-Specific Monitoring**:
  - ☕ Java: JVM metrics, garbage collection, memory usage
  - 📦 Node.js: Event loop, heap memory, CPU utilization
- 📝 **Log Management**: Custom log patterns, error rate tracking
- 💬 **Slack Integration**: Automated alerts and notifications

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/Beast12/terraform-datadog-monitoring.git
cd terraform-datadog-monitoring

# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Prerequisites

- 🐍 Python 3.x
- 🏗️ Terraform >= 1.0
- 🔑 Valid Datadog account with API and APP keys
- ☁️ AWS credentials with appropriate permissions
- 💬 Slack workspace (for notifications)

### 3. Configure Your Application

Create a configuration file in `monitor_configs/applications/`:

<details>
<summary>📄 View Example Configuration</summary>

```yaml
name: "example-app-1"
description: "Example API Service"
type: "java"
monitor_sets:
  infrastructure:
    ecs:
      enabled: true
      settings:
        services:
          example-app-1:
            thresholds:
              cpu_percent: 85
              memory_percent: 90
              memory_available: 1024
              network_errors: 20
            alert_settings:
              include_tags: true
              priority: "3"
          example-app-2:
            thresholds:
              cpu_percent: 85
              memory_percent: 90
              memory_available: 1024
              network_errors: 20
            alert_settings:
              include_tags: true
              priority: "3"
    alb:
      enabled: true
      settings:
        services:
          example-app-1:
            alb_name: "example-app-1-alb"
            thresholds:
              request_count: 100
              latency: 200
              error_rate: 20
            alert_settings:
              include_tags: true
              priority: "3"
    db:
      enabled: true
      settings:
        databases:
          example-app-1:
            type: "rds"
            identifier: "example-app-1-placeholder"
            service_name: "example-app-1"
            thresholds:
              cpu_percent: 80
              memory_threshold: 2048
              connection_threshold: 100
            alert_settings:
              include_tags: true
              priority: "3"
  messaging:
    sqs:
      enabled: true
      settings:
        queues:
          example-app-1-application-events:
            queue_name: "example-app-1-application-events"
            dlq_name: "example-app-1-application-events-dlq"
            service_name: "example-app-1"
            thresholds:
              age_threshold: 300
              depth_threshold: 1000
              dlq_threshold: 1
            alert_settings:
              include_tags: true
              priority: "3"
    sns:
      enabled: false
      settings:
        topics:
          example-app-1:
            topic_name: "example-app-1-topic"
            service_name: "example-app-1"
            thresholds:
              message_count_threshold: 100
              age_threshold: 300
            alert_settings:
              include_tags: true
              priority: "3"
  application:
    apm:
      enabled: true
      services:
        example-app-1:
          thresholds:
            latency: 200 # in ms
            error_rate: 0.05 # 5% error rate
            throughput: 100 # requests per minute
          alert_settings:
            priority: "3"
            include_tags: true
        example-app-2:
          enabled: false
          thresholds:
            latency: 250
            error_rate: 0.07
            throughput: 120
          alert_settings:
            priority: "3"
            include_tags: true
    java:
      enabled: true
      services:
        example-app-1:
          thresholds:
            jvm_memory_used: 1700
            minor_gc_time: 200 # Set your desired threshold for minor GC
            major_gc_time: 150
          alert_settings:
            priority: "3"
        example-app-2:
          thresholds:
            jvm_memory_used: 1700
            minor_gc_time: 200 # Set your desired threshold for minor GC
            major_gc_time: 150
          alert_settings:
            priority: "3"
  logs:
    enabled: true
    services:
      example-app-1:
        custom_log_lines:
          - "Error getting balance for wallet"
        thresholds:
          critical: 20
          critical_recovery: 15
          warning: 10
          warning_recovery: 5
      example-app-2:
        custom_log_lines:
          - "io.venly.tokenapi.common.exception.WalletBusinessException: An unexpected error occurred. Please contact support!"
        thresholds:
          critical: 20
          critical_recovery: 15
          warning: 10
          warning_recovery: 5
```
</details>

### 4. Set Environment Overrides

Create environment-specific settings in `monitor_configs/environments/`:

<details>
<summary>📄 View Example Environment Config</summary>

```yaml
environment: "qa"
cluster_name: "example-app-1-qa-cluster"
notification_channels:
  infrastructure:
    ecs: "slack-ecs-alerts-p2"
    alb: "slack-elb-alerts-p2"
    rds: "slack-rds-alerts-p2"
  messaging:
    sns: "slack-sns-alerts-p2"
    sqs: "slack-sqs-alerts-p2"
  application:
    java: "slack-apm-alerts-p2"
    node: "slack-apm-alerts-p2"
    apm: "slack-apm-alerts-p2"
  logs: "slack-logs-alerts-p2"
  default: "slack-ecs-alerts-p2"

threshold_overrides:
  infrastructure:
    ecs:
      example-app-1:
        cpu_percent: 90
        memory_percent: 90
        memory_available: 2048
        network_errors: 10
        alert_settings:
          priority: "4"
      example-app-2:
        cpu_percent: 90
        memory_percent: 90
        memory_available: 2048
        network_errors: 15
        alert_settings:
          priority: "3"
    alb:
      example-app-1:
        enabled: false
    db:
      enabled: false
  messaging:
    sqs:
      enabled: false
    sns:
      enabled: false
  application:
    apm:
      enabled: true
      services:
        example-app-1:
          thresholds:
            latency: 150
            error_rate: 10
            throughput: 90
          alert_settings:
            priority: "4"
        example-app-2:
          thresholds:
            latency: 220
            error_rate: 10
            throughput: 110
          alert_settings:
            priority: "4"
    java:
      enabled: true
      services:
        example-app-1:
            thresholds:
              jvm_memory_used: 2048
            alert_settings:
              priority: "4"
        example-app-2:
            thresholds:
              jvm_memory_used: 2048
            alert_settings:
              priority: "4"
  logs:
    services:
      example-app-1:
        thresholds:
          critical: 50
          critical_recovery: 40
          warning: 35
          warning_recovery: 30
      example-app-2:
        thresholds:
          critical: 50
          critical_recovery: 40
          warning: 35
          warning_recovery: 30
```
</details>

## 🔄 GitHub Actions Workflow

### Required Secrets

```yaml
DATADOG_API_KEY: Your Datadog API key
DATADOG_APP_KEY: Your Datadog application key
RESOURCES_DEPLOY_ROLE: AWS IAM role ARN for deployment
```

### Manual Deployment

1. Go to the "Actions" tab in your GitHub repository
2. Select "Deploy Datadog Monitoring"
3. Choose your options:
   - 🎯 Action: apply/destroy
   - 📦 Application: specific app or all
   - 🌍 Environment: specific environment or all
4. Click "Run workflow"

## 🎯 Alert Priority Levels

| Priority | Severity | Use Case | Response Time |
|----------|----------|----------|---------------|
| P1 | 🔴 Critical | Production-breaking issues | Immediate |
| P2 | 🟠 High | Significant service degradation | < 30 mins |
| P3 | 🟡 Medium | Performance issues | < 2 hours |
| P4 | 🟢 Low | Non-critical warnings | Next business day |

## 💡 Best Practices

### 📊 Threshold Management

- Start with conservative thresholds
- Adjust based on application behavior
- Use different thresholds for different environments

### ⚡ Alert Configuration

- Group related alerts
- Include relevant tags
- Set appropriate notification channels

### 🌍 Environment Separation

- Maintain separate configurations per environment
- Use stricter thresholds in production
- Adjust notification priorities accordingly

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Create an issue for bug reports or feature requests
- Check existing issues for solutions
- Contact maintainers for critical issues

---

<div align="center">

Made with ❤️ for DevOps

</div>
