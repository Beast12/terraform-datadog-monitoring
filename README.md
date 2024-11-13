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
name: "your-app"
description: "Your Application Description"
type: "java"  # or "node"
monitor_sets:
  infrastructure:
    ecs:
      enabled: true
      settings:
        services:
          your-service:
            thresholds:
              cpu_percent: 85
              memory_percent: 90
# ... (additional configuration as needed)
```

3. **Set Environment Overrides**

Create environment-specific settings in `monitor_configs/environments/`:

```yaml
environment: "staging"
cluster_name: "your-cluster-name"
notification_channels:
  infrastructure:
    ecs: "slack-ecs-alerts"
# ... (additional settings as needed)
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
