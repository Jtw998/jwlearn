#!/bin/bash
# Common utility functions for learn skill

# Get knowledge base directory
KB_DIR="$(dirname "$0")/../data/knowledge"
CARDS_DIR="$(dirname "$0")/../data/cards"
STATS_DIR="$(dirname "$0")/../data/stats"
DATA_DIR="$(dirname "$0")/../data"

# Question bank data files
QUESTION_BANKS_FILE="$DATA_DIR/question_banks.json"
EXAM_PAPERS_FILE="$DATA_DIR/exam_papers.json"
WRONG_QUESTIONS_FILE="$DATA_DIR/wrong_questions.json"

# Read JSON file
read_json() {
    local file="$1"
    if [ -f "$file" ]; then
        jq -c '.' "$file" 2>/dev/null || echo "{}"
    else
        echo "{}"
    fi
}

# Write JSON file
write_json() {
    local data="$1"
    local file="$2"
    echo "$data" | jq '.' > "$file"
}

# Get current timestamp in ISO format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# List all knowledge documents
list_documents() {
    find "$KB_DIR" -name "*.json" -type f | sort
}

# List all review cards
list_cards() {
    find "$CARDS_DIR" -name "*.json" -type f | sort
}

# Count total cards
count_cards() {
    list_cards | wc -l
}

# Count due cards today
count_due_cards() {
    local today=$(date +%Y-%m-%d)
    local count=0
    for card in $(list_cards); do
        local due_date=$(jq -r '.due' "$card" 2>/dev/null || echo "")
        if [ "$due_date" != "" ] && [ "$due_date" \< "$today" ] || [ "$due_date" = "$today" ]; then
            count=$((count + 1))
        fi
    done
    echo $count
}

# Extract text from file (integrated Doubao OCR for PDF)
extract_text() {
    local input="$1"
    local ext="${input##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        pdf)
            # Use Python OCR extractor (same logic as provided working script)
            python3 "$(dirname "$0")/ocr_extract.py" "$input"
            ;;
        md|txt|json)
            cat "$input" 2>/dev/null
            ;;
        *)
            echo "Unsupported file format: $ext"
            exit 1
            ;;
    esac
}

# Generate unique ID
generate_id() {
    echo "$(date +%s%N)_$RANDOM" | md5sum | head -c 16
}

# ==================== INDEX & SEARCH FUNCTIONS ====================

# Search knowledge points by keyword
search_knowledge() {
    local keyword="$1"
    local document_filter="$2"
    local index_file="$KB_DIR/../indexes/knowledge_index.jsonl"
    if [ -n "$document_filter" ]; then
        grep -i "$keyword" "$index_file" | jq 'select(.document_id == "'$document_filter'")'
    else
        grep -i "$keyword" "$index_file" | jq '.'
    fi
}

# Get all chapters of a document
get_document_chapters() {
    local doc_id="$1"
    local index_file="$KB_DIR/../indexes/chapters_index.jsonl"
    grep "$doc_id" "$index_file" | jq -s 'sort_by(.chapter_number | tonumber)'
}

# Get chapter content by ID
get_chapter_content() {
    local doc_id="$1"
    local ch_id="$2"
    cat "$KB_DIR/$doc_id/chapters/$ch_id.json"
}

# Get knowledge points by chapter
get_chapter_knowledge() {
    local doc_id="$1"
    local ch_id="$2"
    local index_file="$KB_DIR/../indexes/knowledge_index.jsonl"
    grep "$doc_id" "$index_file" | grep "$ch_id" | jq -s '.'
}

# Get cross-chapter insights for a document
get_cross_chapter_insights() {
    local doc_id="$1"
    cat "$KB_DIR/$doc_id/cross_chapter_insights.json"
}

# Search across all documents
search_all() {
    local keyword="$1"
    echo "=== Documents ==="
    grep -i "$keyword" "$KB_DIR/../indexes/documents_index.jsonl" | jq '.title'
    echo -e "\n=== Knowledge Points ==="
    search_knowledge "$keyword" | jq '{question: .question, document_id: .document_id, chapter_id: .chapter_id}'
}

# List all documents in knowledge base
list_all_documents() {
    local index_file="$KB_DIR/../indexes/documents_index.jsonl"
    if [ -f "$index_file" ]; then
        cat "$index_file" | jq -s 'sort_by(.created) | reverse | .[] | {document_id, title, created, total_chapters}'
    else
        echo "No documents found in knowledge base."
    fi
}

# ==================== QUESTION BANK UTILITY FUNCTIONS ====================

# Read all question banks
read_question_banks() {
    read_json "$QUESTION_BANKS_FILE"
}

# Write question banks
write_question_banks() {
    local data="$1"
    write_json "$data" "$QUESTION_BANKS_FILE"
}

# Get question bank by ID
get_bank_by_id() {
    local bank_id="$1"
    read_question_banks | jq '.banks[] | select(.id == "'$bank_id'")'
}

# Read all exam papers
read_exam_papers() {
    read_json "$EXAM_PAPERS_FILE"
}

# Write exam papers
write_exam_papers() {
    local data="$1"
    write_json "$data" "$EXAM_PAPERS_FILE"
}

# Read all wrong question records
read_wrong_questions() {
    read_json "$WRONG_QUESTIONS_FILE"
}

# Write wrong question records
write_wrong_questions() {
    local data="$1"
    write_json "$data" "$WRONG_QUESTIONS_FILE"
}

# Validate question bank data structure
validate_bank_data() {
    local data="$1"
    if echo "$data" | jq 'has("id") and has("title") and has("subject") and has("source_path") and has("chapters") and has("questions") and has("total_questions")' | grep -q "true"; then
        return 0
    else
        return 1
    fi
}

