#!/usr/bin/env python3
"""
Delta Processor (Silver Layer) for Large-Scale Streaming Data Pipeline
Transforms Bronze layer JSON data into Silver layer Delta Lake tables
"""

import os
import sys
from datetime import datetime
import logging
import traceback

from pyspark.sql import DataFrame, SparkSession

from pyspark.sql.functions import (
    avg,
    col,
    count,
    countDistinct,
    current_date,
    current_timestamp,
    date_trunc,
    length,
    explode,
    max,
)

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class DeltaProcessor:
    """Handles Delta Lake processing for Silver layer"""

    def __init__(
        self,
        spark_master: str,
        minio_endpoint: str,
        minio_access_key: str,
        minio_secret_key: str,
    ):
        self.spark_master = spark_master
        self.minio_endpoint = minio_endpoint
        self.minio_access_key = minio_access_key
        self.minio_secret_key = minio_secret_key

        # Initialize Spark session with Delta Lake support
        self.spark = self._create_spark_session()

    def _create_spark_session(self) -> SparkSession:
        """Create Spark session with Delta Lake and MinIO support"""
        logger.info("Creating Spark session with MinIO endpoint: %s", self.minio_endpoint)

        return (
            SparkSession.builder.appName("TweetDeltaProcessor")  # type: ignore
            .master(self.spark_master)
            .config(
                "spark.jars.packages",
                "io.delta:delta-core_2.12:2.4.0,"
                + "org.apache.hadoop:hadoop-aws:3.3.4",
            )
            .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
            .config(
                "spark.sql.catalog.spark_catalog",
                "org.apache.spark.sql.delta.catalog.DeltaCatalog",
            )
            .config("spark.hadoop.fs.s3a.endpoint", self.minio_endpoint)
            .config("spark.hadoop.fs.s3a.access.key", self.minio_access_key)
            .config("spark.hadoop.fs.s3a.secret.key", self.minio_secret_key)
            .config("spark.hadoop.fs.s3a.path.style.access", "true")
            .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
            .config(
                "spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem"
            )
            .config(
                "spark.hadoop.fs.s3a.aws.credentials.provider",
                "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider",
            )
            .config("spark.hadoop.fs.s3a.connection.timeout", "30000")  # 30 seconds
            .config("spark.hadoop.fs.s3a.connection.ttl", "3600000")  # 1 hour
            .config("spark.hadoop.fs.s3a.connection.max", "20")
            .config("spark.hadoop.fs.s3a.threads.max", "20")
            .config("spark.hadoop.fs.s3a.threads.core", "10")
            .config("spark.hadoop.fs.s3a.max.total.tasks", "5")
            .config("spark.hadoop.fs.s3a.experimental.input.fadvise", "normal")
            .config("spark.hadoop.fs.s3a.buffer.dir", "/tmp")
            .config("spark.hadoop.fs.s3a.block.size", "134217728")  # 128MB
            .config("spark.hadoop.fs.s3a.multipart.size", "134217728")  # 128MB
            .config("spark.hadoop.fs.s3a.multipart.threshold", "134217728")  # 128MB
            .config("spark.sql.adaptive.enabled", "true")
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
            .config("spark.sql.adaptive.skewJoin.enabled", "true")
            .getOrCreate()
        )

    def read_bronze_data(
        self, bronze_bucket: str, date_partition: str = ""
    ) -> "DataFrame":
        """Read data from Bronze layer"""
        try:
            # Construct S3 path
            s3_path = f"s3a://{bronze_bucket}"
            if date_partition:
                s3_path += f"/date={date_partition}"

            logger.info("Reading Bronze data from: %s", s3_path)

            df = (
                self.spark.read.option("multiline", "true")
                .option("mode", "PERMISSIVE")
                .option("timestampFormat", "yyyy-MM-dd HH:mm:ss")
                .option("dateFormat", "yyyy-MM-dd")
                .option("inferSchema", "true")
                .json(s3_path)
            )

            logger.info("JSON read operation completed, counting records...")
            record_count = df.count()
            logger.info("Read %d records from Bronze layer", record_count)
            return df

        except Exception as e:
            logger.error("Error reading Bronze data: %s", e)
            logger.error("Exception type: %s", type(e).__name__)
            logger.error("Full traceback: %s", traceback.format_exc())
            raise

    def clean_and_transform_data(self, df: "DataFrame") -> "DataFrame":
        """Clean and transform the data for Silver layer"""
        try:
            # Select and rename columns for better structure
            cleaned_df = df.select(
                col("tweet_id").cast("string"),
                col("text").cast("string"),
                col("created_at").cast("timestamp"),
                col("tweet_type").cast("string"),
                col("language").cast("string"),
                col("region").cast("string"),
                col("hashtags"),
                col("mentions"),
                col("retweet_count").cast("long"),
                col("like_count").cast("long"),
                col("reply_count").cast("long"),
                col("quote_count").cast("long"),
                col("is_retweet").cast("boolean"),
                col("is_reply").cast("boolean"),
                col("is_quote").cast("boolean"),
                col("has_media").cast("boolean"),
                col("has_url").cast("boolean"),
                col("sentiment_score").cast("double"),
                col("engagement_score").cast("integer"),
                col("reach_estimate").cast("long"),
                # User information
                col("user.user_id").cast("string").alias("user_id"),
                col("user.username").cast("string").alias("username"),
                col("user.display_name").cast("string").alias("display_name"),
                col("user.followers_count").cast("long").alias("followers_count"),
                col("user.following_count").cast("long").alias("following_count"),
                col("user.verified").cast("boolean").alias("verified"),
                col("user.location").cast("string").alias("user_location"),
                col("user.description").cast("string").alias("user_description"),
                # Additional fields for retweets/replies/quotes
                col("original_tweet_id").cast("string"),
                col("original_user.user_id").cast("string").alias("original_user_id"),
                col("reply_to_tweet_id").cast("string"),
                col("reply_to_user.user_id").cast("string").alias("reply_to_user_id"),
                col("quoted_tweet_id").cast("string"),
                col("quoted_user.user_id").cast("string").alias("quoted_user_id"),
                col("quoted_text").cast("string"),
            )

            # Add processing metadata
            cleaned_df = cleaned_df.withColumn(
                "processed_at", current_timestamp()
            ).withColumn("processing_date", current_date())

            # Filter out invalid records
            cleaned_df = cleaned_df.filter(
                col("tweet_id").isNotNull()
                & col("text").isNotNull()
                & col("created_at").isNotNull()
            )

            # Remove duplicates based on tweet_id
            cleaned_df = cleaned_df.dropDuplicates(["tweet_id"])

            logger.info("Cleaned data: %d records", cleaned_df.count())
            return cleaned_df

        except Exception as e:
            logger.error("Error cleaning data: %s", e)
            raise

    def write_silver_table(self, df: "DataFrame", silver_bucket: str) -> None:
        """Write cleaned data to Silver layer as Delta table"""
        try:
            silver_path = f"s3a://{silver_bucket}/tweets_silver"

            logger.info("Writing Silver table to: %s", silver_path)

            # Write as Delta table with partitioning
            df.write.format("delta").mode("append").partitionBy(
                "processing_date"
            ).option("mergeSchema", "true").save(silver_path)

            logger.info("Successfully wrote Silver table to %s", silver_path)

        except Exception as e:
            logger.error("Error writing Silver table: %s", e)
            raise

    def create_gold_tables(self, silver_bucket: str, gold_bucket: str) -> None:
        """Create Gold layer aggregated tables"""
        try:
            silver_path = f"s3a://{silver_bucket}/tweets_silver"

            # Read Silver table
            silver_df = self.spark.read.format("delta").load(silver_path)

            # Create Gold tables
            self._create_popular_hashtags_table(silver_df, gold_bucket)
            self._create_active_users_table(silver_df, gold_bucket)
            self._create_tweet_volume_table(silver_df, gold_bucket)
            self._create_tweet_metrics_table(silver_df, gold_bucket)

        except Exception as e:
            logger.error("Error creating Gold tables: %s", e)
            raise

    def _create_popular_hashtags_table(self, df: "DataFrame", gold_bucket: str) -> None:
        """Create popular hashtags by hour table"""
        try:
            # Explode hashtags and aggregate
            hashtags_df = df.select(
                col("created_at"),
                col("hashtags"),
                date_trunc("hour", col("created_at")).alias("hour"),
            ).filter(col("hashtags").isNotNull())

            # Explode hashtags array
            hashtags_exploded = hashtags_df.select(
                col("hour"), explode(col("hashtags")).alias("hashtag")
            )

            # Aggregate by hour and hashtag
            popular_hashtags = (
                hashtags_exploded.groupBy("hour", "hashtag")
                .agg(
                    count("*").alias("tweet_count"),
                    countDistinct("hashtag").alias("unique_mentions"),
                )
                .orderBy("hour", col("tweet_count").desc())
            )

            # Write to Gold layer
            gold_path = f"s3a://{gold_bucket}/popular_hashtags_by_hour"
            popular_hashtags.write.format("delta").mode("overwrite").partitionBy(
                "hour"
            ).save(gold_path)

            logger.info("Created popular hashtags table: %s", gold_path)

        except Exception as e:
            logger.error("Error creating popular hashtags table: %s", e)
            raise

    def _create_active_users_table(self, df: "DataFrame", gold_bucket: str) -> None:
        """Create active users by day table"""
        try:
            active_users = (
                df.select(
                    col("user_id"),
                    col("username"),
                    col("followers_count"),
                    date_trunc("day", col("created_at")).alias("day"),
                )
                .groupBy("day", "user_id", "username")
                .agg(
                    count("*").alias("tweets_count"),
                    max("followers_count").alias("followers_count"),
                )
                .orderBy("day", col("tweets_count").desc())
            )

            # Write to Gold layer
            gold_path = f"s3a://{gold_bucket}/active_users_by_day"
            active_users.write.format("delta").mode("overwrite").partitionBy(
                "day"
            ).save(gold_path)

            logger.info("Created active users table: %s", gold_path)

        except Exception as e:
            logger.error("Error creating active users table: %s", e)
            raise

    def _create_tweet_volume_table(self, df: "DataFrame", gold_bucket: str) -> None:
        """Create tweet volume by region table"""
        try:
            tweet_volume = (
                df.select(
                    col("region"),
                    col("language"),
                    date_trunc("hour", col("created_at")).alias("hour"),
                )
                .groupBy("hour", "region", "language")
                .agg(
                    count("*").alias("tweet_count"),
                    countDistinct("region").alias("unique_regions"),
                )
                .orderBy("hour", col("tweet_count").desc())
            )

            # Write to Gold layer
            gold_path = f"s3a://{gold_bucket}/tweet_volume_by_region"
            tweet_volume.write.format("delta").mode("overwrite").partitionBy(
                "hour"
            ).save(gold_path)

            logger.info("Created tweet volume table: %s", gold_path)

        except Exception as e:
            logger.error("Error creating tweet volume table: %s", e)
            raise

    def _create_tweet_metrics_table(self, df: "DataFrame", gold_bucket: str) -> None:
        """Create average tweet length by language table"""
        try:
            tweet_metrics = (
                df.select(
                    col("language"),
                    col("text"),
                    col("sentiment_score"),
                    col("engagement_score"),
                    date_trunc("hour", col("created_at")).alias("hour"),
                )
                .groupBy("hour", "language")
                .agg(
                    count("*").alias("tweet_count"),
                    avg(length(col("text"))).alias("avg_tweet_length"),
                    avg("sentiment_score").alias("avg_sentiment"),
                    avg("engagement_score").alias("avg_engagement"),
                )
                .orderBy("hour", col("tweet_count").desc())
            )

            # Write to Gold layer
            gold_path = f"s3a://{gold_bucket}/tweet_metrics_by_language"
            tweet_metrics.write.format("delta").mode("overwrite").partitionBy(
                "hour"
            ).save(gold_path)

            logger.info("Created tweet metrics table: %s", gold_path)

        except Exception as e:
            logger.error("Error creating tweet metrics table: %s", e)
            raise

    def process_daily_data(
        self,
        bronze_bucket: str,
        silver_bucket: str,
        gold_bucket: str,
        date_partition: str = "",
    ) -> None:
        """Process data for a specific date partition"""
        try:
            logger.info("Starting daily processing for date: %s", date_partition)

            # Read Bronze data
            bronze_df = self.read_bronze_data(bronze_bucket, date_partition)

            if bronze_df.count() == 0:
                logger.info("No data to process for this date")
                return

            logger.info("Bronze data read successfully")

            # Clean and transform
            silver_df = self.clean_and_transform_data(bronze_df)

            logger.info("Silver data cleaned and transformed successfully")

            # Write Silver table
            self.write_silver_table(silver_df, silver_bucket)

            # Create Gold tables
            self.create_gold_tables(silver_bucket, gold_bucket)

            logger.info("Completed processing for date: %s", date_partition)

        except Exception as e:
            logger.error("Error in daily processing: %s", e)
            raise

    def close(self):
        """Close Spark session"""
        if self.spark:
            self.spark.stop()


