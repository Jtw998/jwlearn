#!/bin/bash
set -e

# Chapters list command script
DOCUMENT="$1"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

echo "📚 Chapters for document: $DOCUMENT"
echo "===================================="

CHAPTERS=$(get_document_chapters "$DOCUMENT")

if [ -z "$CHAPTERS" ] || [ "$CHAPTERS" = "[]" ]; then
    echo "❌ No chapters found for this document."
    exit 0
fi

echo "$CHAPTERS" | jq -r '.[] |
"Chapter \(.chapter_number): \(.chapter_title)" +
"\n📄 Pages: \(.page_range) | ID: \(.chapter_id)" +
"\n----------------------------------------"'

# Show knowledge point count per chapter
echo -e "\n📊 Knowledge points per chapter:"
echo "===================================="
echo "$CHAPTERS" | jq -r '.[].chapter_id' | while read ch_id; do
    KP_COUNT=$(get_chapter_knowledge "$DOCUMENT" "$ch_id" | jq '. | length')
    echo "Chapter $ch_id: $KP_COUNT knowledge points"
done