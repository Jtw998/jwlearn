#!/bin/bash
# Learn skill initialization script - checks and installs required dependencies

set -e

echo "🔧 Initializing learn skill dependencies..."

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "📦 Installing jq (JSON processor)..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    elif command -v choco &> /dev/null; then
        choco install jq -y
    else
        echo "❌ Could not install jq automatically. Please install jq manually: https://stedolan.github.io/jq/download/"
        exit 1
    fi
fi

# Check for pdftotext (poppler-utils)
if ! command -v pdftotext &> /dev/null; then
    echo "📦 Installing pdftotext (PDF text extraction)..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y poppler-utils
    elif command -v brew &> /dev/null; then
        brew install poppler
    elif command -v choco &> /dev/null; then
        choco install poppler -y
    else
        echo "❌ Could not install poppler-utils automatically. Please install poppler manually for pdftotext support."
        exit 1
    fi
fi

# Create data directories if they don't exist
mkdir -p $(dirname "$0")/../data/knowledge
mkdir -p $(dirname "$0")/../data/cards
mkdir -p $(dirname "$0")/../data/stats

echo "✅ All dependencies installed successfully!"
exit 0
