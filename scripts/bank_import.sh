#!/bin/bash
set -e

# Question Bank Import Script
INPUT="$1"
SUBJECT="$2"
TITLE="$3"
ANSWER_PAGE="$4"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Validate input
if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

if [ -z "$SUBJECT" ]; then
    echo "Error: Subject is required"
    exit 1
fi

# Step 1: Extract text from PDF
echo "Extracting text from PDF..."
TEXT=$(extract_text "$INPUT")
echo "$TEXT" > /tmp/learn_bank_content.txt
echo "Text extraction completed."

# Step 2: Generate parsing prompt
PARSE_PROMPT=$(cat $(dirname "$0")/../templates/bank_parse_prompt.md)

# Replace placeholders in prompt
FULL_PROMPT=$(echo "$PARSE_PROMPT" | sed "s/{{subject}}/$SUBJECT/g")
if [ -n "$ANSWER_PAGE" ]; then
    FULL_PROMPT=$(echo "$FULL_PROMPT" | sed "s/{{answer_page}}/$ANSWER_PAGE/g")
else
    FULL_PROMPT=$(echo "$FULL_PROMPT" | sed "s/Optional answer page number: {{answer_page}} (if provided, answers start from this page)//g")
fi

FULL_PROMPT="$FULL_PROMPT

Content file: /tmp/learn_bank_content.txt
Input filename: $INPUT
Subject: $SUBJECT
Custom title: $TITLE
Answer page: ${ANSWER_PAGE:-Not provided}"

echo "$FULL_PROMPT" > /tmp/learn_bank_prompt.txt

# Step 3: Process prompt result (injected by skill system)
if [ -z "$PROMPT_RESULT" ]; then
    echo "Error: PROMPT_RESULT not set"
    exit 1
fi

# Validate JSON result
if ! echo "$PROMPT_RESULT" | jq '.' > /dev/null 2>&1; then
    echo "Error: Invalid JSON returned from parser"
    exit 1
fi

# Step 4: Create new question bank
echo "Creating new question bank..."
BANK_TITLE=${TITLE:-$(echo "$PROMPT_RESULT" | jq -r '.bank_metadata.title')}
BANK_DESCRIPTION=$(echo "$PROMPT_RESULT" | jq -r '.bank_metadata.description')
BANK_ID=$(create_question_bank "$BANK_TITLE" "$SUBJECT" "$INPUT" "$BANK_DESCRIPTION")
echo "Created question bank with ID: $BANK_ID"

# Step 5: Add chapters to bank
echo "Adding chapters..."
echo "$PROMPT_RESULT" | jq -c '.chapters[]' | while read -r chapter; do
    # Add bank ID to chapter
    chapter_with_bank=$(echo "$chapter" | jq '.bank_id = "'$BANK_ID'" | .created_at = "'$(get_timestamp)'"')
    add_chapter_to_bank "$BANK_ID" "$chapter_with_bank"
done

# Step 6: Add questions to bank
echo "Adding questions..."
echo "$PROMPT_RESULT" | jq -c '.questions[]' | while read -r question; do
    # Add bank ID to question
    question_with_bank=$(echo "$question" | jq '.bank_id = "'$BANK_ID'" | .created_at = "'$(get_timestamp)'"')

    # Validate question data
    if validate_question_data "$question_with_bank"; then
        add_question_to_bank "$BANK_ID" "$question_with_bank"
    else
        echo "Warning: Skipping invalid question"
    fi
done

# Step 7: Update total question count
update_bank_question_count "$BANK_ID"

# Step 8: Associate knowledge points (optional)
echo "Associating knowledge points..."
# TODO: Implement semantic matching with existing knowledge points

# Step 9: Output result
FINAL_BANK=$(get_bank_by_id "$BANK_ID")
TOTAL_QUESTIONS=$(echo "$FINAL_BANK" | jq '.total_questions')
TOTAL_CHAPTERS=$(echo "$FINAL_BANK" | jq '.chapters | length')

echo "
✅ Question bank import completed successfully!
==============================================
Bank ID: $BANK_ID
Title: $BANK_TITLE
Subject: $SUBJECT
Total chapters: $TOTAL_CHAPTERS
Total questions: $TOTAL_QUESTIONS
==============================================
Use '/learn bank-list $BANK_ID' to view the chapter structure
Use '/learn bank-extract $BANK_ID' to extract questions
"

# Clean up temporary files
rm -f /tmp/learn_bank_content.txt /tmp/learn_bank_prompt.txt

exit 0
