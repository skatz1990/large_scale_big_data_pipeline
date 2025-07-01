-- Setup script for Bronze, Silver, and Gold layer tables
-- This script creates the data lake architecture in Trino memory catalog

-- Create schemas for different data layers
CREATE SCHEMA IF NOT EXISTS memory.bronze;
CREATE SCHEMA IF NOT EXISTS memory.silver;
CREATE SCHEMA IF NOT EXISTS memory.gold;

-- ============================================================================
-- BRONZE LAYER: Raw data tables
-- ============================================================================

-- Bronze tweets table (raw JSON data structure)
CREATE TABLE IF NOT EXISTS memory.bronze.tweets (
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
    user_id VARCHAR,
    username VARCHAR,
    display_name VARCHAR,
    followers_count BIGINT,
    following_count BIGINT,
    verified BOOLEAN,
    user_location VARCHAR,
    user_description VARCHAR,
    original_tweet_id VARCHAR,
    original_user_id VARCHAR,
    reply_to_tweet_id VARCHAR,
    reply_to_user_id VARCHAR,
    quoted_tweet_id VARCHAR,
    quoted_user_id VARCHAR,
    quoted_text VARCHAR,
    ingested_at TIMESTAMP,
    partition_date DATE
);

-- ============================================================================
-- SILVER LAYER: Cleaned and processed data
-- ============================================================================

-- Silver tweets table (cleaned and structured data)
CREATE TABLE IF NOT EXISTS memory.silver.tweets (
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
    user_id VARCHAR,
    username VARCHAR,
    display_name VARCHAR,
    followers_count BIGINT,
    following_count BIGINT,
    verified BOOLEAN,
    user_location VARCHAR,
    user_description VARCHAR,
    original_tweet_id VARCHAR,
    original_user_id VARCHAR,
    reply_to_tweet_id VARCHAR,
    reply_to_user_id VARCHAR,
    quoted_tweet_id VARCHAR,
    quoted_user_id VARCHAR,
    quoted_text VARCHAR,
    -- Derived fields for analytics
    text_length INTEGER,
    sentiment_category VARCHAR,
    total_engagement BIGINT,
    processed_at TIMESTAMP,
    processing_date DATE
);

-- ============================================================================
-- GOLD LAYER: Business-level aggregated tables
-- ============================================================================

-- 1. Popular Hashtags by Hour
CREATE TABLE IF NOT EXISTS memory.gold.popular_hashtags_by_hour (
    hour TIMESTAMP,
    hashtag VARCHAR,
    tweet_count BIGINT,
    unique_mentions BIGINT,
    avg_sentiment DOUBLE,
    total_engagement BIGINT
);

-- 2. Active Users by Day
CREATE TABLE IF NOT EXISTS memory.gold.active_users_by_day (
    day DATE,
    user_id VARCHAR,
    username VARCHAR,
    tweets_count BIGINT,
    followers_count BIGINT,
    total_engagement BIGINT,
    avg_sentiment DOUBLE
);

-- 3. Tweet Volume by Region
CREATE TABLE IF NOT EXISTS memory.gold.tweet_volume_by_region (
    hour TIMESTAMP,
    region VARCHAR,
    language VARCHAR,
    tweet_count BIGINT,
    unique_users BIGINT,
    avg_sentiment DOUBLE
);

-- 4. Tweet Metrics by Language
CREATE TABLE IF NOT EXISTS memory.gold.tweet_metrics_by_language (
    hour TIMESTAMP,
    language VARCHAR,
    tweet_count BIGINT,
    avg_tweet_length DOUBLE,
    avg_sentiment DOUBLE,
    avg_engagement DOUBLE,
    unique_users BIGINT
);

-- 5. Hourly Activity Summary
CREATE TABLE IF NOT EXISTS memory.gold.hourly_activity_summary (
    hour TIMESTAMP,
    total_tweets BIGINT,
    unique_users BIGINT,
    avg_sentiment DOUBLE,
    total_engagement BIGINT,
    top_hashtag VARCHAR,
    top_region VARCHAR
);

-- ============================================================================
-- VIEWS for easier querying
-- ============================================================================

-- Bronze tweets view with additional derived fields
CREATE OR REPLACE VIEW memory.bronze.tweets_view AS
SELECT 
    *,
    LENGTH(text) as text_length,
    CASE 
        WHEN sentiment_score > 0.1 THEN 'positive'
        WHEN sentiment_score < -0.1 THEN 'negative'
        ELSE 'neutral'
    END as sentiment_category,
    (retweet_count + like_count + reply_count + quote_count) as total_engagement
FROM memory.bronze.tweets;

