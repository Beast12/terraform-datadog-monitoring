# scripts/validate_datadog_creds.py
import os
import sys
import requests

def validate_datadog_credentials():
    api_key = os.environ.get('DATADOG_API_KEY')
    app_key = os.environ.get('DATADOG_APP_KEY')
    
    if not api_key or not app_key:
        print("Error: Missing Datadog credentials in environment variables")
        return False
    
    # Test the credentials against Datadog EU API
    headers = {
        'DD-API-KEY': api_key,
        'DD-APPLICATION-KEY': app_key,
    }
    
    try:
        response = requests.get(
            'https://api.datadoghq.eu/api/v1/validate',
            headers=headers
        )
        
        if response.status_code == 200:
            print("Datadog credentials are valid!")
            return True
        else:
            print(f"Error validating Datadog credentials: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except Exception as e:
        print(f"Error testing Datadog credentials: {e}")
        return False

if __name__ == "__main__":
    if not validate_datadog_credentials():
        sys.exit(1)