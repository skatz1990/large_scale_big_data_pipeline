#!/bin/bash

# Wait for database to be ready
sleep 5

# Initialize the database
superset db upgrade

# Create admin user
superset fab create-admin \
    --username admin \
    --firstname Superset \
    --lastname Admin \
    --email admin@superset.com \
    --password admin

# Initialize Superset
superset init

# Start Superset
superset run -p 8088 --host 0.0.0.0 