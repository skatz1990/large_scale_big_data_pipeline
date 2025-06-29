FROM openjdk:11-jre-slim

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set environment variables for Spark
ENV SPARK_HOME=/usr/local/spark
ENV PYTHONPATH="${SPARK_HOME}/python:${SPARK_HOME}/python/lib/py4j-0.10.9.5-src.zip:${PYTHONPATH}"
ENV PATH="${SPARK_HOME}/bin:${PATH}"

# Download and setup Spark
RUN curl -O https://archive.apache.org/dist/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz \
    && tar -xzf spark-3.5.0-bin-hadoop3.tgz \
    && mv spark-3.5.0-bin-hadoop3 /usr/local/spark \
    && rm spark-3.5.0-bin-hadoop3.tgz

# Create a script to run the processor
RUN echo '#!/bin/bash\npython3 /app/processor.py' > /app/run.sh \
    && chmod +x /app/run.sh

CMD ["/app/run.sh"] 