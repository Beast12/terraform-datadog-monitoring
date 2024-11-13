#!/usr/bin/env python3
import argparse
import json
import yaml
import os
from pathlib import Path

def load_yaml_file(file_path):
    """Load a YAML file and return its contents."""
    with open(file_path, 'r') as f:
        return yaml.safe_load(f)

def apply_overrides(service_settings, overrides):
    """Apply environment overrides to service settings."""
    for key, value in overrides.items():
        if key in service_settings:
            service_settings[key] = value
    return service_settings

def validate_db_names(app_config, env_config):
    """Validate that database names in environment config match application config."""
    if not env_config.get('threshold_overrides', {}).get('infrastructure', {}).get('db', {}).get('enabled', True):
        return  # Skip validation if DB monitoring is disabled

    app_db_names = set(
        app_config.get('monitor_sets', {})
        .get('infrastructure', {})
        .get('db', {})
        .get('settings', {})
        .get('databases', {}).keys()
    )
    
    env_db_names = set(
        env_config.get('threshold_overrides', {})
        .get('infrastructure', {})
        .get('db', {}).keys()
    ) - {'enabled'}  # Remove the 'enabled' key from comparison

    unknown_dbs = env_db_names - app_db_names
    if unknown_dbs:
        print(f"\nWarning: Found database overrides in environment config that don't exist in application config: {unknown_dbs}")
        print(f"Application database names: {app_db_names}")
        print(f"Environment override names: {env_db_names}")

def process_ecs_services(ecs_config, env_config, new_cluster_name, app_name):
    """Process ECS services configuration with threshold overrides."""
    services_config = {}

    # Retrieve the entire infrastructure overrides
    infrastructure_overrides = env_config.get('threshold_overrides', {}).get('infrastructure', {})

    for service_name, service_settings in ecs_config.get('settings', {}).get('services', {}).items():
        # Retrieve service-specific overrides directly from infrastructure overrides
        service_override = infrastructure_overrides.get(service_name, {})

        # Apply service-specific overrides, or fallback to defaults if no specific overrides exist
        service_config = {
            "name": service_name,
            "cluster": new_cluster_name,
            "thresholds": {
                "cpu_percent": service_override.get('cpu_percent', service_settings['thresholds'].get('cpu_percent', 85)),
                "memory_percent": service_override.get('memory_percent', service_settings['thresholds'].get('memory_percent', 90)),
                "memory_available": service_override.get('memory_available', service_settings['thresholds'].get('memory_available', 1024)),
                "network_errors": service_override.get('network_errors', service_settings['thresholds'].get('network_errors', 20)),
                "desired_count": service_override.get('desired_count', service_settings['thresholds'].get('desired_count', 2))
            },
            "alert_settings": {
                "priority": service_override.get('alert_settings', {}).get('priority', service_settings['alert_settings'].get('priority', '2')),
                "include_tags": service_override.get('alert_settings', {}).get('include_tags', service_settings['alert_settings'].get('include_tags', True))
            },
            "tags": {
                "application": app_name,
                "service": service_name
            }
        }

        services_config[f"{app_name}-{service_name}"] = service_config

    return services_config

