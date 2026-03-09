#!/bin/bash
set -e

# Parse command wrapper script
INPUT="$1"
AUTO_ADD="$2"
OUTPUT="$3"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh
source $(dirname "$0")/../scripts/fsrs.sh

# Step 1: Extract text from document
TEXT=$(extract_text "$INPUT")
echo "$TEXT" > /tmp/learn_parse_content.txt

# Step 2: Generate prompt and get result
PARSE_PROMPT=$(cat $(dirname "$0")/../templates/parse_prompt.md)
FULL_PROMPT="$PARSE_PROMPT

Content file: /tmp/learn_parse_content.txt
Auto-add to deck: $AUTO_ADD
Input filename: $INPUT"

# Use current LLM to process the prompt (this is a placeholder that will be handled by skill execution)
echo "$FULL_PROMPT" > /tmp/learn_parse_prompt.txt

# Step 3: Wait for prompt result and process
# Note: The prompt result will be injected by the skill system as PROMPT_RESULT environment variable
if [ -z "$PROMPT_RESULT" ]; then
  echo "Error: PROMPT_RESULT not set"
  exit 1
fi

DOC_ID=$(generate_id)
# Add document ID to result
FULL_RESULT=$(echo "$PROMPT_RESULT" | jq '.document_id = "'$DOC_ID'" | .created = "'$(get_timestamp)'" | .source = "'$INPUT'"')

# Create directory structure for hierarchical storage
DOC_DIR="$KB_DIR/$DOC_ID"
CHAPTERS_DIR="$DOC_DIR/chapters"
mkdir -p "$CHAPTERS_DIR"

# Save full document structure
echo "$FULL_RESULT" | jq '.' > "$DOC_DIR/full_document.json"

# Step 4: Process chapters and save individually
echo "$FULL_RESULT" | jq -c '.chapters[]' | while read -r chapter; do
  CH_ID=$(echo "$chapter" | jq -r '.chapter_id')
  echo "$chapter" | jq '.' > "$CHAPTERS_DIR/$CH_ID.json"

  # Add chapter to global chapter index
  INDEX_ENTRY=$(jq -n \
    --arg doc_id "$DOC_ID" \
    --arg ch_id "$CH_ID" \
    --arg ch_num "$(echo "$chapter" | jq -r '.chapter_number')" \
    --arg ch_title "$(echo "$chapter" | jq -r '.chapter_title')" \
    --arg page_range "$(echo "$chapter" | jq -r '.page_range')" \
    '{
      document_id: $doc_id,
      chapter_id: $ch_id,
      chapter_number: $ch_num,
      chapter_title: $ch_title,
      page_range: $page_range
    }')
  echo "$INDEX_ENTRY" >> "$KB_DIR/../indexes/chapters_index.jsonl"
done

# Step 5: Process knowledge points and build search index
echo "$FULL_RESULT" | jq -c '.chapters[].knowledge_points[]' | while read -r kp; do
  KP_ID=$(echo "$kp" | jq -r '.kp_id')
  CH_ID=$(echo "$kp" | jq -r '.kp_id' | cut -d'_' -f2)

  # Add knowledge point to global search index
  INDEX_ENTRY=$(jq -n \
    --arg doc_id "$DOC_ID" \
    --arg ch_id "$CH_ID" \
    --arg kp_id "$KP_ID" \
    --arg question "$(echo "$kp" | jq -r '.question')" \
    --arg answer "$(echo "$kp" | jq -r '.answer')" \
    --arg difficulty "$(echo "$kp" | jq -r '.difficulty')" \
    '{
      document_id: $doc_id,
      chapter_id: $ch_id,
      kp_id: $kp_id,
      question: $question,
      answer: $answer,
      difficulty: $difficulty
    }')
  echo "$INDEX_ENTRY" >> "$KB_DIR/../indexes/knowledge_index.jsonl"
done

# Step 6: Save cross-chapter insights
CROSS_INSIGHTS=$(echo "$FULL_RESULT" | jq '.cross_chapter_insights')
echo "$CROSS_INSIGHTS" | jq '.' > "$DOC_DIR/cross_chapter_insights.json"

# Step 7: Auto add to deck if enabled
if [ "$AUTO_ADD" = "true" ]; then
  echo "$FULL_RESULT" | jq -c '.chapters[].knowledge_points[]' | while read -r q; do
    Q=$(echo "$q" | jq -r '.question')
    A=$(echo "$q" | jq -r '.answer')
    KP_ID=$(echo "$q" | jq -r '.kp_id')
    init_card "$DOC_ID" "$Q" "$A" "$KP_ID"
  done
fi

# Step 8: Save output if specified
if [ -n "$OUTPUT" ]; then
  echo "$FULL_RESULT" | jq '.' > "$OUTPUT"
fi

# Step 9: Update global document index
DOC_INDEX_ENTRY=$(jq -n \
  --arg doc_id "$DOC_ID" \
  --arg title "$(echo "$FULL_RESULT" | jq -r '.title')" \
  --arg source "$INPUT" \
  --arg created "$(get_timestamp)" \
  --arg total_chapters "$(echo "$FULL_RESULT" | jq -r '.total_chapters')" \
  --argjson tags "$(echo "$FULL_RESULT" | jq '.tags')" \
  '{
    document_id: $doc_id,
    title: $title,
    source: $source,
    created: $created,
    total_chapters: $total_chapters,
    tags: $tags
  }')
echo "$DOC_INDEX_ENTRY" >> "$KB_DIR/../indexes/documents_index.jsonl"

# Step 10: Show result
COUNT=$(echo "$FULL_RESULT" | jq '[.chapters[].knowledge_points[]] | length')
CH_COUNT=$(echo "$FULL_RESULT" | jq '.chapters | length')
CROSS_COUNT=$(echo "$FULL_RESULT" | jq '.cross_chapter_insights | length')
echo "✅ Document parsed successfully!"
echo "📄 Knowledge ID: $DOC_ID"
echo "📚 Chapters identified: $CH_COUNT"
echo "💡 Knowledge points extracted: $COUNT"
echo "🔍 Cross-chapter insights: $CROSS_COUNT"
echo "📂 Data saved to: $DOC_DIR"