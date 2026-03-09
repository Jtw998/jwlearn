#!/bin/bash
set -e

# Wrong Question Book Management Script
ACTION="$1"
BANK_ID="$2"
LIMIT="$3"
OUTPUT="$4"
QUESTION_ID="$5"

# Default values
LIMIT=${LIMIT:-20}

# Source dependencies
source $(dirname "$0")/../scripts/utils.sh
source $(dirname "$0")/../scripts/fsrs.sh

# Function to get question details
get_question_details() {
    local qid="$1"
    local bid="$2"
    get_bank_by_id "$bid" | jq '.questions[] | select(.id == "'$qid'")'
}

# Handle different actions
case "$ACTION" in
    "list")
        echo "📋 Wrong Question Book"
        echo "=============================================="

        RECORDS=$(read_wrong_questions | jq '.records')
        if [ -n "$BANK_ID" ]; then
            RECORDS=$(echo "$RECORDS" | jq 'map(select(.bank_id == "'$BANK_ID'"))')
        fi

        TOTAL_RECORDS=$(echo "$RECORDS" | jq 'length')
        if [ "$TOTAL_RECORDS" -eq 0 ]; then
            echo "No wrong questions found."
            exit 0
        fi

        MASTERED_COUNT=$(echo "$RECORDS" | jq 'map(select(.mastered == true)) | length')
        DUE_TODAY=$(echo "$RECORDS" | jq 'map(select(.next_review <= "'$(date +%Y-%m-%d)'" and .mastered == false)) | length')

        echo "Total wrong questions: $TOTAL_RECORDS"
        echo "Mastered: $MASTERED_COUNT"
        echo "Due for review today: $DUE_TODAY"
        echo "=============================================="

        # List records
        echo "$RECORDS" | jq -c '.[]' | while read -r record; do
            rid=$(echo "$record" | jq -r '.id')
            qid=$(echo "$record" | jq -r '.question_id')
            bid=$(echo "$record" | jq -r '.bank_id')
            mastered=$(echo "$record" | jq -r '.mastered')
            next_review=$(echo "$record" | jq -r '.next_review')
            review_count=$(echo "$record" | jq -r '.review_count')

            q_details=$(get_question_details "$qid" "$bid")
            q_stem=$(echo "$q_details" | jq -r '.stem' | cut -c 1-50)

            echo "ID: $rid"
            echo "  Question: ${q_stem}..."
            echo "  Bank ID: $bid"
            echo "  Mastered: $mastered"
            echo "  Next review: $next_review"
            echo "  Review count: $review_count"
            echo "----------------------------------------------"
        done
        ;;

    "review")
        echo "📚 Wrong Question Review Session"
        echo "=============================================="

        # Get due questions
        TODAY=$(date +%Y-%m-%d)
        RECORDS=$(read_wrong_questions | jq '.records | map(select(.next_review <= "'$TODAY'" and .mastered == false))')

        if [ -n "$BANK_ID" ]; then
            RECORDS=$(echo "$RECORDS" | jq 'map(select(.bank_id == "'$BANK_ID'"))')
        fi

        TOTAL_DUE=$(echo "$RECORDS" | jq 'length')
        if [ "$TOTAL_DUE" -eq 0 ]; then
            echo "✅ No questions due for review today!"
            exit 0
        fi

        if [ "$TOTAL_DUE" -lt "$LIMIT" ]; then
            LIMIT=$TOTAL_DUE
        fi

        # Randomize and take limit
        RECORDS=$(echo "$RECORDS" | jq -s 'sort_by(random) | .[0:'$LIMIT']')

        echo "You have $TOTAL_DUE questions due, reviewing $LIMIT of them."
        echo "Rate each question: 1=Again, 2=Hard, 3=Good, 4=Easy"
        echo "Press Ctrl+C to exit at any time."
        echo "=============================================="

        # Review loop
        index=1
        echo "$RECORDS" | jq -c '.[]' | while read -r record; do
            rid=$(echo "$record" | jq -r '.id')
            qid=$(echo "$record" | jq -r '.question_id')
            bid=$(echo "$record" | jq -r '.bank_id')
            user_answer=$(echo "$record" | jq -r '.user_answer')
            error_reason=$(echo "$record" | jq -r '.error_reason')

            # Get question details
            q=$(get_question_details "$qid" "$bid")
            stem=$(echo "$q" | jq -r '.stem')
            type=$(echo "$q" | jq -r '.type')
            correct_answer=$(echo "$q" | jq -r '.correct_answer')
            options=$(echo "$q" | jq -r '.options')
            explanation=$(echo "$q" | jq -r '.explanation')

            clear
            echo "Question $index/$LIMIT"
            echo "=============================================="
            echo "$stem (Type: $type)"
            echo

            if [ "$options" != "null" ] && [ "$options" != "[]" ]; then
                echo "$options" | jq -r '.[]'
                echo
            fi

            echo "Your previous answer: $user_answer"
            echo "Error reason: $error_reason"
            echo
            echo "Press Enter to show answer..."
            read -rs

            echo
            echo "✅ Correct Answer: $correct_answer"
            if [ "$explanation" != "null" ] && [ -n "$explanation" ]; then
                echo "📝 Explanation: $explanation"
            fi
            echo

            # Get user rating
            while true; do
                read -p "Rate your recall (1=Again, 2=Hard, 3=Good, 4=Easy): " rating
                if [[ "$rating" =~ ^[1-4]$ ]]; then
                    break
                fi
                echo "Invalid input, please enter 1-4."
            done

            # Update FSRS parameters
            stability=$(echo "$record" | jq -r '.stability')
            difficulty=$(echo "$record" | jq -r '.difficulty')
            review_count=$(echo "$record" | jq -r '.review_count')
            lapse_count=$(echo "$record" | jq -r '.lapse_count')

            # Calculate new FSRS values
            read new_stability new_difficulty next_review <<< $(calculate_fsrs "$stability" "$difficulty" "$rating")

            # Update lapse count if rating is 1 (Again)
            if [ "$rating" -eq 1 ]; then
                lapse_count=$((lapse_count + 1))
            fi

            # Mark as mastered if rating is 4 and stability > 30
            mastered=false
            if [ "$rating" -eq 4 ] && (( $(echo "$new_stability > 30" | bc -l) )); then
                mastered=true
                echo "🎉 Question marked as mastered!"
            fi

            # Update record
            WRONG_RECORDS=$(read_wrong_questions)
            UPDATED_RECORDS=$(echo "$WRONG_RECORDS" | jq '
                (.records[] | select(.id == "'$rid'")) |=
                .stability = '$new_stability' |
                .difficulty = '$new_difficulty' |
                .last_review = "'$TODAY'" |
                .next_review = "'$next_review'" |
                .review_count = '$((review_count + 1))' |
                .lapse_count = '$lapse_count' |
                .mastered = '$mastered'
            ')
            write_wrong_questions "$UPDATED_RECORDS"

            index=$((index + 1))
            echo
            echo "Press Enter to continue..."
            read -rs
        done

        clear
        echo "✅ Review session completed!"
        echo "=============================================="
        echo "Reviewed $LIMIT questions"
        echo "Use '/learn wrongbook list' to see updated progress"
        ;;

    "export")
        if [ -z "$OUTPUT" ]; then
            echo "Error: Output path is required for export action"
            exit 1
        fi

        RECORDS=$(read_wrong_questions | jq '.records')
        if [ -n "$BANK_ID" ]; then
            RECORDS=$(echo "$RECORDS" | jq 'map(select(.bank_id == "'$BANK_ID'"))')
        fi

        # Add question details to export
        EXPORT_DATA=$(echo "$RECORDS" | jq 'map({
            id: .id,
            question_id: .question_id,
            bank_id: .bank_id,
            user_answer: .user_answer,
            error_reason: .error_reason,
            mastered: .mastered,
            next_review: .next_review,
            review_count: .review_count
        })')

        echo "$EXPORT_DATA" | jq '.' > "$OUTPUT"
        echo "✅ Wrong questions exported to: $OUTPUT"
        ;;

    "clear")
        echo "⚠️  This will delete all wrong question records!"
        read -p "Are you sure? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            write_wrong_questions '{"records": [], "version": "1.0"}'
            echo "✅ All wrong question records cleared."
        else
            echo "Operation cancelled."
        fi
        ;;

    "mark-mastered")
        if [ -z "$QUESTION_ID" ]; then
            echo "Error: Question ID is required for mark-mastered action"
            exit 1
        fi

        WRONG_RECORDS=$(read_wrong_questions)
        UPDATED_RECORDS=$(echo "$WRONG_RECORDS" | jq '
            (.records[] | select(.question_id == "'$QUESTION_ID'")) |=
            .mastered = true
        ')
        write_wrong_questions "$UPDATED_RECORDS"
        echo "✅ Question marked as mastered."
        ;;

    *)
        echo "Error: Invalid action. Available actions: list, review, export, clear, mark-mastered"
        exit 1
        ;;
esac

exit 0
