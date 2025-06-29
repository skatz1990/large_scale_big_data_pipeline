# Quick Start Guide

Get your Large-Scale Streaming Data Pipeline up and running in minutes!

## Prerequisites

- **Docker & Docker Compose**: Latest version installed
- **System Resources**: 
  - Minimum: 8GB RAM, 4 CPU cores
  - Recommended: 16GB RAM, 8 CPU cores
- **Storage**: At least 100GB available space
- **Network**: Ports 8080, 8081, 8088, 9000, 9001, 9092 available

## Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com/skatz1990/large_scale_big_data_pipeline
cd large_scale_big_data_pipeline

# Make setup script executable
chmod +x scripts/setup_pipeline.sh
```

## Step 2: Start the Pipeline

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps
```

## Step 3: Initialize the Pipeline

```bash
# Run the setup script
./scripts/setup_pipeline.sh
```

This script will:
- Wait for all services to be ready
- Create MinIO buckets
- Set up bucket policies
- Verify connectivity

## Step 4: Access Your Services

### Apache Superset (Visualization)
- **URL**: http://localhost:8088
- **Username**: `admin`
- **Password**: `admin`

### MinIO Console (Storage Management)
- **URL**: http://localhost:9001
- **Username**: `minioadmin`
- **Password**: `minioadmin`

### Kafka UI (Message Queue Monitoring)
- **URL**: http://localhost:8080

### Spark Master (Processing)
- **URL**: http://localhost:8081

## Step 5: Configure Superset

1. **Login to Superset** (http://localhost:8088)
2. **Add Database Connection**:
   - Go to Data → Databases → + Database
   - **Connection String**: `trino://trino:8080/hive/tweets`
   - **Database Name**: `Tweet Analytics`
3. **Import Sample Dashboards** (Optional):
   - Use the dashboard configurations in `config/superset/dashboards.json`

## Step 6: Run SQL Scripts

Connect to Trino and run the setup scripts:

```bash
# Connect to Trino (using any SQL client)
# Host: localhost
# Port: 8080
# Catalog: minio
# Schema: tweets

# Run the scripts in order:
# 1. scripts/create_bronze_table.sql
# 2. scripts/create_silver_table.sql  
# 3. scripts/create_gold_tables.sql
```

## Step 7: Monitor Data Flow

### Check Data Generation
```bash
# View data generator logs
docker-compose logs -f data-generator

# Check Kafka topic
# Visit http://localhost:8080 and navigate to Topics → tweets
```

### Check Data Ingestion
```bash
# View consumer logs
docker-compose logs -f kafka-consumer

# Check MinIO buckets
# Visit http://localhost:9001 and browse buckets
```

### Check Data Processing
```bash
# View Delta processor logs
docker-compose logs -f delta-processor

# Check Spark jobs
# Visit http://localhost:8081
```

## Step 8: Create Your First Dashboard

1. **In Superset**, go to Dashboards → + Dashboard
2. **Add a Chart**:
   - Click + Chart
   - Select your database
   - Choose a visualization type
   - Write a SQL query like:
   ```sql
   SELECT 
       EXTRACT(HOUR FROM created_at) as hour,
       COUNT(*) as tweet_count
   FROM tweets.silver_tweets_view 
   WHERE processing_date = CURRENT_DATE
   GROUP BY EXTRACT(HOUR FROM created_at)
   ORDER BY hour
   ```

## Sample Queries

### Bronze Layer (Raw Data)
```sql
-- Count tweets by date
SELECT date_partition, COUNT(*) as tweet_count 
FROM tweets.bronze_tweets_view 
GROUP BY date_partition 
ORDER BY date_partition DESC;
```

### Silver Layer (Cleaned Data)
```sql
-- Top hashtags
SELECT hashtag, COUNT(*) as usage_count
FROM tweets.silver_tweets_view
CROSS JOIN UNNEST(hashtags) AS t(hashtag)
WHERE processing_date = CURRENT_DATE
GROUP BY hashtag
ORDER BY usage_count DESC
LIMIT 10;
```

### Gold Layer (Aggregated Data)
```sql
-- Trending hashtags
SELECT hashtag, SUM(tweet_count) as total_mentions
FROM tweets.popular_hashtags_view
WHERE hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
GROUP BY hashtag
ORDER BY total_mentions DESC
LIMIT 10;
```

## Troubleshooting

### Common Issues

**Services not starting**:
```bash
# Check Docker resources
docker system df
docker system prune

# Restart services
docker-compose down
docker-compose up -d
```

**Port conflicts**:
```bash
# Check what's using the ports
lsof -i :8080
lsof -i :8088
lsof -i :9000

# Modify ports in docker-compose.yml if needed
```

**Memory issues**:
```bash
# Increase Docker memory limit
# Docker Desktop → Settings → Resources → Memory: 16GB
```

**Data not flowing**:
```bash
# Check service logs
docker-compose logs kafka
docker-compose logs data-generator
docker-compose logs kafka-consumer

# Verify connectivity
docker-compose exec kafka-consumer ping kafka
docker-compose exec kafka-consumer ping minio
```

### Performance Tuning

**Increase throughput**:
```bash
# Modify environment variables in docker-compose.yml
TWEETS_PER_SECOND=2000  # Increase tweet generation rate
```

**Optimize storage**:
```bash
# Adjust Spark configurations in delta-processor/processor.py
# Increase executor memory and cores
```

**Scale services**:
```bash
# Scale specific services
docker-compose up -d --scale kafka-consumer=3
docker-compose up -d --scale spark-worker=2
```

## Next Steps

1. **Explore the Data**: Use Superset to create custom visualizations
2. **Modify the Pipeline**: Customize data generation and processing logic
3. **Add ML Models**: Integrate real-time sentiment analysis
4. **Scale Up**: Deploy to Kubernetes for production use
5. **Monitor**: Set up comprehensive monitoring and alerting

## Support

- **Documentation**: Check `docs/` directory for detailed guides
- **Issues**: Report bugs and feature requests via GitHub issues
- **Community**: Join discussions and share your use cases

## Production Deployment

For production deployment, consider:

1. **Kubernetes**: Use the provided Helm charts
2. **Cloud Storage**: Replace MinIO with S3, GCS, or Azure Blob
3. **Monitoring**: Add Prometheus, Grafana, and ELK stack
4. **Security**: Implement proper authentication and encryption
5. **Backup**: Set up automated backup and disaster recovery

---

🎉 **Congratulations!** Your streaming data pipeline is now running and processing real-time tweet data! 