def process_alb_config(alb_config, env_config, app_name):
    """Process ALB configuration."""
    alb_services_config = {}

    # Check if the ALB monitoring is enabled
    if alb_config.get('enabled', False):
        for service_name, service_settings in alb_config.get('settings', {}).get('services', {}).items():
            # Get environment overrides for the service
            alb_env_overrides = env_config.get('threshold_overrides', {}).get('infrastructure', {}).get('alb', {}).get(service_name, {})
            
            # Check if the ALB service should be enabled or not
            if alb_env_overrides.get('enabled', True):  # Default to True if not specified
                # Build the ALB service config with overrides
                alb_service_config = {
                    "name": service_name,
                    "alb_name": alb_env_overrides.get('alb_name', service_settings['alb_name']),
                    "thresholds": {
                        "request_count": alb_env_overrides.get('request_count', service_settings['thresholds'].get('request_count', 100)),
                        "latency": alb_env_overrides.get('latency', service_settings['thresholds'].get('latency', 200)),
                        "error_rate": alb_env_overrides.get('error_rate', service_settings['thresholds'].get('error_rate', 20)),
                    },
                    "alert_settings": {
                        "priority": alb_env_overrides.get('alert_settings', {}).get('priority', service_settings['alert_settings'].get('priority', '2')),
                        "include_tags": service_settings['alert_settings'].get('include_tags', True)
                    },
                    "tags": {
                        "application": app_name,
                        "service": service_name
                    }
                }

                alb_services_config[f"{app_name}-{service_name}"] = alb_service_config

    return alb_services_config

def process_db_config(db_config, env_config, app_name):
    """Process database configuration."""
    databases_config = {}

    # Check if the DB monitoring is enabled in the main config and overrides
    if db_config.get('enabled', True):  # Default to True if not specified
        for db_name, db_settings in db_config.get('settings', {}).get('databases', {}).items():
            # Get environment overrides for the database
            db_env_overrides = env_config.get('threshold_overrides', {}).get('infrastructure', {}).get('db', {}).get(db_name, {})
            
            # Check if the database should be enabled based on overrides
            if env_config.get('threshold_overrides', {}).get('infrastructure', {}).get('db', {}).get('enabled', True):
                # Build the database service config with overrides
                databases_config[f"{app_name}-{db_name}"] = {
                    "name": db_name,
                    "type": db_env_overrides.get('type', db_settings['type']),
                    "identifier": db_env_overrides.get('identifier', db_settings['identifier']),
                    "service_name": db_env_overrides.get('service_name', db_settings['service_name']),
                    "thresholds": {
                        "cpu_percent": db_env_overrides.get('cpu_percent', db_settings['thresholds'].get('cpu_percent', 80)),
                        "memory_threshold": db_env_overrides.get('memory_threshold', db_settings['thresholds'].get('memory_threshold', 2)),
                        "connection_threshold": db_env_overrides.get('connection_threshold', db_settings['thresholds'].get('connection_threshold', 100)),
                        "iops_threshold": db_env_overrides.get('iops_threshold', db_settings['thresholds'].get('iops_threshold', 2400))
                    },
                    "alert_settings": {
                        "priority": db_env_overrides.get('alert_settings', {}).get('priority', db_settings['alert_settings'].get('priority', '2')),
                        "include_tags": db_settings.get('alert_settings', {}).get('include_tags', True)
                    },
                    "tags": {
                        "application": app_name,
                        "database": db_name
                    }
                }
    
    return databases_config

