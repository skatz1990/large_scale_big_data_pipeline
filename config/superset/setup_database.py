#!/usr/bin/env python3
"""
Script to add Trino database connection to Superset
"""
import requests
import json
import time
import os

# Superset configuration
SUPERSET_URL = "http://localhost:8088"
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "admin"

# Trino connection details
TRINO_CONNECTION = {
    "database_name": "trino_hive",
    "sqlalchemy_uri": "trino://trino:8080/hive",
    "cache_timeout": 0,
    "expose_in_sqllab": True,
    "allow_run_async": True,
    "allow_dml": True,
    "allow_ctas": True,
    "allow_cvas": True,
    "allow_file_upload": False,
    "extra": json.dumps({
        "engine_params": {
            "connect_args": {
                "catalog": "hive",
                "schema": "default"
            }
        }
    })
}

def wait_for_superset():
    """Wait for Superset to be ready"""
    print("Waiting for Superset to be ready...")
    max_attempts = 30
    for attempt in range(max_attempts):
        try:
            response = requests.get(f"{SUPERSET_URL}/health", timeout=5)
            if response.status_code == 200:
                print("Superset is ready!")
                return True
        except requests.exceptions.RequestException:
            pass
        
        print(f"Attempt {attempt + 1}/{max_attempts}: Superset not ready yet...")
        time.sleep(2)
    
    print("Superset did not become ready in time")
    return False

def login_to_superset():
    """Login to Superset and get session"""
    print("Logging in to Superset...")
    
    # Get CSRF token
    session = requests.Session()
    response = session.get(f"{SUPERSET_URL}/login/")
    
    # Extract CSRF token from the login page
    csrf_token = None
    if response.status_code == 200:
        # Simple regex to extract CSRF token
        import re
        match = re.search(r'name="csrf_token" value="([^"]+)"', response.text)
        if match:
            csrf_token = match.group(1)
    
    if not csrf_token:
        print("Could not extract CSRF token")
        return None
    
    # Login
    login_data = {
        "username": ADMIN_USERNAME,
        "password": ADMIN_PASSWORD,
        "csrf_token": csrf_token
    }
    
    response = session.post(f"{SUPERSET_URL}/login/", data=login_data)
    
    if response.status_code == 200 and "Invalid login" not in response.text:
        print("Successfully logged in to Superset")
        return session
    else:
        print("Failed to login to Superset")
        return None

def add_database_connection(session):
    """Add Trino database connection to Superset"""
    print("Adding Trino database connection...")
    
    # Get CSRF token for database creation
    response = session.get(f"{SUPERSET_URL}/databaseview/list/")
    csrf_token = None
    if response.status_code == 200:
        import re
        match = re.search(r'name="csrf_token" value="([^"]+)"', response.text)
        if match:
            csrf_token = match.group(1)
    
    if not csrf_token:
        print("Could not extract CSRF token for database creation")
        return False
    
    # Prepare database data
    db_data = {
        "database_name": TRINO_CONNECTION["database_name"],
        "sqlalchemy_uri": TRINO_CONNECTION["sqlalchemy_uri"],
        "cache_timeout": TRINO_CONNECTION["cache_timeout"],
        "expose_in_sqllab": "y" if TRINO_CONNECTION["expose_in_sqllab"] else "n",
        "allow_run_async": "y" if TRINO_CONNECTION["allow_run_async"] else "n",
        "allow_dml": "y" if TRINO_CONNECTION["allow_dml"] else "n",
        "allow_ctas": "y" if TRINO_CONNECTION["allow_ctas"] else "n",
        "allow_cvas": "y" if TRINO_CONNECTION["allow_cvas"] else "n",
        "allow_file_upload": "y" if TRINO_CONNECTION["allow_file_upload"] else "n",
        "extra": TRINO_CONNECTION["extra"],
        "csrf_token": csrf_token
    }
    
    # Add database
    response = session.post(f"{SUPERSET_URL}/databaseview/add", data=db_data)
    
    if response.status_code == 302:  # Redirect indicates success
        print("Successfully added Trino database connection!")
        return True
    else:
        print(f"Failed to add database connection. Status: {response.status_code}")
        print(f"Response: {response.text[:500]}")
        return False

def main():
    """Main function"""
    print("Setting up Trino database connection in Superset...")
    
    # Wait for Superset to be ready
    if not wait_for_superset():
        return False
    
    # Login to Superset
    session = login_to_superset()
    if not session:
        return False
    
    # Add database connection
    success = add_database_connection(session)
    
    if success:
        print("\n✅ Trino database connection has been added to Superset!")
        print("You can now access it in SQL Lab.")
        print(f"Database name: {TRINO_CONNECTION['database_name']}")
        print(f"Connection URI: {TRINO_CONNECTION['sqlalchemy_uri']}")
    else:
        print("\n❌ Failed to add Trino database connection.")
    
    return success

if __name__ == "__main__":
    main() 