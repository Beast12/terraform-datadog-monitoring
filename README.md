# Terraform Datadog Monitoring

This repository provides a Terraform-based solution for setting up monitoring in Datadog. It includes scripts to generate Terraform variables and configurations for various applications and environments, facilitating efficient and consistent monitoring setups.

## Prerequisites

- **Python 3.x**: Ensure Python 3 is installed on your system. You can download it from the [official Python website](https://www.python.org/downloads/).
- **Terraform**: Install Terraform by following the instructions on the [Terraform website](https://www.terraform.io/downloads.html).
- **Datadog Account**: A valid Datadog account is required. Sign up at [Datadog](https://www.datadoghq.com/).

## Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/Beast12/terraform-datadog-monitoring.git
   cd terraform-datadog-monitoring
   ```

2. Install Python Dependencies:

It's recommended to use a virtual environment:

```bash
Copy code
python3 -m venv venv
source venv/bin/activate
```

Then, install the required packages:

```bash
pip install -r requirements.txt
```

## Configuration

### Applications Configuration

Define your applications in the monitor_configs/applications directory. Each application should have its own YAML file. Below is an example configuration for an application named example-app:

```yaml
# monitor_configs/applications/example-app.yaml
type: java
monitor_sets:
  logs:
    enabled: true
    services:
      example-service:
        custom_log_lines:
          - "Error processing request"
        thresholds:
          critical: 50
          critical_recovery: 40
          warning: 30
          warning_recovery: 20
```

### Environment Overrides

Environment-specific overrides are located in the monitor_configs/environments directory. Create a YAML file for each environment. Here's an example for a staging environment:

```yaml
# monitor_configs/environments/staging.yaml
threshold_overrides:
  logs:
    services:
      example-service:
        custom_log_lines:
          - "Error processing request"
        thresholds:
          critical: 60
          critical_recovery: 50
          warning: 40
          warning_recovery: 30
```

## Usage

1. Generate Terraform Variables:

Use the provided Python script to generate the terraform.tfvars.json file:

```bash
python3 scripts/generate_tf_vars.py \\
  --app-name example-app \\
  --env staging \\
  --apps-dir monitor_configs/applications \\
  --env-dir monitor_configs/environments \\
  --output tofu/environments/staging/terraform.tfvars.json
```

2. Initialize and Apply Terraform Configuration:

Navigate to the appropriate environment directory and apply the Terraform configuration:

```bash
cd tofu/environments/staging
terraform init
terraform apply
```

Review the plan and confirm the changes to set up the monitoring in Datadog.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes. Ensure that your code adheres to the existing style and includes appropriate tests.