def process_messaging(messaging_config, env_config, app_name):
    """Process messaging configuration (SQS and SNS)."""
    queues_config = {}
    topics_config = {}

    # Get the messaging overrides from the correct path
    messaging_overrides = env_config.get('threshold_overrides', {}).get('messaging', {})

    # Process SQS configuration
    sqs_enabled = messaging_config.get('sqs', {}).get('enabled', True)
    sqs_override_enabled = messaging_overrides.get('sqs', {}).get('enabled', True)
    
    if sqs_enabled and sqs_override_enabled:  # Check both main config and override
        for queue_name, queue_settings in messaging_config.get('sqs', {}).get('settings', {}).get('queues', {}).items():
            # Get environment overrides for the queue
            sqs_env_overrides = messaging_overrides.get('sqs', {}).get(queue_name, {})
            
            # Check if individual queue should be enabled
            if sqs_env_overrides.get('enabled', True):
                queues_config[f"{app_name}-{queue_name}"] = {
                    "name": queue_name,
                    "service_name": queue_settings['service_name'],
                    "queue_name": sqs_env_overrides.get('queue_name', queue_settings['queue_name']),
                    "dlq_name": sqs_env_overrides.get('dlq_name', queue_settings.get('dlq_name')),
                    "thresholds": {
                        "age_threshold": sqs_env_overrides.get('age_threshold', queue_settings.get('thresholds', {}).get('age_threshold', 300)),
                        "depth_threshold": sqs_env_overrides.get('depth_threshold', queue_settings.get('thresholds', {}).get('depth_threshold', 1000)),
                        "dlq_threshold": sqs_env_overrides.get('dlq_threshold', queue_settings.get('thresholds', {}).get('dlq_threshold', 1))
                    },
                    "alert_settings": {
                        "priority": sqs_env_overrides.get('alert_settings', {}).get('priority', "2"),
                        "include_tags": queue_settings.get('alert_settings', {}).get('include_tags', True)
                    },
                    "tags": {
                        "application": app_name,
                        "queue": queue_name
                    }
                }

    # Process SNS configuration
    sns_enabled = messaging_config.get('sns', {}).get('enabled', True)
    sns_override_enabled = messaging_overrides.get('sns', {}).get('enabled', True)
    
    if sns_enabled and sns_override_enabled:  # Check both main config and override
        for topic_name, topic_settings in messaging_config.get('sns', {}).get('settings', {}).get('topics', {}).items():
            sns_env_overrides = messaging_overrides.get('sns', {}).get(topic_name, {})
            
            # Check if individual topic should be enabled
            if sns_env_overrides.get('enabled', True):
                topics_config[f"{app_name}-{topic_name}"] = {
                    "name": topic_name,
                    "service_name": topic_settings['service_name'],
                    "topic_name": sns_env_overrides.get('topic_name', topic_settings['topic_name']),
                    "thresholds": {
                        "message_count_threshold": sns_env_overrides.get('message_count_threshold', topic_settings.get('thresholds', {}).get('message_count_threshold', 100)),
                        "age_threshold": sns_env_overrides.get('age_threshold', topic_settings.get('thresholds', {}).get('age_threshold', 300)),
                    },
                    "alert_settings": {
                        "priority": sns_env_overrides.get('alert_settings', {}).get('priority', "2"),
                        "include_tags": topic_settings.get('alert_settings', {}).get('include_tags', True)
                    },
                    "tags": {
                        "application": app_name,
                        "topic": topic_name
                    }
                }

    return queues_config, topics_config