-- Silver tweets view with business metrics
CREATE OR REPLACE VIEW memory.silver.tweets_view AS
SELECT 
    *,
    CASE 
        WHEN followers_count >= 100000 THEN 'High Influence'
        WHEN followers_count >= 10000 THEN 'Medium Influence'
        ELSE 'Low Influence'
    END as influence_level,
    CASE 
        WHEN total_engagement > 1000 THEN 'Viral'
        WHEN total_engagement > 100 THEN 'Popular'
        ELSE 'Regular'
    END as engagement_level
FROM memory.silver.tweets;

-- Popular hashtags view with ranking
CREATE OR REPLACE VIEW memory.gold.popular_hashtags_view AS
SELECT 
    hour,
    hashtag,
    tweet_count,
    unique_mentions,
    avg_sentiment,
    total_engagement,
    ROW_NUMBER() OVER (PARTITION BY hour ORDER BY tweet_count DESC) as rank_in_hour
FROM memory.gold.popular_hashtags_by_hour;

-- Active users view with ranking
CREATE OR REPLACE VIEW memory.gold.active_users_view AS
SELECT 
    day,
    user_id,
    username,
    tweets_count,
    followers_count,
    total_engagement,
    avg_sentiment,
    ROW_NUMBER() OVER (PARTITION BY day ORDER BY tweets_count DESC) as rank_in_day
FROM memory.gold.active_users_by_day;

-- Regional activity view with ranking
CREATE OR REPLACE VIEW memory.gold.regional_activity_view AS
SELECT 
    hour,
    region,
    language,
    tweet_count,
    unique_users,
    avg_sentiment,
    ROW_NUMBER() OVER (PARTITION BY hour ORDER BY tweet_count DESC) as rank_in_hour
FROM memory.gold.tweet_volume_by_region;

-- Language metrics view with ranking
CREATE OR REPLACE VIEW memory.gold.language_metrics_view AS
SELECT 
    hour,
    language,
    tweet_count,
    avg_tweet_length,
    avg_sentiment,
    avg_engagement,
    unique_users,
    ROW_NUMBER() OVER (PARTITION BY hour ORDER BY tweet_count DESC) as rank_in_hour
FROM memory.gold.tweet_metrics_by_language;

-- ============================================================================
-- SAMPLE DATA INSERTION
-- ============================================================================

-- Insert sample data into bronze layer
INSERT INTO memory.bronze.tweets (
    tweet_id, text, created_at, tweet_type, language, region,
    hashtags, mentions, retweet_count, like_count, reply_count, quote_count,
    is_retweet, is_reply, is_quote, has_media, has_url, sentiment_score,
    engagement_score, reach_estimate, user_id, username, display_name,
    followers_count, following_count, verified, user_location, user_description
) VALUES 
('tweet_001', 'Just launched our new product! #innovation #tech', 
 CURRENT_TIMESTAMP, 'original', 'en', 'US',
 ARRAY['innovation', 'tech'], ARRAY['techguru'], 50, 200, 10, 5,
 false, false, false, false, true, 0.8, 265, 5000,
 'user_001', 'techcompany', 'Tech Company', 10000, 500, true, 'San Francisco', 'Leading tech company'),
 
('tweet_002', 'Amazing weather today! #sunshine #happy', 
 CURRENT_TIMESTAMP, 'original', 'en', 'CA',
 ARRAY['sunshine', 'happy'], ARRAY[], 5, 25, 2, 1,
 false, false, false, true, false, 0.9, 33, 1000,
 'user_002', 'weatherfan', 'Weather Fan', 1000, 200, false, 'Toronto', 'Weather enthusiast'),
 
('tweet_003', 'RT @techcompany: Just launched our new product! #innovation #tech', 
 CURRENT_TIMESTAMP, 'retweet', 'en', 'UK',
 ARRAY['innovation', 'tech'], ARRAY['techcompany'], 0, 15, 0, 0,
 true, false, false, false, true, 0.8, 15, 300,
 'user_003', 'techfan', 'Tech Fan', 500, 100, false, 'London', 'Tech enthusiast');

-- Insert sample data into silver layer (processed from bronze)
INSERT INTO memory.silver.tweets (
    tweet_id, text, created_at, tweet_type, language, region,
    hashtags, mentions, retweet_count, like_count, reply_count, quote_count,
    is_retweet, is_reply, is_quote, has_media, has_url, sentiment_score,
    engagement_score, reach_estimate, user_id, username, display_name,
    followers_count, following_count, verified, user_location, user_description,
    text_length, sentiment_category, total_engagement
) VALUES 
('tweet_001', 'Just launched our new product! #innovation #tech', 
 CURRENT_TIMESTAMP, 'original', 'en', 'US',
 ARRAY['innovation', 'tech'], ARRAY['techguru'], 50, 200, 10, 5,
 false, false, false, false, true, 0.8, 265, 5000,
 'user_001', 'techcompany', 'Tech Company', 10000, 500, true, 'San Francisco', 'Leading tech company',
 45, 'positive', 265),
 
