#!/bin/bash

# Script to restart and set up the data lake after Docker restarts
echo "🚀 Setting up data lake after Docker restart..."

# Wait for Trino to be ready
echo "⏳ Waiting for Trino to be ready..."
until curl -s http://localhost:8080/v1/info > /dev/null; do
    echo "Trino not ready yet, waiting..."
    sleep 5
done
echo "✅ Trino is ready!"

# Wait for Superset to be ready
echo "⏳ Waiting for Superset to be ready..."
until curl -s http://localhost:8088/health > /dev/null; do
    echo "Superset not ready yet, waiting..."
    sleep 5
done
echo "✅ Superset is ready!"

# Set up database connections in Superset
echo "🔗 Setting up database connections in Superset..."
docker exec -it superset superset set-database-uri -d "trino_memory" -u "trino://anonymous@trino:8080/memory/default"

# Create tables and sample data
echo "📊 Creating bronze, silver, and gold layer tables..."
docker exec -i trino trino --server trino:8080 --catalog memory --schema default < scripts/setup_data_layers.sql

# Test the setup
echo "🧪 Testing the setup..."
docker exec -it trino trino --server trino:8080 --catalog memory --schema bronze --execute "SELECT COUNT(*) as bronze_tweets FROM tweets"
docker exec -it trino trino --server trino:8080 --catalog memory --schema silver --execute "SELECT COUNT(*) as silver_tweets FROM tweets"
docker exec -it trino trino --server trino:8080 --catalog memory --schema gold --execute "SELECT COUNT(*) as gold_hashtags FROM popular_hashtags_by_hour"

echo "🎉 Setup complete! You can now access:"
echo "   - Superset: http://localhost:8088 (admin/admin)"
echo "   - Use the 'trino_memory' database in SQL Lab"
echo "   - Available schemas: bronze, silver, gold" 