def process_application_config(app_config, env_config):
    """Process application configuration for Java and Node.js services."""
    applications_config = {}

    # Ensure monitor_sets exists in app_config
    monitor_sets = app_config.get('monitor_sets', {})
    if not monitor_sets:
        print("Debug - No monitor_sets found in app_config.")
        return applications_config

    # Check for application monitoring settings within monitor_sets
    application_settings = monitor_sets.get('application', {})
    if not application_settings:
        print("Debug - No application settings found within monitor_sets.")
        return applications_config

    # Process Java monitoring
    java_config = application_settings.get('java', {})
    if app_config.get('type') == "java" and java_config.get('enabled', False):
        for service_name, service_config in java_config.get('services', {}).items():
            # Access the nested 'jvm' key in overrides
            jvm_env_overrides = env_config.get('threshold_overrides', {}).get('application', {}).get('java', {}).get('services', {}).get(service_name, {}).get('jvm', {})

            applications_config[f"{service_name}-jvm"] = {
                "name": service_name,
                "service_name": service_name,
                "thresholds": {
                    "jvm_memory_used": jvm_env_overrides.get('thresholds', {}).get('jvm_memory_used', 
                        service_config.get('thresholds', {}).get('jvm_memory_used', 1700)),
                    "minor_gc_time": jvm_env_overrides.get('minor_gc_time', 
                        service_config.get('thresholds', {}).get('minor_gc_time', 200)),
                    "major_gc_time": jvm_env_overrides.get('major_gc_time', 
                        service_config.get('thresholds', {}).get('major_gc_time', 150))
                },
                "alert_settings": {
                    "priority": jvm_env_overrides.get('alert_settings', {}).get('priority',
                        service_config.get('alert_settings', {}).get('priority', '2')),
                    "include_tags": service_config.get('alert_settings', {}).get('include_tags', True)
                },
                "tags": {
                    "application": app_config['name'],
                    "type": "java"
                }
            }
            print(f"Debug - Added Java service config for {service_name}")

    # Process Node.js monitoring
    node_config = application_settings.get('node', {})
    if app_config.get('type') == "node" and node_config.get('enabled', False):
        print("Debug - Node monitoring enabled and type is node")  # Debug print
        for service_name, service_config in node_config.get('services', {}).items():
            node_env_overrides = env_config.get('threshold_overrides', {}).get('application', {}).get('node', {}).get('services', {}).get(service_name, {})

            applications_config[f"{service_name}-node"] = {
                "name": service_name,
                "service_name": service_name,
                "thresholds": {
                    "cpu_total_usage": node_env_overrides.get('thresholds', {}).get('cpu_total_usage', 
                        service_config.get('thresholds', {}).get('cpu_total_usage', 85)),
                    "heap_memory_usage": node_env_overrides.get('thresholds', {}).get('heap_memory_usage', 
                        service_config.get('thresholds', {}).get('heap_memory_usage', 800)),
                    "event_loop_delay": node_env_overrides.get('thresholds', {}).get('event_loop_delay', 
                        service_config.get('thresholds', {}).get('event_loop_delay', 100))
                },
                "alert_settings": {
                    "priority": node_env_overrides.get('alert_settings', {}).get('priority',
                        service_config.get('alert_settings', {}).get('priority', '3')),
                    "include_tags": service_config.get('alert_settings', {}).get('include_tags', True)
                },
                "tags": {
                    "application": app_config['name'],
                    "type": "node"
                }
            }
    return applications_config

def process_apm_config(app_config, env_config):
    """Process APM monitoring configuration."""
    apm_config = {}

    # Check if APM is enabled for the application in the main config
    if app_config.get('monitor_sets', {}).get('application', {}).get('apm', {}).get('enabled', False):
        for service_name, service_settings in app_config['monitor_sets']['application']['apm']['services'].items():
            # Apply overrides if present in the environment config
            apm_env_overrides = env_config.get('threshold_overrides', {}).get('application', {}).get('apm', {}).get('services', {}).get(service_name, {})

            # Check if the service should be enabled, considering overrides
            service_enabled = apm_env_overrides.get('enabled', service_settings.get('enabled', True))
            if not service_enabled:
                print(f"Debug - APM monitoring disabled for {service_name}")
                continue  # Skip this service if APM is disabled

            # Build the APM service config with thresholds and overrides
            apm_config[f"{service_name}-apm"] = {
                "name": service_name,
                "service_name": service_name,
                "thresholds": {
                    "latency": apm_env_overrides.get('thresholds', {}).get('latency', service_settings.get('thresholds', {}).get('latency', 200)),
                    "error_rate": apm_env_overrides.get('thresholds', {}).get('error_rate', service_settings.get('thresholds', {}).get('error_rate', 0.05)),
                    "throughput": apm_env_overrides.get('thresholds', {}).get('throughput', service_settings.get('thresholds', {}).get('throughput', 100))
                },
                "alert_settings": {
                    "priority": apm_env_overrides.get('alert_settings', {}).get('priority', service_settings.get('alert_settings', {}).get('priority', '3')),
                    "include_tags": service_settings.get('alert_settings', {}).get('include_tags', True)
                },
                "tags": {
                    "application": app_config['name'],
                    "type": "apm"
                }
            }
            print(f"Debug - Added APM service config for {service_name}")

    return apm_config

