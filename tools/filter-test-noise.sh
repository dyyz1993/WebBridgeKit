#!/bin/bash
# filter-test-noise.sh — Separate accepted test noise from real failures
# Usage: cat test.log | bash tools/filter-test-noise.sh
#   or:  bash tools/filter-test-noise.sh < test.log
# Exit code = number of real failures found

set -euo pipefail

ACCEPTED_PATTERNS=(
    "is implemented in both"
    "libtool: warning"
    "has no symbols"
    "appintentsmetadataprocessor"
    "Class PodcastPracticeWidget"
    "Class PodcastsCarouselWidget"
    "duplicate symbol"
    "ld: warning"
    " umbrella header"
    "not a consuming node"
    "The canonical "
    "SDK contains new symbols"
    "objc[0-9]*: Class"
)

NOISE_FILE=$(mktemp)
FAILURES_FILE=$(mktemp)
trap 'rm -f "$NOISE_FILE" "$FAILURES_FILE"' EXIT

TOTAL_LINES=0
ACCEPTED_NOISE=0
REAL_FAILURES=0

while IFS= read -r line; do
    TOTAL_LINES=$((TOTAL_LINES + 1))

    IS_NOISE=false
    for pattern in "${ACCEPTED_PATTERNS[@]}"; do
        if [[ "$line" == *"$pattern"* ]]; then
            IS_NOISE=true
            break
        fi
    done

    if [[ "$IS_NOISE" == true ]]; then
        ACCEPTED_NOISE=$((ACCEPTED_NOISE + 1))
        echo "  [noise] $line" >> "$NOISE_FILE"
    elif [[ "$line" == *"error:"* || "$line" == *"failed"* || "$line" == *"FAILED"* || "$line" == *"FAIL "* ]]; then
        REAL_FAILURES=$((REAL_FAILURES + 1))
        echo "$line" >> "$FAILURES_FILE"
    fi
done

if [[ "$REAL_FAILURES" -gt 0 ]]; then
    echo "=== Real Failures ($REAL_FAILURES) ==="
    cat "$FAILURES_FILE"
    echo ""
fi

echo "=== Test Noise Summary ==="
echo "  Total lines processed: $TOTAL_LINES"
echo "  Accepted noise lines:  $ACCEPTED_NOISE"
echo "  Real failures:         $REAL_FAILURES"

if [[ "$REAL_FAILURES" -gt 0 ]]; then
    echo ""
    echo "Status: FAIL ($REAL_FAILURES real issue(s) found)"
else
    echo ""
    echo "Status: PASS (no real failures)"
fi

exit "$REAL_FAILURES"
