<div align="center">

# 🎯 Terraform Datadog Monitoring

[![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Datadog](https://img.shields.io/badge/datadog-%23632CA6.svg?style=for-the-badge&logo=datadog&logoColor=white)](https://www.datadoghq.com/)

*A comprehensive Terraform solution for automated Datadog monitoring across AWS services*

</div>

---

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
# ... (rest of the configuration)
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
# ... (rest of the configuration)
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

Made with ❤️ by the Infrastructure Team

</div>