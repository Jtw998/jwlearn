#!/bin/bash
set -e

# Question Extraction Script
BANK_ID="$1"
COUNT="$2"
CHAPTER="$3"
TYPE="$4"
DIFFICULTY="$5"
KNOWLEDGE_POINT="$6"
RANDOM="$7"
OUTPUT="$8"

# Default values
COUNT=${COUNT:-10}
RANDOM=${RANDOM:-true}

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Validate bank exists
BANK=$(get_bank_by_id "$BANK_ID")
if [ -z "$BANK" ] || [ "$BANK" = "null" ]; then
    echo "Error: Question bank not found: $BANK_ID"
    exit 1
fi

BANK_TITLE=$(echo "$BANK" | jq -r '.title')

echo "🔍 Extracting questions from bank: $BANK_TITLE"
echo "Filters:"
[ -n "$CHAPTER" ] && echo "  - Chapter: $CHAPTER"
[ -n "$TYPE" ] && echo "  - Type: $TYPE"
[ -n "$DIFFICULTY" ] && echo "  - Difficulty: $DIFFICULTY/5"
[ -n "$KNOWLEDGE_POINT" ] && echo "  - Knowledge point: $KNOWLEDGE_POINT"
echo "  - Count: $COUNT"
echo "  - Random order: $RANDOM"
echo "----------------------------------------------"

# Search questions with filters
QUESTIONS=$(search_questions "$BANK_ID" "$CHAPTER" "$TYPE" "$DIFFICULTY" "$KNOWLEDGE_POINT")
TOTAL_MATCHED=$(echo "$QUESTIONS" | jq -s 'length')

if [ "$TOTAL_MATCHED" -eq 0 ]; then
    echo "❌ No questions matched your filter criteria."
    exit 0
fi

if [ "$TOTAL_MATCHED" -lt "$COUNT" ]; then
    echo "⚠️  Only $TOTAL_MATCHED questions matched, returning all available."
    COUNT=$TOTAL_MATCHED
fi

# Randomize if requested
if [ "$RANDOM" = "true" ]; then
    QUESTIONS=$(echo "$QUESTIONS" | jq -s 'sort_by(random) | .[]')
fi

# Take the requested number of questions
SELECTED_QUESTIONS=$(echo "$QUESTIONS" | jq -s '.[0:'$COUNT']')

# Function to format question for display
format_question() {
    local q="$1"
    local index="$2"
    local type=$(echo "$q" | jq -r '.type')
    local stem=$(echo "$q" | jq -r '.stem')
    local difficulty=$(echo "$q" | jq -r '.difficulty')
    local options=$(echo "$q" | jq -r '.options')

    echo -e "\n${index}. ${stem} (Difficulty: ${difficulty}/5, Type: ${type})"

    if [ "$options" != "null" ] && [ "$options" != "[]" ]; then
        echo "$options" | jq -r '.[]' | while read -r opt; do
            echo "   $opt"
        done
    fi

    echo -e "\n   Correct Answer: $(echo "$q" | jq -r '.correct_answer')"

    local explanation=$(echo "$q" | jq -r '.explanation')
    if [ "$explanation" != "null" ] && [ -n "$explanation" ]; then
        echo -e "   Explanation: ${explanation}"
    fi
}

# Display results
echo -e "\n✅ Extracted $COUNT questions:\n"

echo "$SELECTED_QUESTIONS" | jq -c '.[]' | awk 'NR==1{idx=1} {print idx ":" $0; idx++}' | while IFS=":" read -r idx q_str; do
    format_question "$q_str" "$idx"
    echo "=============================================="
done

# Save to output file if specified
if [ -n "$OUTPUT" ]; then
    # Add metadata
    OUTPUT_CONTENT=$(jq -n \
        --arg bank_id "$BANK_ID" \
        --arg bank_title "$BANK_TITLE" \
        --arg generated_at "$(get_timestamp)" \
        --argjson count "$COUNT" \
        --argjson questions "$SELECTED_QUESTIONS" \
        '{
            bank_id: $bank_id,
            bank_title: $bank_title,
            generated_at: $generated_at,
            count: $count,
            questions: $questions
        }')

    # Save as JSON
    echo "$OUTPUT_CONTENT" | jq '.' > "$OUTPUT"
    echo -e "\n💾 Extracted questions saved to: $OUTPUT"
fi

echo -e "\n💡 Tips:"
echo "- Use '/learn exam-generate' to create full exam papers"
echo "- Use '/learn wrongbook' to manage wrong questions during practice"

exit 0
