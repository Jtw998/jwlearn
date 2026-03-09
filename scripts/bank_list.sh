#!/bin/bash
set -e

# Question Bank List Script
BANK_ID="$1"

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Function to print chapter hierarchy
print_chapter_hierarchy() {
    local chapters="$1"
    local level="$2"
    local indent=""
    for ((i=0; i<level; i++)); do
        indent="$indent  "
    done

    echo "$chapters" | jq -c '.' | while read -r chapter; do
        local title=$(echo "$chapter" | jq -r '.title')
        local order=$(echo "$chapter" | jq -r '.order')
        local question_count=$(echo "$chapter" | jq -r '.question_count // 0')

        echo "${indent}${order}. ${title} (${question_count} questions)"

        # Print children if any
        local children=$(echo "$chapter" | jq -c '.children[]')
        if [ -n "$children" ]; then
            print_chapter_hierarchy "$children" $((level + 1))
        fi
    done
}

# If specific bank ID is provided, show detailed info
if [ -n "$BANK_ID" ]; then
    BANK=$(get_bank_by_id "$BANK_ID")
    if [ -z "$BANK" ] || [ "$BANK" = "null" ]; then
        echo "Error: Question bank not found: $BANK_ID"
        exit 1
    fi

    TITLE=$(echo "$BANK" | jq -r '.title')
    SUBJECT=$(echo "$BANK" | jq -r '.subject')
    DESCRIPTION=$(echo "$BANK" | jq -r '.description')
    TOTAL_QUESTIONS=$(echo "$BANK" | jq -r '.total_questions')
    CREATED_AT=$(echo "$BANK" | jq -r '.created_at')
    SOURCE_PATH=$(echo "$BANK" | jq -r '.source_path')

    echo "
📚 Question Bank Details
==============================================
ID: $BANK_ID
Title: $TITLE
Subject: $SUBJECT
Description: ${DESCRIPTION:-N/A}
Total questions: $TOTAL_QUESTIONS
Created: $CREATED_AT
Source file: $SOURCE_PATH
==============================================

📑 Chapter Structure:
"
    CHAPTERS=$(get_chapters_by_bank "$BANK_ID")
    print_chapter_hierarchy "$CHAPTERS" 0

    exit 0
fi

# Otherwise list all banks
BANKS=$(read_question_banks | jq '.banks')
BANK_COUNT=$(echo "$BANKS" | jq 'length')

if [ "$BANK_COUNT" -eq 0 ]; then
    echo "No question banks found. Use '/learn bank-import' to import a PDF question bank."
    exit 0
fi

echo "
📚 All Question Banks ($BANK_COUNT total)
==============================================
"

echo "$BANKS" | jq -c '.[]' | while read -r bank; do
    ID=$(echo "$bank" | jq -r '.id')
    TITLE=$(echo "$bank" | jq -r '.title')
    SUBJECT=$(echo "$bank" | jq -r '.subject')
    TOTAL_QUESTIONS=$(echo "$bank" | jq -r '.total_questions')
    CREATED_AT=$(echo "$bank" | jq -r '.created_at')

    echo "ID: $ID"
    echo "  Title: $TITLE"
    echo "  Subject: $SUBJECT"
    echo "  Questions: $TOTAL_QUESTIONS"
    echo "  Created: $CREATED_AT"
    echo "  Use '/learn bank-list $ID' to view detailed structure"
    echo "----------------------------------------------"
done

echo "
💡 Tips:
- Use '/learn bank-import <path> <subject>' to import a new PDF question bank
- Use '/learn bank-extract <bank-id>' to extract questions for practice
"

exit 0
