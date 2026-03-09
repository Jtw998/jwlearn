#!/bin/bash
set -e

# Review command wrapper script
LIMIT="$1"
if [ -z "$LIMIT" ]; then
  LIMIT=20
fi

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh
source $(dirname "$0")/../scripts/fsrs.sh

# Step 1: Get due cards
DUE_CARDS=$(get_due_cards "$LIMIT")
COUNT=$(echo "$DUE_CARDS" | wc -l)

if [ "$COUNT" -eq 0 ]; then
  echo "🎉 No cards due for review today!"
  exit 0
fi

echo "📚 Starting review session: $COUNT cards due today"

# Step 2: Review each card
for CARD in $DUE_CARDS; do
  QUESTION=$(jq -r '.question' "$CARD")
  echo -e "\n❓ Question: $QUESTION"
  read -p "Press Enter to see answer..."
  ANSWER=$(jq -r '.answer' "$CARD")
  echo -e "\n💡 Answer: $ANSWER"
  echo -e "\nRate your recall: 1=Again, 2=Hard, 3=Good, 4=Easy"
  read -p "Rating: " RATING
  update_card "$CARD" "$RATING"
done

# Step 3: Update stats
TODAY=$(date +%Y-%m-%d)
STATS_FILE="$STATS_DIR/$TODAY.json"
STATS=$(read_json "$STATS_FILE")
NEW_STATS=$(echo "$STATS" | jq '.reviews = (.reviews // 0) + '$COUNT' | .date = "'$TODAY'"')
write_json "$NEW_STATS" "$STATS_FILE"

# Step 4: Generate summary
REVIEW_PROMPT=$(cat $(dirname "$0")/../templates/review_prompt.md)
FULL_PROMPT="$REVIEW_PROMPT

You just completed a review session with $COUNT cards. Generate a short encouraging summary."

echo "$FULL_PROMPT" > /tmp/learn_review_prompt.txt

# The prompt result will be displayed automatically