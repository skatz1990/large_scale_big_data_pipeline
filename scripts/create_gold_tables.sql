-- Gold Layer: Business-level aggregated tables
-- These tables provide pre-computed metrics for efficient querying and visualization

-- 1. Popular Hashtags by Hour
CREATE TABLE IF NOT EXISTS tweets.popular_hashtags_by_hour (
    hour TIMESTAMP,
    hashtag VARCHAR,
    tweet_count BIGINT,
    unique_mentions BIGINT
)
WITH (
    format = 'DELTA',
    external_location = 's3a://tweets-gold/popular_hashtags_by_hour/',
    partitioned_by = ARRAY['hour']
);

-- 2. Active Users by Day
CREATE TABLE IF NOT EXISTS tweets.active_users_by_day (
    day DATE,
    user_id VARCHAR,
    username VARCHAR,
    tweets_count BIGINT,
    followers_count BIGINT
)
WITH (
    format = 'DELTA',
    external_location = 's3a://tweets-gold/active_users_by_day/',
    partitioned_by = ARRAY['day']
);

-- 3. Tweet Volume by Region
CREATE TABLE IF NOT EXISTS tweets.tweet_volume_by_region (
    hour TIMESTAMP,
    region VARCHAR,
    language VARCHAR,
    tweet_count BIGINT,
    unique_regions BIGINT
)
WITH (
    format = 'DELTA',
    external_location = 's3a://tweets-gold/tweet_volume_by_region/',
    partitioned_by = ARRAY['hour']
);

-- 4. Tweet Metrics by Language
CREATE TABLE IF NOT EXISTS tweets.tweet_metrics_by_language (
    hour TIMESTAMP,
    language VARCHAR,
    tweet_count BIGINT,
    avg_tweet_length DOUBLE,
    avg_sentiment DOUBLE,
    avg_engagement DOUBLE
)
WITH (
    format = 'DELTA',
    external_location = 's3a://tweets-gold/tweet_metrics_by_language/',
    partitioned_by = ARRAY['hour']
);

-- Create views for easier querying of Gold data

-- Popular Hashtags View
CREATE OR REPLACE VIEW tweets.popular_hashtags_view AS
SELECT 
    hour,
    hashtag,
    tweet_count,
    unique_mentions,
    ROW_NUMBER() OVER (PARTITION BY hour ORDER BY tweet_count DESC) as rank_in_hour
FROM tweets.popular_hashtags_by_hour;

-- Active Users View
CREATE OR REPLACE VIEW tweets.active_users_view AS
SELECT 
    day,
    user_id,
    username,
    tweets_count,
    followers_count,
    ROW_NUMBER() OVER (PARTITION BY day ORDER BY tweets_count DESC) as rank_in_day
FROM tweets.active_users_by_day;

-- Regional Activity View
CREATE OR REPLACE VIEW tweets.regional_activity_view AS
SELECT 
    hour,
    region,
    language,
    tweet_count,
    unique_regions,
    ROW_NUMBER() OVER (PARTITION BY hour ORDER BY tweet_count DESC) as rank_in_hour
FROM tweets.tweet_volume_by_region;

-- Language Metrics View
CREATE OR REPLACE VIEW tweets.language_metrics_view AS
SELECT 
    hour,
    language,
    tweet_count,
    avg_tweet_length,
    avg_sentiment,
    avg_engagement,
    ROW_NUMBER() OVER (PARTITION BY hour ORDER BY tweet_count DESC) as rank_in_hour
FROM tweets.tweet_metrics_by_language;

-- Sample queries for Gold layer:

-- 1. Top trending hashtags for the last 24 hours
-- SELECT 
--     hashtag,
--     SUM(tweet_count) as total_mentions,
--     COUNT(DISTINCT hour) as active_hours
-- FROM tweets.popular_hashtags_view
-- WHERE hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
-- GROUP BY hashtag
-- ORDER BY total_mentions DESC
-- LIMIT 10;

