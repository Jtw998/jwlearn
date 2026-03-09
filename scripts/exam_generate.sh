#!/bin/bash
set -e

# Exam Paper Generation Script
BANK_IDS="$1"
TITLE="$2"
TOTAL_SCORE="$3"
DURATION="$4"
DIFFICULTY_DISTRIBUTION="$5"
TYPE_RATIO="$6"
KNOWLEDGE_COVERAGE="$7"
OUTPUT="$8"

# Default values
TOTAL_SCORE=${TOTAL_SCORE:-100}
DURATION=${DURATION:-120}
DIFFICULTY_DISTRIBUTION=${DIFFICULTY_DISTRIBUTION:-"3:5:2"}
KNOWLEDGE_COVERAGE=${KNOWLEDGE_COVERAGE:-0.8}

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh

# Parse difficulty distribution
IFS=':' read -r EASY_RATIO MEDIUM_RATIO HARD_RATIO <<< "$DIFFICULTY_DISTRIBUTION"
TOTAL_RATIO=$((EASY_RATIO + MEDIUM_RATIO + HARD_RATIO))

# Parse type ratio
declare -A TYPE_SCORES
IFS=',' read -ra TYPE_PAIRS <<< "$TYPE_RATIO"
for pair in "${TYPE_PAIRS[@]}"; do
    IFS=':' read -r type score <<< "$pair"
    TYPE_SCORES[$type]=$score
done

# Validate bank IDs
IFS=',' read -ra BANK_ID_ARRAY <<< "$BANK_IDS"
for bank_id in "${BANK_ID_ARRAY[@]}"; do
    BANK=$(get_bank_by_id "$bank_id")
    if [ -z "$BANK" ] || [ "$BANK" = "null" ]; then
        echo "Error: Question bank not found: $bank_id"
        exit 1
    fi
done

echo "📝 Generating exam paper: $TITLE"
echo "=============================================="
echo "Source banks: $BANK_IDS"
echo "Total score: $TOTAL_SCORE"
echo "Duration: $DURATION minutes"
echo "Difficulty distribution: Easy($EASY_RATIO) : Medium($MEDIUM_RATIO) : Hard($HARD_RATIO)"
echo "Question type ratio: $TYPE_RATIO"
echo "Minimum knowledge coverage: $((KNOWLEDGE_COVERAGE * 100))%"
echo "Output: $OUTPUT"
echo "=============================================="
echo "Generating paper..."

# Step 1: Calculate number of questions per difficulty level
EASY_SCORE=$(( TOTAL_SCORE * EASY_RATIO / TOTAL_RATIO ))
MEDIUM_SCORE=$(( TOTAL_SCORE * MEDIUM_RATIO / TOTAL_RATIO ))
HARD_SCORE=$(( TOTAL_SCORE - EASY_SCORE - MEDIUM_SCORE ))

# Step 2: Select questions by type and difficulty
SELECTED_QUESTIONS="[]"
TOTAL_SELECTED_SCORE=0

# Function to select questions for a difficulty level
select_questions_for_difficulty() {
    local difficulty="$1"
    local target_score="$2"
    local selected="[]"
    local current_score=0

    for type in "${!TYPE_SCORES[@]}"; do
        local type_score=${TYPE_SCORES[$type]}
        local num_questions=$(( target_score * type_score / TOTAL_SCORE ))

        # Get questions for this difficulty and type
        local questions=""
        for bank_id in "${BANK_ID_ARRAY[@]}"; do
            local bank_questions=$(search_questions "$bank_id" "" "$type" "$difficulty" "")
            if [ -n "$bank_questions" ]; then
                if [ -z "$questions" ]; then
                    questions="$bank_questions"
                else
                    questions=$(echo "$questions $bank_questions" | jq -s 'add')
                fi
            fi
        done

        # Randomize and select
        if [ -n "$questions" ]; then
            local available_count=$(echo "$questions" | jq -s 'length')
            if [ "$available_count" -lt "$num_questions" ]; then
                echo "⚠️  Not enough $type questions for difficulty $difficulty, using $available_count instead of $num_questions"
                num_questions=$available_count
            fi

            if [ "$num_questions" -gt 0 ]; then
                local selected_type=$(echo "$questions" | jq -s 'sort_by(random) | .[0:'$num_questions']')
                selected=$(echo "$selected $selected_type" | jq -s 'add')
                current_score=$(( current_score + num_questions * (type_score / num_questions) ))
            fi
        fi
    done

    echo "$selected"
}

