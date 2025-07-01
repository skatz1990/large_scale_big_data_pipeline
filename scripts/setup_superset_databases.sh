#!/bin/bash

# Script to set up database connections in Superset
echo "Setting up database connections in Superset..."

# Wait for Superset to be ready
echo "Waiting for Superset to be ready..."
until curl -s http://localhost:8088/health > /dev/null; do
    echo "Superset not ready yet, waiting..."
    sleep 5
done
echo "Superset is ready!"

# Wait for Trino to be ready
echo "Waiting for Trino to be ready..."
until curl -s http://localhost:8080/v1/info > /dev/null; do
    echo "Trino not ready yet, waiting..."
    sleep 5
done
echo "Trino is ready!"

# Add Trino memory catalog connection
echo "Adding Trino memory catalog connection..."
docker exec -it superset superset set-database-uri -d "trino_memory" -u "trino://anonymous@trino:8080/memory/default"

# Add Trino hive catalog connection (if metastore is available)
echo "Adding Trino hive catalog connection..."
docker exec -it superset superset set-database-uri -d "trino_hive" -u "trino://anonymous@trino:8080/hive/default"

echo "Database connections have been set up!"
echo ""
echo "Available databases in Superset:"
echo "- trino_memory: In-memory database for testing"
echo "- trino_hive: Hive catalog (requires metastore)"
echo ""
echo "You can now access these databases in Superset SQL Lab."
echo ""
echo "Test queries you can try:"
echo "- SHOW TABLES"
echo "- SELECT * FROM test_table2" 