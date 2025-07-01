# Large-Scale Streaming Data Pipeline with Kafka and Delta Lake

A comprehensive big data application that simulates real-time Twitter activity and processes it through a multi-layered data architecture: Bronze → Silver → Gold.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────┐    ┌─────────────────┐
│   Data Generator│───▶│    Kafka    │───▶│  Kafka Consumer │
│   (Producer)    │    │             │    │  (Bronze Layer) │
└─────────────────┘    └─────────────┘    └─────────────────┘
                                                      │
                                                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Apache        │◀───│  Delta Processor│◀───│  Object Storage │
│   Superset      │    │  (Silver Layer) │    │  (MinIO/S3)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   Gold Layer    │    │   Query Engine  │
│   (Aggregated)  │    │   (Trino/Spark) │
└─────────────────┘    └─────────────────┘
```

## Current Implementation

**Note**: This project currently uses Trino's memory catalog for prototyping and development. The full MinIO integration is planned for future releases.

### Data Layers (Memory-Based)
- **Bronze Layer**: Raw tweet data with full JSON structure
- **Silver Layer**: Cleaned and processed data with derived fields
- **Gold Layer**: Business-level aggregated metrics and KPIs

## Components

1. **Data Generator (Producer)** - Simulates high-throughput tweet stream (1000+/sec)
2. **Kafka Consumer (Bronze Layer)** - Ingests raw JSON data to object storage
3. **Delta Processor (Silver Layer)** - Cleans, validates, and transforms data
4. **Gold Layer** - Business-level aggregated tables
5. **Apache Superset** - Visualization and BI dashboard
6. **Trino Query Engine** - SQL interface for data exploration
7. **Containerized Deployment** - Docker Compose for local deployment

## Quick Start

```bash
# Clone the repository
git clone https://github.com/skatz1990/large_scale_big_data_pipeline
cd large_scale_big_data_pipeline

# Start the entire pipeline
docker-compose up -d

# Wait for services to start, then run the setup script
./scripts/restart_setup.sh
```

## Access Services

- **Superset**: http://localhost:8088 (admin/admin)
- **MinIO Console**: http://localhost:9001 (minioadmin/minioadmin)
- **Kafka UI**: http://localhost:8080
- **Trino**: http://localhost:8080 (for API access)

## Available Scripts

### `scripts/restart_setup.sh`
**Purpose**: Complete setup after Docker restart or fresh installation
**What it does**:
- Waits for Trino and Superset to be ready
- Sets up database connections in Superset
- Creates bronze, silver, and gold layer tables
- Inserts sample data
- Tests the setup

### `scripts/setup_data_layers.sql`
**Purpose**: SQL script that creates the complete data lake architecture
**What it creates**:
- Bronze layer: Raw tweet data table
- Silver layer: Processed tweet data with derived fields
- Gold layer: 5 aggregated business tables
- Views: Enhanced views with business metrics and rankings

## Data Schema

### Bronze Layer (`memory.bronze.tweets`)
Raw tweet data with fields like:
- `tweet_id`, `text`, `created_at`
- `hashtags`, `mentions` (arrays)
- `retweet_count`, `like_count`, `reply_count`, `quote_count`
- User information: `user_id`, `username`, `followers_count`
- Sentiment and engagement metrics

### Silver Layer (`memory.silver.tweets`)
Processed data with additional fields:
- `text_length`: Length of tweet text
- `sentiment_category`: Categorized sentiment (positive/negative/neutral)
- `total_engagement`: Sum of all engagement metrics

### Gold Layer Tables
1. **`popular_hashtags_by_hour`**: Trending hashtags with engagement metrics
2. **`active_users_by_day`**: User activity and influence metrics
3. **`tweet_volume_by_region`**: Geographic activity patterns
4. **`tweet_metrics_by_language`**: Language performance analytics
5. **`hourly_activity_summary`**: Overall platform activity summary

## Sample Queries

### Bronze Layer
```sql
-- Count tweets in bronze layer
SELECT COUNT(*) FROM memory.bronze.tweets;

