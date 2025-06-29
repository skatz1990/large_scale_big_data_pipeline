#!/bin/bash

# Setup script for Large-Scale Streaming Data Pipeline
# This script initializes MinIO buckets and runs SQL setup scripts

set -e

echo "🚀 Setting up Large-Scale Streaming Data Pipeline..."

# Wait for MinIO to be ready
echo "⏳ Waiting for MinIO to be ready..."
until curl -s http://localhost:9000/minio/health/live > /dev/null; do
    echo "Waiting for MinIO..."
    sleep 5
done

# Install MinIO client
echo "📦 Installing MinIO client..."
if ! command -v mc &> /dev/null; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget https://dl.min.io/client/mc/release/linux-amd64/mc
        chmod +x mc
        sudo mv mc /usr/local/bin/
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install minio/stable/mc
    fi
fi

# Configure MinIO client
echo "🔧 Configuring MinIO client..."
mc alias set local http://localhost:9000 minioadmin minioadmin

# Create buckets
echo "🪣 Creating MinIO buckets..."
mc mb local/tweets-bronze --ignore-existing
mc mb local/tweets-silver --ignore-existing
mc mb local/tweets-gold --ignore-existing

# Set bucket policies for public read (for development)
echo "📋 Setting bucket policies..."
mc policy set download local/tweets-bronze
mc policy set download local/tweets-silver
mc policy set download local/tweets-gold

echo "✅ MinIO setup completed!"

# Wait for Trino to be ready
echo "⏳ Waiting for Trino to be ready..."
until curl -s http://localhost:8080/v1/info > /dev/null; do
    echo "Waiting for Trino..."
    sleep 10
done

echo "✅ Trino is ready!"

# Wait for Superset to be ready
echo "⏳ Waiting for Superset to be ready..."
until curl -s http://localhost:8088/health > /dev/null; do
    echo "Waiting for Superset..."
    sleep 10
done

echo "✅ Superset is ready!"

echo "🎉 Pipeline setup completed successfully!"
echo ""
echo "📊 Access your services:"
echo "   - Superset: http://localhost:8088 (admin/admin)"
echo "   - MinIO Console: http://localhost:9001 (minioadmin/minioadmin)"
echo "   - Kafka UI: http://localhost:8080"
echo "   - Trino: http://localhost:8080"
echo ""
echo "📝 Next steps:"
echo "   1. Access Superset and add Trino as a database connection"
echo "   2. Run the SQL scripts in the scripts/ directory"
echo "   3. Create dashboards and visualizations"
echo ""
echo "🔗 Trino connection string for Superset:"
echo "   trino://trino:8080/hive/tweets" 