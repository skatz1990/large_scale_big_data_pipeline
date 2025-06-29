-- Silver Layer: External table for cleaned and structured tweet data
-- This table provides access to processed Delta Lake data

-- Create Silver table (external table on Delta Lake data)
CREATE TABLE IF NOT EXISTS tweets.silver_tweets (
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
    processed_at TIMESTAMP,
    processing_date DATE
)
WITH (
    format = 'DELTA',
    external_location = 's3a://tweets-silver/tweets_silver/',
    partitioned_by = ARRAY['processing_date']
);

-- Create view for easier querying of Silver data
CREATE OR REPLACE VIEW tweets.silver_tweets_view AS
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
    user_id,
    username,
    display_name,
    followers_count,
    following_count,
    verified,
    user_location,
    user_description,
    original_tweet_id,
    original_user_id,
    reply_to_tweet_id,
    reply_to_user_id,
    quoted_tweet_id,
    quoted_user_id,
    quoted_text,
    processed_at,
    processing_date,
    -- Derived fields for analytics
    LENGTH(text) as text_length,
    CASE 
        WHEN sentiment_score > 0.1 THEN 'positive'
        WHEN sentiment_score < -0.1 THEN 'negative'
        ELSE 'neutral'
    END as sentiment_category,
    (retweet_count + like_count + reply_count + quote_count) as total_engagement
FROM tweets.silver_tweets;

-- Sample queries for Silver layer:

-- 1. Data quality check
-- SELECT 
--     processing_date,
--     COUNT(*) as total_tweets,
--     COUNT(DISTINCT user_id) as unique_users,
--     AVG(sentiment_score) as avg_sentiment,
--     AVG(total_engagement) as avg_engagement
-- FROM tweets.silver_tweets_view
-- GROUP BY processing_date
-- ORDER BY processing_date DESC;

-- 2. Language distribution
-- SELECT 
--     language,
--     COUNT(*) as tweet_count,
--     AVG(sentiment_score) as avg_sentiment
-- FROM tweets.silver_tweets_view
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY language
-- ORDER BY tweet_count DESC;

-- 3. Regional activity
-- SELECT 
--     region,
--     COUNT(*) as tweet_count,
--     COUNT(DISTINCT user_id) as unique_users,
--     AVG(followers_count) as avg_followers
-- FROM tweets.silver_tweets_view
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY region
-- ORDER BY tweet_count DESC;

-- 4. Tweet type analysis
-- SELECT 
--     tweet_type,
--     COUNT(*) as count,
--     AVG(sentiment_score) as avg_sentiment,
--     AVG(total_engagement) as avg_engagement
-- FROM tweets.silver_tweets_view
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY tweet_type;

-- 5. User verification analysis
-- SELECT 
--     verified,
--     COUNT(*) as tweet_count,
--     AVG(followers_count) as avg_followers,
--     AVG(total_engagement) as avg_engagement
-- FROM tweets.silver_tweets_view
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY verified;

-- 6. Hourly activity pattern
-- SELECT 
--     EXTRACT(HOUR FROM created_at) as hour_of_day,
--     COUNT(*) as tweet_count,
--     AVG(sentiment_score) as avg_sentiment
-- FROM tweets.silver_tweets_view
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY EXTRACT(HOUR FROM created_at)
-- ORDER BY hour_of_day;

-- 7. Top users by engagement
-- SELECT 
--     username,
--     display_name,
--     followers_count,
--     COUNT(*) as tweet_count,
--     AVG(total_engagement) as avg_engagement,
--     SUM(total_engagement) as total_engagement
-- FROM tweets.silver_tweets_view
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY username, display_name, followers_count
-- ORDER BY total_engagement DESC
-- LIMIT 20;

-- 8. Hashtag analysis
-- SELECT 
--     hashtag,
--     COUNT(*) as usage_count,
--     AVG(sentiment_score) as avg_sentiment,
--     AVG(total_engagement) as avg_engagement
-- FROM tweets.silver_tweets_view
-- CROSS JOIN UNNEST(hashtags) AS t(hashtag)
-- WHERE processing_date = CURRENT_DATE
-- GROUP BY hashtag
-- ORDER BY usage_count DESC
-- LIMIT 15; 