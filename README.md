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

## Components

1. **Data Generator (Producer)** - Simulates high-throughput tweet stream (1000+/sec)
2. **Kafka Consumer (Bronze Layer)** - Ingests raw JSON data to object storage
3. **Delta Processor (Silver Layer)** - Cleans, validates, and transforms data
4. **Gold Layer** - Business-level aggregated tables
5. **Apache Superset** - Visualization and BI dashboard
6. **Containerized Deployment** - Docker Compose for local deployment

## Quick Start

```bash
# Clone the repository
git clone https://github.com/skatz1990/large_scale_big_data_pipeline
cd large_scale_big_data_pipeline

# Start the entire pipeline
docker-compose up -d

# Access services:
# - Superset: http://localhost:8088 (admin/admin)
# - MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
# - Kafka UI: http://localhost:8080
# - Trino: http://localhost:8080 (for API access)
```

## Data Flow

1. **Bronze Layer**: Raw JSON tweets stored in MinIO, partitioned by date
2. **Silver Layer**: Cleaned, validated Delta Lake tables
3. **Gold Layer**: Aggregated business metrics tables

## Business Metrics

- Popular hashtags by hour
- Active users by day
- Tweet volume by region
- Average tweet length by language

## Technologies Used

- **Streaming**: Apache Kafka
- **Storage**: MinIO (S3-compatible)
- **Processing**: Apache Spark, Delta Lake
- **Query Engine**: Trino
- **Visualization**: Apache Superset
- **Containerization**: Docker, Docker Compose