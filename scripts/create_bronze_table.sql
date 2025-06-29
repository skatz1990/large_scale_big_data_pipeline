-- Bronze Layer: External table for raw JSON tweet data
-- This table provides access to raw tweet data stored in MinIO

-- Create catalog for MinIO if not exists
CREATE CATALOG IF NOT EXISTS minio
WITH (
    type = 'hive',
    hive.metastore.uri = 'thrift://localhost:9083',
    hive.s3.endpoint = 'http://localhost:9000',
    hive.s3.aws-access-key = 'minioadmin',
    hive.s3.aws-secret-key = 'minioadmin',
    hive.s3.path-style-access = true
);

-- Use the minio catalog
USE CATALOG minio;

-- Create schema for tweet data
CREATE SCHEMA IF NOT EXISTS tweets;

-- Create Bronze table (external table on raw JSON data)
CREATE TABLE IF NOT EXISTS tweets.bronze_tweets (
    tweet_id VARCHAR,
    text VARCHAR,
    created_at TIMESTAMP,
    tweet_type VARCHAR,
    language VARCHAR,
    region VARCHAR,
    hashtags ARRAY(VARCHAR),
    mentions ARRAY(VARCHAR),
    retweet_count BIGINT,
    like_count BIGINT,
    reply_count BIGINT,
    quote_count BIGINT,
    is_retweet BOOLEAN,
    is_reply BOOLEAN,
    is_quote BOOLEAN,
    has_media BOOLEAN,
    has_url BOOLEAN,
    sentiment_score DOUBLE,
    engagement_score INTEGER,
    reach_estimate BIGINT,
    user ROW(
        user_id VARCHAR,
        username VARCHAR,
        display_name VARCHAR,
        followers_count BIGINT,
        following_count BIGINT,
        verified BOOLEAN,
        created_at VARCHAR,
        location VARCHAR,
        description VARCHAR
    ),
    original_tweet_id VARCHAR,
    original_user ROW(
        user_id VARCHAR,
        username VARCHAR,
        display_name VARCHAR,
        followers_count BIGINT,
        following_count BIGINT,
        verified BOOLEAN,
        created_at VARCHAR,
        location VARCHAR,
        description VARCHAR
    ),
    reply_to_tweet_id VARCHAR,
    reply_to_user ROW(
        user_id VARCHAR,
        username VARCHAR,
        display_name VARCHAR,
        followers_count BIGINT,
        following_count BIGINT,
        verified BOOLEAN,
        created_at VARCHAR,
        location VARCHAR,
        description VARCHAR
    ),
    quoted_tweet_id VARCHAR,
    quoted_user ROW(
        user_id VARCHAR,
        username VARCHAR,
        display_name VARCHAR,
        followers_count BIGINT,
        following_count BIGINT,
        verified BOOLEAN,
        created_at VARCHAR,
        location VARCHAR,
        description VARCHAR
    ),
    quoted_text VARCHAR
)
WITH (
    format = 'JSON',
    external_location = 's3a://tweets-bronze/',
    partitioned_by = ARRAY['date', 'hour']
);

-- Create view for easier querying of Bronze data
CREATE OR REPLACE VIEW tweets.bronze_tweets_view AS
SELECT 
    tweet_id,
    text,
    created_at,
    tweet_type,
    language,
    region,
    hashtags,
    mentions,
    retweet_count,
    like_count,
    reply_count,
    quote_count,
    is_retweet,
    is_reply,
    is_quote,
    has_media,
    has_url,
    sentiment_score,
    engagement_score,
    reach_estimate,
    user.user_id as user_id,
    user.username as username,
    user.display_name as display_name,
    user.followers_count as followers_count,
    user.following_count as following_count,
    user.verified as verified,
    user.location as user_location,
    user.description as user_description,
    original_tweet_id,
    original_user.user_id as original_user_id,
    reply_to_tweet_id,
    reply_to_user.user_id as reply_to_user_id,
    quoted_tweet_id,
    quoted_user.user_id as quoted_user_id,
    quoted_text,
    date_partition,
    hour_partition
FROM tweets.bronze_tweets;

-- Sample queries for Bronze layer:

-- 1. Count tweets by date
-- SELECT date_partition, COUNT(*) as tweet_count 
-- FROM tweets.bronze_tweets_view 
-- GROUP BY date_partition 
-- ORDER BY date_partition DESC;

-- 2. Top hashtags
-- SELECT hashtag, COUNT(*) as usage_count
-- FROM tweets.bronze_tweets_view
-- CROSS JOIN UNNEST(hashtags) AS t(hashtag)
-- GROUP BY hashtag
-- ORDER BY usage_count DESC
-- LIMIT 10;

-- 3. Tweet volume by hour
-- SELECT hour_partition, COUNT(*) as tweet_count
-- FROM tweets.bronze_tweets_view
-- WHERE date_partition = '2024-01-15'
-- GROUP BY hour_partition
-- ORDER BY hour_partition;

-- 4. User activity
-- SELECT username, COUNT(*) as tweet_count
-- FROM tweets.bronze_tweets_view
-- GROUP BY username
-- ORDER BY tweet_count DESC
-- LIMIT 20; 