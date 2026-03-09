#!/bin/bash
set -e

# Cross-chapter insights command script
DOCUMENT="$1"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

echo "🔬 Cross-chapter comparative insights for document: $DOCUMENT"
echo "===================================="

INSIGHTS=$(get_cross_chapter_insights "$DOCUMENT")

if [ -z "$INSIGHTS" ] || [ "$INSIGHTS" = "[]" ]; then
    echo "❌ No cross-chapter insights found for this document."
    exit 0
fi

COUNT=$(echo "$INSIGHTS" | jq '. | length')
echo "✅ Found $COUNT cross-chapter insights:"
echo "===================================="

echo "$INSIGHTS" | jq -r '.[] |
"\n🔍 Topic: \(.topic)" +
"\n📚 Chapters involved: \(.chapters_involved | join(", "))" +
"\n💡 Analysis: \(.content)" +
"\n----------------------------------------"'