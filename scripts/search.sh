#!/bin/bash
set -e

# Search command script
KEYWORD="$1"
DOCUMENT="$2"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

echo "🔍 Searching for: $KEYWORD"
echo "===================================="

if [ -n "$DOCUMENT" ]; then
    echo "📄 Filtered to document: $DOCUMENT"
    echo "===================================="
fi

RESULTS=$(search_knowledge "$KEYWORD" "$DOCUMENT")

if [ -z "$RESULTS" ]; then
    echo "❌ No matching knowledge points found."
    exit 0
fi

COUNT=$(echo "$RESULTS" | wc -l)
echo "✅ Found $COUNT matching results:"
echo "===================================="

echo "$RESULTS" | jq -r '
"\n📌 Question: \(.question)" +
"\n💡 Answer: \(.answer)" +
"\n📚 Document ID: \(.document_id) | Chapter: \(.chapter_id) | Difficulty: \(.difficulty)" +
"\n----------------------------------------"'