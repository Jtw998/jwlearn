#!/bin/bash
set -e

# Stats command wrapper script

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Step 1: Calculate statistics
TOTAL_CARDS=$(count_cards)
DUE_CARDS=$(count_due_cards)
TOTAL_DOCS=$(list_documents | wc -l)
TOTAL_REVIEWS=$(find "$STATS_DIR" -name "*.json" -exec jq '.reviews // 0' {} \; | awk '{sum += $1} END {print sum}')
WEEKLY_REVIEWS=$(for i in {0..6}; do d=$(date -d "-$i days" +%Y-%m-%d); f="$STATS_DIR/$d.json"; if [ -f "$f" ]; then jq '.reviews // 0' "$f"; else echo 0; fi; done | awk '{sum += $1} END {print sum}')

# Step 2: Generate stats report
STATS_PROMPT=$(cat $(dirname "$0")/../templates/stats_prompt.md)
FULL_PROMPT="$STATS_PROMPT

Statistics: Total cards: $TOTAL_CARDS, Due today: $DUE_CARDS, Total documents: $TOTAL_DOCS, Total reviews: $TOTAL_REVIEWS, Weekly reviews: $WEEKLY_REVIEWS. Generate a comprehensive statistics report."

echo "$FULL_PROMPT" > /tmp/learn_stats_prompt.txt

# The prompt result will be displayed automatically