-- 2. Most active users today
-- SELECT 
--     username,
--     tweets_count,
--     followers_count
-- FROM tweets.active_users_view
-- WHERE day = CURRENT_DATE
-- AND rank_in_day <= 20
-- ORDER BY tweets_count DESC;

-- 3. Regional activity heatmap data
-- SELECT 
--     region,
--     language,
--     SUM(tweet_count) as total_tweets,
--     AVG(tweet_count) as avg_tweets_per_hour
-- FROM tweets.regional_activity_view
-- WHERE hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
-- GROUP BY region, language
-- ORDER BY total_tweets DESC;

-- 4. Language performance metrics
-- SELECT 
--     language,
--     SUM(tweet_count) as total_tweets,
--     AVG(avg_sentiment) as overall_sentiment,
--     AVG(avg_engagement) as overall_engagement
-- FROM tweets.language_metrics_view
-- WHERE hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
-- GROUP BY language
-- ORDER BY total_tweets DESC;

-- 5. Hourly trending hashtags
-- SELECT 
--     EXTRACT(HOUR FROM hour) as hour_of_day,
--     hashtag,
--     tweet_count
-- FROM tweets.popular_hashtags_view
-- WHERE hour >= CURRENT_DATE
-- AND rank_in_hour <= 5
-- ORDER BY hour_of_day, tweet_count DESC;

-- 6. User engagement analysis
-- SELECT 
--     CASE 
--         WHEN followers_count >= 100000 THEN 'High Influence'
--         WHEN followers_count >= 10000 THEN 'Medium Influence'
--         ELSE 'Low Influence'
--     END as influence_level,
--     COUNT(*) as user_count,
--     AVG(tweets_count) as avg_tweets,
--     SUM(tweets_count) as total_tweets
-- FROM tweets.active_users_view
-- WHERE day = CURRENT_DATE
-- GROUP BY 
--     CASE 
--         WHEN followers_count >= 100000 THEN 'High Influence'
--         WHEN followers_count >= 10000 THEN 'Medium Influence'
--         ELSE 'Low Influence'
--     END;

-- 7. Regional language distribution
-- SELECT 
--     region,
--     language,
--     COUNT(*) as hour_count,
--     SUM(tweet_count) as total_tweets
-- FROM tweets.regional_activity_view
-- WHERE hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
-- GROUP BY region, language
-- ORDER BY region, total_tweets DESC;

-- 8. Sentiment trends by language
-- SELECT 
--     language,
--     EXTRACT(HOUR FROM hour) as hour_of_day,
--     AVG(avg_sentiment) as avg_sentiment,
--     SUM(tweet_count) as tweet_count
-- FROM tweets.language_metrics_view
-- WHERE hour >= CURRENT_DATE
-- GROUP BY language, EXTRACT(HOUR FROM hour)
-- ORDER BY language, hour_of_day;

-- 9. Engagement correlation analysis
-- SELECT 
--     language,
--     CORR(avg_tweet_length, avg_engagement) as length_engagement_correlation,
--     CORR(avg_sentiment, avg_engagement) as sentiment_engagement_correlation,
--     AVG(avg_engagement) as avg_engagement
-- FROM tweets.language_metrics_view
-- WHERE hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
-- GROUP BY language
-- ORDER BY avg_engagement DESC;

-- 10. Top hashtags by engagement (if we had engagement data in hashtags table)
-- This would require joining with silver layer or adding engagement metrics to gold tables
-- SELECT 
--     ph.hashtag,
--     SUM(ph.tweet_count) as total_mentions,
--     AVG(st.sentiment_score) as avg_sentiment
-- FROM tweets.popular_hashtags_by_hour ph
-- JOIN tweets.silver_tweets_view st 
--     ON CONTAINS(st.hashtags, ph.hashtag)
-- WHERE ph.hour >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
-- GROUP BY ph.hashtag
-- ORDER BY total_mentions DESC
-- LIMIT 15; 