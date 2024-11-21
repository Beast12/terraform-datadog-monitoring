#!/usr/bin/env python3
import os
import sys
import json
import subprocess

def get_changed_files():
    """Get list of changed files using git diff"""
    try:
        # Get the base and head SHAs
        if os.environ.get('GITHUB_BASE_REF'):
            # For pull requests
            base = f"origin/{os.environ['GITHUB_BASE_REF']}"
        else:
            # For pushes
            base = "HEAD^"
        
        # Get changed files
        cmd = ['git', 'diff', '--name-only', base, 'HEAD']
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout.splitlines()
    except Exception as e:
        print(f"Error getting changed files: {e}", file=sys.stderr)
        return []

def parse_monitor_path(path):
    """Extract application and environment from monitor config path"""
    if not path.startswith('monitor_configs/'):
        return None
        
    parts = path.split('/')
    if len(parts) < 3:
        return None
        
    if parts[1] == 'applications':
        # monitor_configs/applications/app-name/...
        return {'application': parts[2], 'environment': None}
    elif parts[1] == 'environments':
        # monitor_configs/environments/env-name/...
        return {'application': None, 'environment': parts[2]}
    return None

def main():
    changed_files = get_changed_files()
    apps = set()
    envs = set()
    
    for path in changed_files:
        result = parse_monitor_path(path)
        if result:
            if result['application']:
                apps.add(result['application'])
            if result['environment']:
                envs.add(result['environment'])
    
    # Output in format for GitHub Actions
    if apps:
        print(f"applications={json.dumps(list(apps))}")
    else:
        # Default to all apps if no specific changes detected
        print("applications=['api-gateway', 'business-portal', 'blockchain-providers', 'connect', 'evm-proxy', 'imx-blockchain-providers', 'login', 'nft-api', 'notifications', 'usages', 'pay', 'wallet', 'wallet-connect']")
    
    if envs:
        print(f"environments={json.dumps(list(envs))}")
    else:
        # Default to qa if no specific environment changes detected
        print("environments=['qa']")

if __name__ == '__main__':
    main()