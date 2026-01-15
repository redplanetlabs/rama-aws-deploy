#!/bin/bash
set -e  # Exit on error

echo "Installing Java (required for Zookeeper and Rama)..."
sudo yum install -y java-21-amazon-corretto

echo "Verifying Java installation..."
java -version

sudo yum update -y

echo "Downloading zookeeper from $1..."

# Download Zookeeper using curl (curl is required per AMI requirements)
# -L follows redirects, -f fails on HTTP errors
if ! curl -L -f -o zookeeper.tar.gz "$1"; then
  echo "Failed to download zookeeper from $1"
  exit 1
fi

echo "Download complete ($(wc -c < zookeeper.tar.gz) bytes)"

# Verify it's actually a gzip file
if ! file zookeeper.tar.gz | grep -q "gzip"; then
  echo "Error: Downloaded file is not a gzip archive:"
  file zookeeper.tar.gz
  echo "First 500 bytes of file:"
  head -c 500 zookeeper.tar.gz
  exit 1
fi

echo "File verified as gzip, extracting..."

# Extract zookeeper tar into a temporary directory
mkdir -p tmp
if ! tar zxf zookeeper.tar.gz -C tmp; then
  echo "Failed to extract zookeeper.tar.gz"
  ls -la zookeeper.tar.gz
  exit 1
fi

echo "Extraction complete, contents of tmp:"
ls -la tmp/

# Move the extracted directory to zookeeper
# The tar extracts to tmp/apache-zookeeper-X.X.X-bin/
# Find the directory and rename it to zookeeper
ZOOKEEPER_DIR=$(ls tmp/)
if [ -z "$ZOOKEEPER_DIR" ]; then
  echo "Error: No directory found in tmp/"
  exit 1
fi

mv "tmp/$ZOOKEEPER_DIR" zookeeper
rm -rf tmp

echo "Successfully set up Zookeeper at: $(pwd)/zookeeper"

# Create data and logs directories
mkdir -p zookeeper/data
mkdir -p zookeeper/logs

echo "Zookeeper setup complete"
