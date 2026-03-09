#!/bin/bash
set -e

# Convert command wrapper script
INPUT="$1"
OUTPUT="$2"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Step 1: Extract text from document
TEXT=$(extract_text "$INPUT")
EXT="${OUTPUT##*.}"

# Step 2: Generate prompt
CONVERT_PROMPT=$(cat $(dirname "$0")/../templates/convert_prompt.md)

if [ "$EXT" = "json" ]; then
  FULL_PROMPT="$CONVERT_PROMPT

Convert the following content to structured JSON format:

$TEXT"
elif [ "$EXT" = "md" ] || [ "$EXT" = "txt" ]; then
  FULL_PROMPT="$CONVERT_PROMPT

Convert the following content to clean $EXT format:

$TEXT"
else
  echo "Error: Unsupported output format $EXT"
  exit 1
fi

echo "$FULL_PROMPT" > /tmp/learn_convert_prompt.txt

# Step 3: Process prompt result
if [ -z "$PROMPT_RESULT" ]; then
  echo "Error: PROMPT_RESULT not set"
  exit 1
fi

# Step 4: Save output
echo "$PROMPT_RESULT" > "$OUTPUT"

echo "✅ File converted successfully! Output saved to: $OUTPUT"