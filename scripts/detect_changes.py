#!/usr/bin/env python3
import os
import sys
import json

def get_changed_files():
    """Get list of changed files from Github event payload"""
    with open(os.environ['GITHUB_EVENT_PATH']) as f:
        event = json.load(f)
    return [f for f in event['commits'] if f['added'] + f['modified'] + f['removed']]

def parse_monitor_path(path):
    """Extract application and environment from monitor config path"""
    parts = path.split('/')
    if path.startswith('monitor_configs/applications/'):
        return {'application': parts[2], 'environment': None}
    elif path.startswith('monitor_configs/environments/'):
        return {'application': None, 'environment': parts[2]}
    return None

def get_affected_components(changed_files):
    """Determine which applications and environments were affected by changes"""
    apps = set()
    envs = set()
    
    for changes in changed_files:
        for path in changes['added'] + changes['modified'] + changes['removed']:
            result = parse_monitor_path(path)
            if result:
                if result['application']:
                    apps.add(result['application'])
                if result['environment']:
                    envs.add(result['environment'])
    
    return list(apps), list(envs)

def main():
    changed_files = get_changed_files()
    apps, envs = get_affected_components(changed_files)
    
    # Output in format for GitHub Actions
    if apps:
        print(f"applications={json.dumps(apps)}")
    else:
        print("applications=['api-gateway', 'business-portal', 'blockchain-providers', 'connect', 'evm-proxy', 'imx-blockchain-providers', 'login', 'nft-api', 'notifications', 'usages', 'pay', 'wallet', 'wallet-connect']")
    
    if envs:
        print(f"environments={json.dumps(envs)}")
    else:
        print("environments=['qa']")

if __name__ == '__main__':
    main()