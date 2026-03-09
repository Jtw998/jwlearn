#!/bin/bash
set -e

# Generate command wrapper script
SOURCE="$1"
COUNT="$2"
TYPE="$3"

if [ -z "$COUNT" ]; then
  COUNT=5
fi
if [ -z "$TYPE" ]; then
  TYPE="all"
fi

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Step 1: Find the document
DOC=$(find "$KB_DIR" -name "*$SOURCE*.json" -o -name "*$(basename "$SOURCE")*.json" | head -1)
if [ -z "$DOC" ]; then
  echo "❌ Document not found: $SOURCE"
  exit 1
fi

# Step 2: Extract content
CONTENT=$(jq -r '.content' "$DOC")
echo "$CONTENT" > /tmp/learn_generate_content.txt

# Step 3: Generate prompt
GENERATE_PROMPT=$(cat $(dirname "$0")/../templates/generate_prompt.md)
FULL_PROMPT="$GENERATE_PROMPT

Content file: /tmp/learn_generate_content.txt, Count: $COUNT, Type: $TYPE. Generate practice exercises."

echo "$FULL_PROMPT" > /tmp/learn_generate_prompt.txt

# Step 4: Process prompt result
if [ -z "$PROMPT_RESULT" ]; then
  echo "Error: PROMPT_RESULT not set"
  exit 1
fi

# Step 5: Save exercises
OUTPUT_FILE="$(dirname "$DOC")/exercises_$(basename "$DOC")"
echo "$PROMPT_RESULT" > "$OUTPUT_FILE"

echo "✅ Exercises generated successfully! Saved to: $OUTPUT_FILE"