# Select questions for each difficulty
EASY_QUESTIONS=$(select_questions_for_difficulty 1 "$EASY_SCORE")
MEDIUM_QUESTIONS=$(select_questions_for_difficulty 3 "$MEDIUM_SCORE")
HARD_QUESTIONS=$(select_questions_for_difficulty 5 "$HARD_SCORE")

# Combine all questions
SELECTED_QUESTIONS=$(echo "[$EASY_QUESTIONS, $MEDIUM_QUESTIONS, $HARD_QUESTIONS]" | jq -s 'add | sort_by(random)')
TOTAL_QUESTIONS=$(echo "$SELECTED_QUESTIONS" | jq 'length')

# Step 3: Create exam paper object
PAPER_ID=$(generate_id)
TIMESTAMP=$(get_timestamp)

PAPER_DATA=$(jq -n \
    --arg id "$PAPER_ID" \
    --arg title "$TITLE" \
    --argjson bank_ids "$(printf '%s\n' "${BANK_ID_ARRAY[@]}" | jq -R . | jq -s .)" \
    --argjson questions "$SELECTED_QUESTIONS" \
    --argjson total_score "$TOTAL_SCORE" \
    --argjson duration "$DURATION" \
    --arg created_at "$TIMESTAMP" \
    '{
        id: $id,
        title: $title,
        bank_ids: $bank_ids,
        questions: $questions,
        total_score: $total_score,
        duration: $duration,
        generation_rules: {
            difficulty_distribution: "'$DIFFICULTY_DISTRIBUTION'",
            type_ratio: "'$TYPE_RATIO'",
            knowledge_coverage: '$KNOWLEDGE_COVERAGE'
        },
        created_at: $created_at
    }')

# Save to exam papers file
EXAM_PAPERS=$(read_exam_papers)
UPDATED_PAPERS=$(echo "$EXAM_PAPERS" | jq '.papers += ['$PAPER_DATA']')
write_exam_papers "$UPDATED_PAPERS"

# Step 4: Generate output file
if [[ "$OUTPUT" == *.md ]]; then
    # Generate Markdown output
    MD_CONTENT="# $TITLE\n\n"
    MD_CONTENT+="**Total Score**: $TOTAL_SCORE  \n"
    MD_CONTENT+="**Duration**: $DURATION minutes  \n"
    MD_CONTENT+="**Generated At**: $(date -d "$TIMESTAMP" "+%Y-%m-%d %H:%M:%S")  \n\n"
    MD_CONTENT+="## Exam Questions\n\n"

    # Add questions
    index=1
    echo "$SELECTED_QUESTIONS" | jq -c '.[]' | while read -r q; do
        stem=$(echo "$q" | jq -r '.stem')
        type=$(echo "$q" | jq -r '.type')
        options=$(echo "$q" | jq -r '.options')

        MD_CONTENT+="### $index. $stem ($type)\n\n"

        if [ "$options" != "null" ] && [ "$options" != "[]" ]; then
            echo "$options" | jq -r '.[]' | while read -r opt; do
                MD_CONTENT+="- $opt\n"
            done
        fi

        MD_CONTENT+="\n**Answer**: _________________________\n\n"
        index=$((index + 1))
    done

    # Add answer key at the end
    MD_CONTENT+="---\n\n## Answer Key\n\n"
    index=1
    echo "$SELECTED_QUESTIONS" | jq -c '.[]' | while read -r q; do
        answer=$(echo "$q" | jq -r '.correct_answer')
        MD_CONTENT+="$index. $answer\n"
        index=$((index + 1))
    done

    echo -e "$MD_CONTENT" > "$OUTPUT"
elif [[ "$OUTPUT" == *.json ]]; then
    # Save as JSON
    echo "$PAPER_DATA" | jq '.' > "$OUTPUT"
else
    echo "⚠️  Unsupported output format, saved as JSON"
    echo "$PAPER_DATA" | jq '.' > "${OUTPUT}.json"
fi

echo "✅ Exam paper generated successfully!"
echo "=============================================="
echo "Paper ID: $PAPER_ID"
echo "Total questions: $TOTAL_QUESTIONS"
echo "Output saved to: $OUTPUT"
echo "=============================================="
echo "💡 Use '/learn wrongbook review' to practice and track wrong questions"

exit 0
