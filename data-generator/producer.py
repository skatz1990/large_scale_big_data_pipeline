#!/usr/bin/env python3
"""
Data Generator (Producer) for Large-Scale Streaming Data Pipeline
Simulates high-throughput Twitter activity and publishes to Kafka
"""

import json
import time
import random
import os
from datetime import datetime
from typing import Dict, List, Any, Optional

from kafka import KafkaProducer
from faker import Faker

# Initialize Faker for generating realistic data
fake = Faker()

class TweetDataGenerator:
    """Generates realistic tweet data for streaming pipeline"""

    def __init__(self):
        self.hashtags = [
            "#DataScience", "#MachineLearning", "#AI", "#BigData", "#Analytics",
            "#Python", "#Spark", "#Kafka", "#Streaming", "#DeltaLake",
            "#Tech", "#Innovation", "#Startup", "#Business", "#Marketing",
            "#SocialMedia", "#Digital", "#Cloud", "#AWS", "#Azure",
            "#Programming", "#Coding", "#Developer", "#Software", "#Engineering",
            "#Data", "#Insights", "#Visualization", "#BI", "#Dashboard"
        ]

        self.languages = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh", "ar"]

        self.regions = [
            "North America", "Europe", "Asia Pacific", "Latin America", 
            "Middle East", "Africa", "Australia", "South Asia"
        ]

        self.tweet_types = ["original", "retweet", "reply", "quote"]

        # Common words for generating realistic tweet content
        self.common_words = [
            "data", "analysis", "insights", "trends", "technology", "innovation",
            "business", "strategy", "growth", "success", "future", "digital",
            "transformation", "automation", "intelligence", "learning", "development",
            "platform", "solution", "service", "product", "market", "industry",
            "research", "study", "report", "findings", "results", "performance",
            "efficiency", "optimization", "scalability", "reliability", "security"
        ]

    def generate_user(self) -> Dict[str, Any]:
        """Generate realistic user data"""
        return {
            "user_id": fake.uuid4(),
            "username": fake.user_name(),
            "display_name": fake.name(),
            "followers_count": random.randint(0, 1000000),
            "following_count": random.randint(0, 5000),
            "verified": random.choice([True, False]),
            "created_at": fake.date_time_between(start_date='-5y', end_date='now').isoformat(),
            "location": fake.city() if random.random() > 0.3 else None,
            "description": fake.text(max_nb_chars=160) if random.random() > 0.2 else None
        }

    def generate_hashtags(self, count: Optional[int] = None) -> List[str]:
        """Generate random hashtags"""
        if count is None:
            count = random.randint(0, 5)
        return random.sample(self.hashtags, min(count, len(self.hashtags)))

    def generate_tweet_text(self, max_length: int = 280) -> str:
        """Generate realistic tweet text"""
        # 70% chance to include hashtags
        include_hashtags = random.random() < 0.7

        # Generate base text
        sentences = []
        for _ in range(random.randint(1, 3)):
            sentence = fake.sentence()
            sentences.append(sentence)

        text = " ".join(sentences)

        # Add hashtags if needed
        if include_hashtags:
            hashtags = self.generate_hashtags(random.randint(1, 3))
            hashtag_text = " ".join(hashtags)
            text = f"{text} {hashtag_text}"

        # Truncate if too long
        if len(text) > max_length:
            text = text[:max_length-3] + "..."

        return text

    def generate_tweet(self) -> Dict[str, Any]:
        """Generate a complete tweet record"""
        tweet_type = random.choice(self.tweet_types)

        # Base tweet data
        tweet = {
            "tweet_id": fake.uuid4(),
            "text": self.generate_tweet_text(),
            "user": self.generate_user(),
            "created_at": datetime.now().isoformat(),
            "tweet_type": tweet_type,
            "language": random.choice(self.languages),
            "region": random.choice(self.regions),
            "hashtags": self.generate_hashtags(),
            "mentions": [fake.user_name() for _ in range(random.randint(0, 3))],
            "retweet_count": random.randint(0, 10000),
            "like_count": random.randint(0, 50000),
            "reply_count": random.randint(0, 1000),
            "quote_count": random.randint(0, 500),
            "is_retweet": tweet_type == "retweet",
            "is_reply": tweet_type == "reply",
            "is_quote": tweet_type == "quote",
            "has_media": random.random() < 0.2,  # 20% chance of media
            "has_url": random.random() < 0.4,    # 40% chance of URL
            "sentiment_score": round(random.uniform(-1.0, 1.0), 3),
            "engagement_score": random.randint(0, 100),
            "reach_estimate": random.randint(100, 1000000)
        }

        # Add retweet/reply specific data
        if tweet_type == "retweet":
            tweet["original_tweet_id"] = fake.uuid4()
            tweet["original_user"] = self.generate_user()
        elif tweet_type == "reply":
            tweet["reply_to_tweet_id"] = fake.uuid4()
            tweet["reply_to_user"] = self.generate_user()
        elif tweet_type == "quote":
            tweet["quoted_tweet_id"] = fake.uuid4()
            tweet["quoted_user"] = self.generate_user()
            tweet["quoted_text"] = self.generate_tweet_text(100)

        return tweet

class KafkaTweetProducer:
    """Kafka producer for tweet data"""

    def __init__(self, bootstrap_servers: str, topic: str):
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            acks='all',
            retries=3,
            batch_size=16384,
            linger_ms=10,
            buffer_memory=33554432
        )
        self.topic = topic
        self.generator = TweetDataGenerator()

    def send_tweet(self, tweet: Dict[str, Any]) -> None:
        """Send a tweet to Kafka"""
        try:
            # Use tweet_id as key for partitioning
            future = self.producer.send(
                self.topic,
                key=tweet['tweet_id'],
                value=tweet
            )
            # Wait for the send to complete
            record_metadata = future.get(timeout=10)
            print(f"Tweet sent to {record_metadata.topic} partition {record_metadata.partition}" \
            + "offset {record_metadata.offset}")
        except Exception as e:
            print(f"Error sending tweet: {e}")

    def generate_and_send_batch(self, batch_size: int) -> None:
        """Generate and send a batch of tweets"""
        for _ in range(batch_size):
            tweet = self.generator.generate_tweet()
            self.send_tweet(tweet)

    def run_stream(self, tweets_per_second: int) -> None:
        """Run continuous tweet stream"""
        print(f"Starting tweet stream at {tweets_per_second} tweets/second")

        batch_size = max(1, tweets_per_second // 10)  # Send in batches
        delay = 1.0 / (tweets_per_second / batch_size)

        try:
            while True:
                start_time = time.time()
                self.generate_and_send_batch(batch_size)

                # Calculate sleep time to maintain rate
                elapsed = time.time() - start_time
                sleep_time = max(0, delay - elapsed)
                time.sleep(sleep_time)

        except KeyboardInterrupt:
            print("Stopping tweet stream...")
        finally:
            self.producer.close()

def main():
    """Main function"""
    # Get configuration from environment
    bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    topic = os.getenv('TOPIC_NAME', 'tweets')
    tweets_per_second = int(os.getenv('TWEETS_PER_SECOND', '1000'))

    print(f"Connecting to Kafka at {bootstrap_servers}")
    print(f"Publishing to topic: {topic}")
    print(f"Target rate: {tweets_per_second} tweets/second")

    # Create producer and start streaming
    producer = KafkaTweetProducer(bootstrap_servers, topic)
    producer.run_stream(tweets_per_second)

if __name__ == "__main__":
    main()