def main():
    """Main function"""
    # Get configuration from environment
    spark_master = os.getenv("SPARK_MASTER", "local[*]")
    minio_endpoint = os.getenv("MINIO_ENDPOINT", "localhost:9000")
    minio_access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
    minio_secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
    bronze_bucket = os.getenv("BRONZE_BUCKET", "tweets-bronze")
    silver_bucket = os.getenv("SILVER_BUCKET", "tweets-silver")
    gold_bucket = os.getenv("GOLD_BUCKET", "tweets-gold")

    logger.info("Initializing Delta Processor...")
    logger.info(f"Spark Master: {spark_master}")
    logger.info(f"Bronze Bucket: {bronze_bucket}")
    logger.info(f"Silver Bucket: {silver_bucket}")
    logger.info(f"Gold Bucket: {gold_bucket}")

    processor = None
    try:
        # Initialize processor
        processor = DeltaProcessor(
            spark_master, minio_endpoint, minio_access_key, minio_secret_key
        )

        # Process today's data
        today = datetime.now().strftime("%Y-%m-%d")
        processor.process_daily_data(bronze_bucket, silver_bucket, gold_bucket, today)

        logger.info("Delta processing completed successfully")

    except Exception as e:
        logger.error(f"Delta processing failed: {e}")
        sys.exit(1)
    finally:
        if processor:
            processor.close()


if __name__ == "__main__":
    main()
