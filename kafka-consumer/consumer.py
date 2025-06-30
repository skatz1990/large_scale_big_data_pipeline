#!/usr/bin/env python3
"""
Kafka Consumer (Bronze Layer) for Large-Scale Streaming Data Pipeline
Consumes tweets from Kafka and stores them in MinIO object storage
"""

import json
import os
import time
from datetime import datetime
from typing import Dict, Any
import logging
from io import BytesIO

from kafka import KafkaConsumer
from minio import Minio
from minio.error import S3Error

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class MinIOStorage:
    """Handles storage operations with MinIO"""

    def __init__(self, endpoint: str, access_key: str, secret_key: str, bucket: str):
        self.client = Minio(
            endpoint,
            access_key=access_key,
            secret_key=secret_key,
            secure=False,  # Set to True for HTTPS
        )
        self.bucket = bucket
        self.ensure_bucket_exists()

    def ensure_bucket_exists(self):
        """Ensure the bucket exists, create if it doesn't"""
        try:
            if not self.client.bucket_exists(self.bucket):
                self.client.make_bucket(self.bucket)
                logger.info("Created bucket: %s", self.bucket)
            else:
                logger.info("Bucket %s already exists", self.bucket)
        except S3Error as e:
            logger.error("Error creating bucket %s: %s", self.bucket, e)
            raise

    def store_tweet(self, tweet: Dict[str, Any], partition_date: str) -> str:
        """Store a tweet in MinIO with date partitioning"""
        try:
            # Create object key with date partitioning
            tweet_id = tweet.get("tweet_id", str(int(time.time() * 1000)))
            timestamp = datetime.now().strftime("%H%M%S")
            object_key = f"date={partition_date}/hour={datetime.now().strftime('%H')}/tweet_{tweet_id}_{timestamp}.json"

            # Convert tweet to JSON string
            tweet_json = json.dumps(tweet, ensure_ascii=False)

            # Upload to MinIO
            self.client.put_object(
                self.bucket,
                object_key,
                data=BytesIO(tweet_json.encode("utf-8")),
                length=len(tweet_json.encode("utf-8")),
                content_type="application/json",
            )
            
            logger.debug("Stored tweet %s to %s", tweet_id, object_key)
            return object_key
        except S3Error as e:
            logger.error("Error storing tweet %s: %s", tweet.get('tweet_id', 'unknown'), e)
            raise


class KafkaTweetConsumer:
    """Kafka consumer for tweet data"""

    def __init__(self, bootstrap_servers: str, topic: str, group_id: str):
        self.consumer = KafkaConsumer(
            topic,
            bootstrap_servers=bootstrap_servers,
            group_id=group_id,
            auto_offset_reset="earliest",
            enable_auto_commit=True,
            auto_commit_interval_ms=1000,
            value_deserializer=lambda x: json.loads(x.decode("utf-8")) if x else None,
            key_deserializer=lambda x: x.decode("utf-8") if x else None,
            max_poll_records=500,
            fetch_max_wait_ms=500,
            fetch_min_bytes=1,
            fetch_max_bytes=52428800,  # 50MB
        )
        self.topic = topic
        logger.info("Initialized Kafka consumer for topic: %s", topic)

    def process_message(self, message, storage: MinIOStorage) -> None:
        """Process a single Kafka message"""
        try:
            # Validate message value
            if not message.value:
                logger.warning("Received empty message, skipping")
                return

            tweet = message.value
            if not isinstance(tweet, dict):
                logger.error("Invalid message format, expected dict, got %s", type(tweet))
                return

            tweet_id = tweet.get("tweet_id", "unknown")

            # Extract date for partitioning
            created_at = tweet.get("created_at", datetime.now().isoformat())
            if isinstance(created_at, str):
                try:
                    dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                    partition_date = dt.strftime("%Y-%m-%d")
                except ValueError:
                    partition_date = datetime.now().strftime("%Y-%m-%d")
            else:
                partition_date = datetime.now().strftime("%Y-%m-%d")

            # Store in MinIO
            object_key = storage.store_tweet(tweet, partition_date)
            logger.info("Processed tweet %s -> %s", tweet_id, object_key)
        except Exception as e:
            logger.error("Error processing message: %s", e)
            # Continue processing other messages

    def run(self, storage: MinIOStorage) -> None:
        """Run the consumer loop"""
        logger.info("Starting Kafka consumer...")

        try:
            for message in self.consumer:
                self.process_message(message, storage)

        except KeyboardInterrupt:
            logger.info("Stopping consumer...")
        except Exception as e:
            logger.error("Consumer error: %s", e)
        finally:
            self.consumer.close()


def main():
    """Main function"""
    # Get configuration from environment
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    topic = os.getenv("TOPIC_NAME", "tweets")
    group_id = os.getenv("KAFKA_GROUP_ID", "tweet-consumer-group")

    # MinIO configuration
    minio_endpoint = os.getenv("MINIO_ENDPOINT", "localhost:9000")
    minio_access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
    minio_secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
    minio_bucket = os.getenv("MINIO_BUCKET", "tweets-bronze")

    logger.info("Connecting to Kafka at %s", bootstrap_servers)
    logger.info("Consuming from topic: %s", topic)
    logger.info("Storing to MinIO bucket: %s", minio_bucket)

    # Initialize storage and consumer
    storage = MinIOStorage(
        minio_endpoint, minio_access_key, minio_secret_key, minio_bucket
    )
    consumer = KafkaTweetConsumer(bootstrap_servers, topic, group_id)

    # Start consuming
    consumer.run(storage)


if __name__ == "__main__":
    main()
