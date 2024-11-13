# Terraform Datadog Monitoring

A comprehensive Terraform solution for setting up and managing Datadog monitoring across multiple AWS services and application types. This module provides automated, consistent monitoring setup with environment-specific configurations and extensive customization options.

## Features

### AWS Service Monitoring

- **ECS (Elastic Container Service)**: Container-level metrics and health monitoring
- **RDS/Aurora**: Database performance and health metrics
- **Application Load Balancer**: Request metrics and latency monitoring
- **SQS/SNS**: Message queue monitoring and dead letter queue alerts

### Application Monitoring

- **APM Integration**: Full application performance monitoring
- **Language-Specific Monitoring**:
  - Java: JVM metrics, garbage collection, memory usage
  - Node.js: Event loop, heap memory, CPU utilization
- **Log Management**: Custom log patterns, error rate tracking
- **Slack Integration**: Automated alerts and notifications

## Prerequisites

- Python 3.x
- Terraform >= 1.0
- Valid Datadog account with API and APP keys
- AWS credentials with appropriate permissions
- Slack workspace (for notifications)

## Quick Start

1. **Clone and Setup**

```bash
git clone https://github.com/Beast12/terraform-datadog-monitoring.git
cd terraform-datadog-monitoring

# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. **Configure Your Application**

Create a YAML configuration file in `monitor_configs/applications/`:

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
              memory_threshold: 2
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

3. **Set Environment Overrides**

Create environment-specific settings in `monitor_configs/environments/`:

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
          jvm:
            thresholds:
              jvm_memory_used: 2048
            alert_settings:
              priority: "4"
        example-app-2:
          jvm:
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

4. **Generate and Apply Configuration**

```bash
# Generate Terraform variables
python3 scripts/generate_tf_vars.py \
  --app-name your-app \
  --env staging \
  --apps-dir monitor_configs/applications \
  --env-dir monitor_configs/environments \
  --output tofu/environments/staging/terraform.tfvars.json

# Apply Terraform configuration
cd tofu/environments/staging
terraform init
terraform plan
terraform apply
```

## Configuration Structure

### Application Configuration

- Located in `monitor_configs/applications/`
- Defines base monitoring settings
- Includes service-specific thresholds
- Configures monitor types and alert conditions

### Environment Overrides

- Located in `monitor_configs/environments/`
- Override default thresholds per environment
- Configure environment-specific notification channels
- Enable/disable specific monitoring features

## Alert Priority Levels

| Priority | Description | Use Case |
|----------|-------------|-----------|
| P1 | Critical | Production-breaking issues |
| P2 | High | Significant service degradation |
| P3 | Medium | Performance issues |
| P4 | Low | Non-critical warnings |

## Best Practices

1. **Threshold Management**
   - Start with conservative thresholds
   - Adjust based on application behavior
   - Use different thresholds for different environments

2. **Alert Configuration**
   - Group related alerts
   - Include relevant tags
   - Set appropriate notification channels

3. **Environment Separation**
   - Maintain separate configurations per environment
   - Use stricter thresholds in production
   - Adjust notification priorities accordingly

## Troubleshooting

Common issues and solutions:

1. **Variable Generation Fails**
   - Verify YAML syntax in configuration files
   - Ensure all required fields are present
   - Check Python environment setup

2. **Terraform Apply Errors**
   - Validate Datadog API/APP keys
   - Check AWS credentials and permissions
   - Verify resource naming conventions

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow existing code style and conventions
- Add tests for new features
- Update documentation as needed
- Follow semantic versioning

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Create an issue for bug reports or feature requests
- Check existing issues for solutions
- Contact maintainers for critical issues

## Acknowledgments

- Datadog API Documentation
- Terraform AWS Provider
- Community contributors