def process_log_config(app_config, env_config):
    """Process log monitoring configuration for standalone log monitoring."""
    logs_config = {}

    # Check if 'logs' is enabled in the main configuration
    logs_main_config = app_config.get('monitor_sets', {}).get('logs', {})
    if not logs_main_config.get('enabled', False):
        print("Debug - Log monitoring is disabled.")
        return logs_config

    # Set index based on environment
    environment = env_config['environment']
    index = "main" if environment == "prd" else environment

    # Global error rate threshold, defaulting to 25 if not specified
    global_error_rate_threshold = env_config.get('threshold_overrides', {}).get('logs', {}).get('error_rate', 25)

    # Combine services from both main and override configurations
    main_services = logs_main_config.get('services', {})
    override_services = env_config.get('threshold_overrides', {}).get('logs', {}).get('services', {})

    # Create a combined list of services from main and overrides
    all_service_names = set(main_services.keys()).union(override_services.keys())

    for service_name in all_service_names:
        # Start with main configuration values, then apply overrides where present
        main_service_settings = main_services.get(service_name, {})
        override_service_settings = override_services.get(service_name, {})

        # Custom thresholds, with layering for each threshold type
        thresholds = {
            "critical": override_service_settings.get("thresholds", {}).get("critical",
                       main_service_settings.get("thresholds", {}).get("critical", global_error_rate_threshold)),
            "critical_recovery": override_service_settings.get("thresholds", {}).get("critical_recovery",
                                main_service_settings.get("thresholds", {}).get("critical_recovery", global_error_rate_threshold - 10)),
            "warning": override_service_settings.get("thresholds", {}).get("warning",
                       main_service_settings.get("thresholds", {}).get("warning", global_error_rate_threshold - 5)),
            "warning_recovery": override_service_settings.get("thresholds", {}).get("warning_recovery",
                                main_service_settings.get("thresholds", {}).get("warning_recovery", global_error_rate_threshold - 15))
        }

        # Error rate monitor for each service
        logs_config[f"{service_name}-error-rate"] = {
            "name": f"Error Rate Monitor for {service_name}",
            "query": f"logs(\"service:{service_name} env:{environment} status:error\").index(\"{index}\").rollup(\"count\").by(\"service\").last(\"5m\") > {thresholds['critical']}",
            "alert_settings": {
                "priority": "2",
                "include_tags": True
            },
            "thresholds": thresholds
        }

        # Add stack trace monitor if the application type is 'java'
        if app_config.get('type') == "java":
            logs_config[f"{service_name}-stack-trace"] = {
                "name": f"Stack Trace Monitor for {service_name}",
                "query": f"logs(\"service:{service_name} env:{environment} @stack_trace:*\").index(\"{index}\").rollup(\"count\").by(\"service\").last(\"5m\") > 25",
                "alert_settings": {
                    "priority": "1",
                    "include_tags": True
                },
                "thresholds": {
                    "critical": 25,
                    "critical_recovery": 10,
                    "warning": 15,
                    "warning_recovery": 5
                }
            }

        # Process custom log lines for each service
        custom_log_lines = override_service_settings.get("custom_log_lines",
                            main_service_settings.get("custom_log_lines", []))
        for log_line in custom_log_lines:
            # Quote log line if it contains spaces
            log_line_query = f'"{log_line}"' if " " in log_line else log_line

            logs_config[f"{service_name}-{log_line}"] = {
                "name": f"Custom Log Monitor for '{log_line}'",
                "query": f"logs(\"service:{service_name} env:{environment} {log_line_query}\").index(\"{index}\").rollup(\"count\").by(\"service\").last(\"5m\") > {thresholds['critical']}",
                "alert_settings": {
                    "priority": "3",
                    "include_tags": True
                },
                "thresholds": thresholds
            }

    return logs_config