-- View raw tweet data
SELECT tweet_id, text, created_at, hashtags 
FROM memory.bronze.tweets 
LIMIT 5;
```

### Silver Layer
```sql
-- Analyze sentiment distribution
SELECT sentiment_category, COUNT(*) as count
FROM memory.silver.tweets 
GROUP BY sentiment_category;

-- Top engaging tweets
SELECT tweet_id, text, total_engagement
FROM memory.silver.tweets 
ORDER BY total_engagement DESC 
LIMIT 10;
```

### Gold Layer
```sql
-- Top hashtags by engagement
SELECT hashtag, SUM(total_engagement) as total_engagement
FROM memory.gold.popular_hashtags_by_hour
GROUP BY hashtag
ORDER BY total_engagement DESC;

-- Regional activity
SELECT region, SUM(tweet_count) as total_tweets
FROM memory.gold.tweet_volume_by_region
GROUP BY region
ORDER BY total_tweets DESC;
```

## Troubleshooting

### Authentication Issues
If you encounter authentication errors with Trino:
- The configuration uses insecure authentication for development
- Connection string format: `trino://anonymous@trino:8080/memory/default`
- Configuration is in `config/trino/config.properties`

### After Docker Restart
If you restart Docker, run:
```bash
./scripts/restart_setup.sh
```

### Testing Connections
In Superset SQL Lab:
1. Select the `trino_memory` database
2. Try: `SHOW SCHEMAS`
3. Try: `SELECT COUNT(*) FROM memory.bronze.tweets`

## Business Metrics Available

- **Popular hashtags by hour** with engagement metrics
- **Active users by day** with influence rankings
- **Tweet volume by region** with sentiment analysis
- **Language performance** with engagement averages
- **Hourly activity summaries** with trending topics

## Technologies Used

- **Streaming**: Apache Kafka
- **Storage**: MinIO (S3-compatible)
- **Processing**: Apache Spark, Delta Lake
- **Query Engine**: Trino
- **Visualization**: Apache Superset
- **Containerization**: Docker, Docker Compose

## Future Enhancements

- [ ] Full MinIO integration with Hive metastore
- [ ] Real-time data streaming from Kafka to Trino
- [ ] Delta Lake table format support
- [ ] Advanced analytics and ML integration
- [ ] Production-ready authentication and security

## Roadmap

### Phase 1: Persistent Storage (In Progress)
- [ ] **Hive Metastore Integration**: Complete the Hive Metastore setup with MySQL backend
  - [ ] Fix MySQL JDBC driver loading issues in Hive container
  - [ ] Resolve schema initialization with `-dbType mysql` parameter
  - [ ] Ensure proper environment variable handling in Hive entrypoint
  - [ ] Test persistent table metadata across container restarts
- [ ] **MinIO External Tables**: Create external tables pointing to MinIO buckets
  - [ ] Bronze layer tables on `s3a://tweets-bronze/`
  - [ ] Silver layer tables on `s3a://tweets-silver/`
  - [ ] Gold layer tables on `s3a://tweets-gold/*/`
- [ ] **Automated Setup**: Create comprehensive setup script for MinIO-based pipeline

### Phase 2: Production Readiness
- [ ] **Authentication & Security**: Implement proper authentication for all services
- [ ] **Monitoring & Logging**: Add comprehensive monitoring and centralized logging
- [ ] **Performance Optimization**: Optimize query performance and resource usage
- [ ] **Backup & Recovery**: Implement data backup and disaster recovery procedures

### Phase 3: Advanced Features
- [ ] **Real-time Processing**: Implement real-time data streaming from Kafka to Trino
- [ ] **ML Integration**: Add machine learning capabilities for predictive analytics
- [ ] **Advanced Analytics**: Implement complex business intelligence dashboards
- [ ] **Multi-tenancy**: Support for multiple data sources and tenants