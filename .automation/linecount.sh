#!/usr/bin/env bash
#
# A-5 — Git-based Line Count Helper
#
# Captures precise line counts for AI-generated code before and after manual
# edits, replacing approximate estimates in the Prompt Log's "Lines generated"
# and "Lines retained" fields.
#
# USAGE
#   linecount.sh snapshot <prompt-number>
#   linecount.sh diff     <prompt-number>
#
# WORKFLOW (run once per prompt)
#   1. Accept AI output into the editor and stage the changed files:
#        git add <file(s)>
#   2. Record the generated line count:
#        ./linecount.sh snapshot <N>
#   3. Make manual edits (do not re-stage).
#   4. Produce the final retained count and the pre-filled log entry:
#        ./linecount.sh diff <N>
#      Copy the printed markdown table into the Prompt Log.
#
# MODES
#   snapshot   Counts added lines in the current git index (staged diff),
#              saves them to .codegen_linecount_state.json.
#   diff       Reads the saved snapshot, counts lines removed in the
#              working tree since staging, prints the markdown table,
#              and deletes the state file.
#
# REQUIREMENTS
#   - git  in PATH
#   - jq   in PATH (brew install jq)
#   - Must be run from inside a git working tree
#
# STATE FILE
#   .codegen_linecount_state.json — written by snapshot, consumed and
#   deleted by diff. Do not commit this file.

set -euo pipefail

STATE_FILE=".codegen_linecount_state.json"

usage() {
    echo "Usage: $(basename "$0") <snapshot|diff> <prompt-number>" >&2
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

MODE="$1"
PROMPT_NUMBER="$2"

if ! [[ "$PROMPT_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: prompt-number must be an integer." >&2
    exit 1
fi

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: not inside a git repository. A git working tree is required." >&2
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    echo "Error: jq is required but not found in PATH. Please install jq." >&2
    exit 1
fi

count_added_lines() {
    awk '/^\+/ && !/^\+\+\+/ { count++ } END { print count+0 }'
}

count_removed_lines() {
    awk '/^-/ && !/^---/ { count++ } END { print count+0 }'
}

case "$MODE" in
    snapshot)
        STAGED_FILES_LIST=$(git diff --cached --name-only)
        if [[ -z "$STAGED_FILES_LIST" ]]; then
            echo "No staged changes found. Stage the AI-generated files before running snapshot." >&2
            exit 1
        fi

        LINES_GENERATED=$(git diff --cached --unified=0 | count_added_lines)
        FILE_COUNT=$(echo "$STAGED_FILES_LIST" | wc -l | tr -d ' ')
        STAGED_FILES_JSON=$(echo "$STAGED_FILES_LIST" | jq -R -s 'split("\n") | map(select(length > 0))')

        jq -n \
            --argjson lines_generated "$LINES_GENERATED" \
            --argjson staged_files "$STAGED_FILES_JSON" \
            --arg prompt_number "$PROMPT_NUMBER" \
            '{lines_generated: $lines_generated, staged_files: $staged_files, prompt_number: $prompt_number}' \
            > "$STATE_FILE"

        echo "Snapshot recorded: ${LINES_GENERATED} lines generated across ${FILE_COUNT} files."
        echo "Run '$(basename "$0") diff ${PROMPT_NUMBER}' after edits to complete the entry."
        ;;

    diff)
        if [[ ! -f "$STATE_FILE" ]]; then
            echo "Error: no snapshot found. Run '$(basename "$0") snapshot <prompt-number>' first." >&2
            exit 1
        fi

        LINES_GENERATED=$(jq -r '.lines_generated' "$STATE_FILE")

        LINES_REMOVED=0
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            REMOVED=$(git diff --unified=0 -- "$file" | count_removed_lines)
            LINES_REMOVED=$((LINES_REMOVED + REMOVED))
        done < <(jq -r '.staged_files[]' "$STATE_FILE")

        LINES_RETAINED=$((LINES_GENERATED - LINES_REMOVED))

        echo "| Field | Value |"
        echo "|---|---|"
        echo "| Lines generated (approx.) | ${LINES_GENERATED} |"
        echo "| Lines retained after edits (approx.) | ${LINES_RETAINED} |"

        rm "$STATE_FILE"
        ;;

    *)
        echo "Error: mode must be 'snapshot' or 'diff'." >&2
        usage
        ;;
esac