def process_app_config(app_config, env_config):
    """Process application configuration with environment overrides."""

    ecs_config = app_config['monitor_sets']['infrastructure'].get('ecs', {})
    alb_config = app_config['monitor_sets']['infrastructure'].get('alb', {})
    db_config = app_config['monitor_sets']['infrastructure'].get('db', {})
    messaging_config = app_config.get('monitor_sets', {}).get('messaging', {})

    new_cluster_name = env_config.get('cluster_name', f"{app_config['name']}-cluster")
    app_name = app_config['name']  # Define app_name from app_config

    services_config = process_ecs_services(ecs_config, env_config, new_cluster_name, app_name) if ecs_config.get('enabled', False) else {}
    databases_config = process_db_config(db_config, env_config, app_name)
    queues_config, topics_config = process_messaging(messaging_config, env_config, app_name)
    alb_services_config = process_alb_config(alb_config, env_config, app_name)
    applications_config = process_application_config(app_config, env_config)
    apm_config = process_apm_config(app_config, env_config)
    logs_config= process_log_config(app_config, env_config)

    return services_config, databases_config, queues_config, topics_config, alb_services_config, applications_config, apm_config, logs_config


def main():
    parser = argparse.ArgumentParser(description='Generate Terraform variables from YAML configs')
    parser.add_argument('--env', required=True, help='Environment name')
    parser.add_argument('--app-name', required=True, help='Name of the application')
    parser.add_argument('--apps-dir', required=True, help='Applications config directory')
    parser.add_argument('--env-dir', required=True, help='Environments config directory')
    parser.add_argument('--output', required=True, help='Output file path')

    args = parser.parse_args()

    # Update path resolution for environment-specific overrides
    env_config_path = os.path.join(args.env_dir, args.app_name, f"{args.env}.yaml")
    if not os.path.exists(env_config_path):
        raise FileNotFoundError(f"Environment config for {args.app_name} in {args.env} not found: {env_config_path}")
        
    env_config = load_yaml_file(env_config_path)

    # Process application configs
    app_files = list(Path(args.apps_dir).glob(f"{args.app_name}.yaml"))
    if len(app_files) != 1:
        raise ValueError(f"Expected exactly one application config for {args.app_name}, found {len(app_files)}")
    
    app_config = load_yaml_file(app_files[0])
    services_config, databases_config, queues_config, topics_config, alb_services_config, applications_config, apm_config, logs_config = process_app_config(app_config, env_config)

    
    tf_vars = {
        "project_name": app_config['name'].lower(),
        "environment": args.env,
        "services": services_config,
        "alb": alb_services_config,
        "databases": databases_config,
        "queues": queues_config,
        "topics": topics_config,
        "java_services": {k: v for k, v in applications_config.items() if v["tags"]["type"] == "java"},
        "node_services": {k: v for k, v in applications_config.items() if v["tags"]["type"] == "node"}, 
        "apm_services": apm_config,
        "logs": logs_config,
        "notification_channels": env_config.get('notification_channels', {
            "infrastructure": {
                "ecs": f"dd-ecs-alerts-p2",
                "alb": f"dd-elb-alerts-p2",
                "rds": f"dd-rds-alerts-p2"
            },
            "messaging": {
                "sns": f"dd-sns-alerts-p2",
                "sqs": f"dd-sqs-alerts-p2"
            },
            "application": {
                "java": f"dd-apm-alerts-p2",
                "node": f"dd-apm-alerts-p2",
                "apm": f"dd-apm-alerts-p2"
            },
            "logs": "dd-logs-alerts-p2",
            "default": "dd-ecs-alerts-p2"
        }),
        "tags": {
            "environment": args.env,
            "managed_by": "terraform",
            "project": app_config['name'].lower()
        }
    }

    os.makedirs(os.path.dirname(args.output), exist_ok=True)

    print(f"\nWriting configuration to: {args.output}")
    with open(args.output, 'w') as f:
        json.dump(tf_vars, f, indent=2)
        
    print("\nGenerated configuration:")
    print(json.dumps(tf_vars, indent=2))


if __name__ == "__main__":
    main()
