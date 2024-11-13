#!/usr/bin/env python3
# scripts/validate_configs.py

import os
import yaml
import sys
from pathlib import Path

def validate_monitor_config(config, file_path):
    """Validate a single monitor configuration."""
    required_fields = ['name', 'description', 'type', 'monitor_sets']
    
    for field in required_fields:
        if field not in config:
            print(f"Error in {file_path}: Missing required field '{field}'")
            return False
            
    if 'monitor_sets' not in config:
        print(f"Error in {file_path}: No monitor_sets defined")
        return False
        
    return True

def validate_environment_config(config, file_path):
    """Validate a single environment configuration."""
    required_fields = ['environment', 'notification_channels', 'threshold_overrides']
    
    for field in required_fields:
        if field not in config:
            print(f"Error in {file_path}: Missing required field '{field}'")
            return False
            
    return True

def main():
    script_dir = Path(__file__).parent.parent
    apps_dir = script_dir / 'monitor_configs' / 'applications'
    envs_dir = script_dir / 'monitor_configs' / 'environments'
    
    print(f"Checking configurations in {apps_dir} and {envs_dir}")
    
    has_error = False
    
    # Validate application configs
    if apps_dir.exists():
        for config_file in apps_dir.glob('*.yaml'):
            print(f"Validating {config_file}")
            try:
                with open(config_file) as f:
                    config = yaml.safe_load(f)
                if not validate_monitor_config(config, config_file):
                    has_error = True
            except yaml.YAMLError as e:
                print(f"Error parsing {config_file}: {e}")
                has_error = True
    else:
        print(f"Applications directory not found: {apps_dir}")
        has_error = True
    
    # Validate environment configs
    if envs_dir.exists():
        for config_file in envs_dir.glob('*.yaml'):
            print(f"Validating {config_file}")
            try:
                with open(config_file) as f:
                    config = yaml.safe_load(f)
                if not validate_environment_config(config, config_file):
                    has_error = True
            except yaml.YAMLError as e:
                print(f"Error parsing {config_file}: {e}")
                has_error = True
    else:
        print(f"Environments directory not found: {envs_dir}")
        has_error = True
    
    if has_error:
        print("Validation failed!")
        sys.exit(1)
    else:
        print("All configurations are valid!")
        sys.exit(0)

if __name__ == "__main__":
    main()