('tweet_002', 'Amazing weather today! #sunshine #happy', 
 CURRENT_TIMESTAMP, 'original', 'en', 'CA',
 ARRAY['sunshine', 'happy'], ARRAY[], 5, 25, 2, 1,
 false, false, false, true, false, 0.9, 33, 1000,
 'user_002', 'weatherfan', 'Weather Fan', 1000, 200, false, 'Toronto', 'Weather enthusiast',
 25, 'positive', 33),
 
('tweet_003', 'RT @techcompany: Just launched our new product! #innovation #tech', 
 CURRENT_TIMESTAMP, 'retweet', 'en', 'UK',
 ARRAY['innovation', 'tech'], ARRAY['techcompany'], 0, 15, 0, 0,
 true, false, false, false, true, 0.8, 15, 300,
 'user_003', 'techfan', 'Tech Fan', 500, 100, false, 'London', 'Tech enthusiast',
 60, 'positive', 15);

-- Insert sample data into gold layer (aggregated metrics)
INSERT INTO memory.gold.popular_hashtags_by_hour (
    hour, hashtag, tweet_count, unique_mentions, avg_sentiment, total_engagement
) VALUES 
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'innovation', 2, 2, 0.8, 280),
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'tech', 2, 2, 0.8, 280),
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'sunshine', 1, 1, 0.9, 33),
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'happy', 1, 1, 0.9, 33);

INSERT INTO memory.gold.active_users_by_day (
    day, user_id, username, tweets_count, followers_count, total_engagement, avg_sentiment
) VALUES 
(CURRENT_DATE, 'user_001', 'techcompany', 1, 10000, 265, 0.8),
(CURRENT_DATE, 'user_002', 'weatherfan', 1, 1000, 33, 0.9),
(CURRENT_DATE, 'user_003', 'techfan', 1, 500, 15, 0.8);

INSERT INTO memory.gold.tweet_volume_by_region (
    hour, region, language, tweet_count, unique_users, avg_sentiment
) VALUES 
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'US', 'en', 1, 1, 0.8),
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'CA', 'en', 1, 1, 0.9),
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'UK', 'en', 1, 1, 0.8);

INSERT INTO memory.gold.tweet_metrics_by_language (
    hour, language, tweet_count, avg_tweet_length, avg_sentiment, avg_engagement, unique_users
) VALUES 
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 'en', 3, 43.33, 0.83, 104.33, 3);

INSERT INTO memory.gold.hourly_activity_summary (
    hour, total_tweets, unique_users, avg_sentiment, total_engagement, top_hashtag, top_region
) VALUES 
(DATE_TRUNC('hour', CURRENT_TIMESTAMP), 3, 3, 0.83, 313, 'innovation', 'US');

-- ============================================================================
-- SAMPLE QUERIES FOR TESTING
-- ============================================================================

-- Test queries to verify the setup:

-- 1. Count tweets in each layer
-- SELECT 'bronze' as layer, COUNT(*) as tweet_count FROM memory.bronze.tweets
-- UNION ALL
-- SELECT 'silver' as layer, COUNT(*) as tweet_count FROM memory.silver.tweets
-- UNION ALL
-- SELECT 'gold_hashtags' as layer, COUNT(*) as tweet_count FROM memory.gold.popular_hashtags_by_hour;

-- 2. Top hashtags by engagement
-- SELECT hashtag, SUM(total_engagement) as total_engagement, COUNT(*) as tweet_count
-- FROM memory.gold.popular_hashtags_by_hour
-- GROUP BY hashtag
-- ORDER BY total_engagement DESC;

-- 3. Regional activity
-- SELECT region, SUM(tweet_count) as total_tweets, AVG(avg_sentiment) as avg_sentiment
-- FROM memory.gold.tweet_volume_by_region
-- GROUP BY region
-- ORDER BY total_tweets DESC;

-- 4. User activity analysis
-- SELECT username, tweets_count, followers_count, total_engagement
-- FROM memory.gold.active_users_by_day
-- ORDER BY tweets_count DESC;

-- 5. Language performance
-- SELECT language, SUM(tweet_count) as total_tweets, AVG(avg_sentiment) as avg_sentiment
-- FROM memory.gold.tweet_metrics_by_language
-- GROUP BY language
-- ORDER BY total_tweets DESC; 