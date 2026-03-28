#!/usr/bin/env bash

set -euo pipefail

VALID_FEATURES=("Catalog" "Detail" "Search" "Watchlist" "Review" "Cross-cutting")

usage() {
    local features
    features=$(IFS=', '; echo "${VALID_FEATURES[*]}")
    echo "Usage: $(basename "$0") <feature> [session-type]" >&2
    echo "  feature:      ${features}" >&2
    echo "  session-type: feature (default), test, both" >&2
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository. Run this script from within an Xcode project directory." >&2
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
BRANCH_LOWER=$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]')

if [[ "$BRANCH_LOWER" =~ (mvvm|viper|tca) ]]; then
    ARCH=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
else
    echo "Error: cannot determine architecture from branch name '$BRANCH'." >&2
    echo "Branch must contain one of: mvvm, viper, tca." >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

FEATURE="$1"
FEATURE_VALID=false
for f in "${VALID_FEATURES[@]}"; do
    if [[ "$f" == "$FEATURE" ]]; then
        FEATURE_VALID=true
        break
    fi
done

if [[ "$FEATURE_VALID" == false ]]; then
    features=$(IFS=', '; echo "${VALID_FEATURES[*]}")
    echo "Error: invalid feature '$FEATURE'." >&2
    echo "Valid features: ${features}" >&2
    exit 1
fi

SESSION_TYPE_ARG="${2:-feature}"
case "$SESSION_TYPE_ARG" in
    feature) SESSION_TYPE="Feature generation" ;;
    test)    SESSION_TYPE="Test generation" ;;
    both)    SESSION_TYPE="Both" ;;
    *)
        echo "Error: invalid session type '$SESSION_TYPE_ARG'. Valid values: feature (default), test, both" >&2
        exit 1
        ;;
esac

OUTPUT_DIR="$(pwd)/.observation-logs"
mkdir -p "$OUTPUT_DIR"

shopt -s nullglob
MATCHING_FILES=("${OUTPUT_DIR}"/*_"${ARCH}"_"${FEATURE}"_session-*.md)
SESSION_NUM=$(( ${#MATCHING_FILES[@]} + 1 ))
shopt -u nullglob

TODAY=$(date +%Y-%m-%d)
OUTPUT_FILE="${OUTPUT_DIR}/${TODAY}_${ARCH}_${FEATURE}_session-${SESSION_NUM}.md"

REPO_ROOT=$(git rev-parse --show-toplevel)
TEMPLATE="${REPO_ROOT}/.templates/codegen_session_log.md"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: template file not found at ${TEMPLATE}" >&2
    exit 1
fi

cp "$TEMPLATE" "$OUTPUT_FILE"

sed -i '' "s/| Date | |/| Date | ${TODAY} |/" "$OUTPUT_FILE"
sed -i '' "s#| Architecture | <!-- MVVM / VIPER / TCA --> |#| Architecture | ${ARCH} |#" "$OUTPUT_FILE"
sed -i '' "s#| Feature(s) covered | <!-- Catalog / Detail / Search / Watchlist / Review / Cross-cutting --> |#| Feature(s) covered | ${FEATURE} |#" "$OUTPUT_FILE"
sed -i '' "s#| Session number | <!-- Sequential per architecture, e.g. 3 of N --> |#| Session number | ${SESSION_NUM} |#" "$OUTPUT_FILE"
sed -i '' "s#| Session type | <!-- Feature generation / Test generation / Both --> |#| Session type | ${SESSION_TYPE} |#" "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