# Validate question data structure
validate_question_data() {
    local data="$1"
    if echo "$data" | jq 'has("id") and has("bank_id") and has("chapter_id") and has("type") and has("stem") and has("correct_answer") and has("difficulty")' | grep -q "true"; then
        return 0
    else
        return 1
    fi
}

# Search questions by multiple filters
search_questions() {
    local bank_id="$1"
    local chapter_id="$2"
    local question_type="$3"
    local difficulty="$4"
    local knowledge_point="$5"

    local filter=""

    if [ -n "$bank_id" ]; then
        filter="$filter | select(.bank_id == \"$bank_id\")"
    fi

    if [ -n "$chapter_id" ]; then
        filter="$filter | select(.chapter_id == \"$chapter_id\")"
    fi

    if [ -n "$question_type" ]; then
        filter="$filter | select(.type == \"$question_type\")"
    fi

    if [ -n "$difficulty" ]; then
        filter="$filter | select(.difficulty == $difficulty)"
    fi

    if [ -n "$knowledge_point" ]; then
        filter="$filter | select(.knowledge_point_ids[] == \"$knowledge_point\")"
    fi

    read_question_banks | jq '.banks[].questions[] '$filter
}

# Get questions by bank ID
get_questions_by_bank() {
    local bank_id="$1"
    read_question_banks | jq '.banks[] | select(.id == "'$bank_id'") | .questions[]'
}

# Get chapters by bank ID
get_chapters_by_bank() {
    local bank_id="$1"
    read_question_banks | jq '.banks[] | select(.id == "'$bank_id'") | .chapters[]'
}

# Get chapter by ID
get_chapter_by_id() {
    local bank_id="$1"
    local chapter_id="$2"
    read_question_banks | jq '.banks[] | select(.id == "'$bank_id'") | .chapters[] | select(.id == "'$chapter_id'")'
}

# Count questions in bank
count_bank_questions() {
    local bank_id="$1"
    read_question_banks | jq '.banks[] | select(.id == "'$bank_id'") | .questions | length'
}

# Add question to bank
add_question_to_bank() {
    local bank_id="$1"
    local question_data="$2"

    local banks=$(read_question_banks)
    local updated_banks=$(echo "$banks" | jq '(.banks[] | select(.id == "'$bank_id'") | .questions) += ['$question_data']')
    write_question_banks "$updated_banks"
}

# Add chapter to bank
add_chapter_to_bank() {
    local bank_id="$1"
    local chapter_data="$2"

    local banks=$(read_question_banks)
    local updated_banks=$(echo "$banks" | jq '(.banks[] | select(.id == "'$bank_id'") | .chapters) += ['$chapter_data']')
    write_question_banks "$updated_banks"
}

# Create new question bank
create_question_bank() {
    local title="$1"
    local subject="$2"
    local source_path="$3"
    local description="$4"

    local bank_id=$(generate_id)
    local timestamp=$(get_timestamp)

    local bank_data=$(jq -n \
        --arg id "$bank_id" \
        --arg title "$title" \
        --arg subject "$subject" \
        --arg description "$description" \
        --arg source_path "$source_path" \
        --arg created_at "$timestamp" \
        --arg last_updated "$timestamp" \
        '{
            id: $id,
            title: $title,
            subject: $subject,
            description: $description,
            source_path: $source_path,
            chapters: [],
            questions: [],
            total_questions: 0,
            created_at: $created_at,
            last_updated: $last_updated
        }')

    local banks=$(read_question_banks)
    local updated_banks=$(echo "$banks" | jq '.banks += ['$bank_data']')
    write_question_banks "$updated_banks"

    echo "$bank_id"
}

# Update bank total questions count
update_bank_question_count() {
    local bank_id="$1"

    local banks=$(read_question_banks)
    local count=$(echo "$banks" | jq '.banks[] | select(.id == "'$bank_id'") | .questions | length')
    local updated_banks=$(echo "$banks" | jq '(.banks[] | select(.id == "'$bank_id'") | .total_questions) = '$count'')
    write_question_banks "$updated_banks"
}

# Add wrong question record
add_wrong_question() {
    local question_id="$1"
    local bank_id="$2"
    local user_answer="$3"
    local error_reason="$4"

    local record_id=$(generate_id)
    local timestamp=$(get_timestamp)
    local today=$(date +%Y-%m-%d)

    # Initialize FSRS values for new wrong question
    local stability=0.5
    local difficulty=3.0
    local next_review=$(date -d "+1 day" +%Y-%m-%d)

    local record_data=$(jq -n \
        --arg id "$record_id" \
        --arg question_id "$question_id" \
        --arg bank_id "$bank_id" \
        --arg user_answer "$user_answer" \
        --arg error_reason "$error_reason" \
        --argjson stability "$stability" \
        --argjson difficulty "$difficulty" \
        --arg next_review "$next_review" \
        --arg created_at "$timestamp" \
        '{
            id: $id,
            question_id: $question_id,
            bank_id: $bank_id,
            user_answer: $user_answer,
            error_reason: $error_reason,
            stability: $stability,
            difficulty: $difficulty,
            last_review: null,
            next_review: $next_review,
            review_count: 0,
            lapse_count: 0,
            mastered: false,
            created_at: $created_at
        }')

    local wrong_questions=$(read_wrong_questions)
    local updated_records=$(echo "$wrong_questions" | jq '.records += ['$record_data']')
    write_wrong_questions "$updated_records"

    echo "$record_id"
}
