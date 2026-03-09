#!/bin/bash
set -e

# QA command wrapper script
QUESTION="$1"
DOCUMENT="$2"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Step 1: Get relevant documents
if [ -n "$DOCUMENT" ]; then
  DOCS=$(find "$KB_DIR" -name "*$DOCUMENT*.json" -o -name "*$(basename "$DOCUMENT")*.json" | head -5)
else
  DOCS=$(list_documents | head -10)
fi

# Step 2: Build context
CONTEXT=""
for d in $DOCS; do
  CONTENT=$(jq -r '.content' "$d" 2>/dev/null || echo "")
  CONTEXT+="Document: $(basename "$d")
$CONTENT

"
done

echo -e "$CONTEXT" > /tmp/learn_qa_context.txt

# Step 3: Generate QA prompt
QA_PROMPT=$(cat $(dirname "$0")/../templates/qa_prompt.md)
FULL_PROMPT="$QA_PROMPT

Question: $QUESTION
Context file: /tmp/learn_qa_context.txt. Generate a detailed answer with citations."

echo "$FULL_PROMPT" > /tmp/learn_qa_prompt.txt

# The prompt result will be displayed automatically