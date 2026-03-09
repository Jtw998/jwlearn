#!/bin/bash
# FSRS (Free Spaced Repetition Scheduler) algorithm implementation
# Based on FSRS v4 algorithm

# Default FSRS parameters
w=(0.4 0.6 2.4 5.8 4.93 0.94 0.86 0.01 1.49 0.14 0.94 2.18 0.05 0.34 1.26 0.29 2.61)

# Calculate retrievability
calculate_retrievability() {
    local stability="$1"
    local days_since_review="$2"
    echo "scale=10; e($days_since_review * (1 / $stability) * ln(0.9))" | bc -l
}

# Calculate new stability after review
calculate_new_stability() {
    local old_stability="$1"
    local retrievability="$2"
    local rating="$3"
    local factor

    if [ "$rating" -eq 1 ]; then # Again
        factor="${w[18]:-0.2}"
        factor=${factor:-0.2}
    elif [ "$rating" -eq 2 ]; then # Hard
        factor="${w[19]:-0.8}"
        factor=${factor:-0.8}
    elif [ "$rating" -eq 3 ]; then # Good
        factor="${w[20]:-1.2}"
        factor=${factor:-1.2}
    elif [ "$rating" -eq 4 ]; then # Easy
        factor="${w[21]:-2.0}"
        factor=${factor:-2.0}
    else
        factor=1.0
    fi

    echo "scale=10; $old_stability * (1 + $factor * (pow($retrievability, ${w[4]}) * exp(${w[5]} * (1 - $retrievability)) - 1))" | bc -l
}

# Calculate new difficulty after review
calculate_new_difficulty() {
    local old_difficulty="$1"
    local rating="$2"
    echo "scale=10; $old_difficulty + ${w[6]} * ($rating - 3)" | bc -l
}

# Calculate next interval
calculate_interval() {
    local stability="$1"
    local difficulty="$2"
    local retrievability_target="${w[0]:-0.9}"

    # Calculate interval in days
    echo "scale=0; $stability * ln($retrievability_target) / ln(0.9)" | bc -l | awk '{print int($1+0.5)}'
}

# Update card after review
update_card() {
    local card_file="$1"
    local rating="$2"

    # Read current card data
    local card=$(read_json "$card_file")
    local stability=$(echo "$card" | jq -r '.stability // 1.0')
    local difficulty=$(echo "$card" | jq -r '.difficulty // 5.0')
    local last_review=$(echo "$card" | jq -r '.last_review // ""')
    local reviews=$(echo "$card" | jq -r '.reviews // 0')
    local lapses=$(echo "$card" | jq -r '.lapses // 0')

    # Calculate days since last review
    local days_since=0
    if [ "$last_review" != "" ]; then
        local last_ts=$(date -d "$last_review" +%s)
        local now_ts=$(date +%s)
        days_since=$(( (now_ts - last_ts) / 86400 ))
        days_since=$(( days_since > 0 ? days_since : 0 ))
    fi

    # Calculate retrievability
    local retrievability=$(calculate_retrievability "$stability" "$days_since")

    # Calculate new values
    local new_stability=$(calculate_new_stability "$stability" "$retrievability" "$rating")
    local new_difficulty=$(calculate_new_difficulty "$difficulty" "$rating")
    local new_interval=$(calculate_interval "$new_stability" "$new_difficulty")

    # Ensure interval is at least 1 day
    new_interval=$(( new_interval < 1 ? 1 : new_interval ))

    # Calculate due date
    local due_date=$(date -d "+$new_interval days" +%Y-%m-%d)

    # Update lapses if rating is Again
    if [ "$rating" -eq 1 ]; then
        lapses=$((lapses + 1))
    fi

    # Update card
    local updated_card=$(echo "$card" | jq \
        --argjson stability "$new_stability" \
        --argjson difficulty "$new_difficulty" \
        --arg due "$due_date" \
        --arg last_review "$(get_timestamp)" \
        --argjson reviews $((reviews + 1)) \
        --argjson lapses "$lapses" \
        --argjson interval "$new_interval" \
        '.stability = $stability | .difficulty = $difficulty | .due = $due | .last_review = $last_review | .reviews = $reviews | .lapses = $lapses | .interval = $interval')

    # Write back to file
    write_json "$updated_card" "$card_file"

    echo "$new_interval"
}

# Initialize new card
init_card() {
    local knowledge_id="$1"
    local question="$2"
    local answer="$3"

    local card_id=$(generate_id)
    local card_file="$CARDS_DIR/$card_id.json"

    # Initial values for new card
    local initial_stability="${w[1]:-1.0}"
    local initial_difficulty="${w[2]:-5.0}"
    local initial_interval=1
    local due_date=$(date -d "+$initial_interval days" +%Y-%m-%d)

    local card=$(jq -n \
        --arg id "$card_id" \
        --arg knowledge_id "$knowledge_id" \
        --arg question "$question" \
        --arg answer "$answer" \
        --argjson stability "$initial_stability" \
        --argjson difficulty "$initial_difficulty" \
        --arg due "$due_date" \
        --arg created "$(get_timestamp)" \
        --argjson reviews 0 \
        --argjson lapses 0 \
        --argjson interval "$initial_interval" \
        '{id: $id, knowledge_id: $knowledge_id, question: $question, answer: $answer, stability: $stability, difficulty: $difficulty, due: $due, created: $created, reviews: $reviews, lapses: $lapses, interval: $interval}')

    write_json "$card" "$card_file"
    echo "$card_id"
}

# Get due cards
get_due_cards() {
    local limit="${1:-20}"
    local today=$(date +%Y-%m-%d)
    local due_cards=()

    for card in $(list_cards); do
        local due_date=$(jq -r '.due' "$card" 2>/dev/null || echo "")
        if [ "$due_date" != "" ] && [ "$due_date" \< "$today" ] || [ "$due_date" = "$today" ]; then
            due_cards+=("$card")
        fi
    done

    # Sort by due date (oldest first) and limit
    printf "%s\n" "${due_cards[@]}" | sort | head -n "$limit"
}
