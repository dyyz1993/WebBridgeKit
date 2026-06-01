#!/bin/bash
# WebBridgeKit UI v4 regression gate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT_JSON="$REPORT_DIR/ui-v4-regression.json"
REPORT_MD="$REPORT_DIR/ui-v4-regression.md"
mkdir -p "$REPORT_DIR"

PASS=0
FAIL=0
RESULT_ROWS=()
JSON_ROWS=()

record() {
    local name="$1"
    local status="$2"
    local evidence="$3"

    RESULT_ROWS+=("| $name | $status | $evidence |")
    JSON_ROWS+=("{\"name\":\"$name\",\"status\":\"$status\",\"evidence\":\"$(printf '%s' "$evidence" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])')\"}")

    if [ "$status" = "PASS" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
}

run_gate() {
    local name="$1"
    local command="$2"
    local log="$REPORT_DIR/$(echo "$name" | tr '[:upper:] /' '[:lower:]--').log"

    echo "== $name =="
    if bash -lc "$command" >"$log" 2>&1; then
        record "$name" "PASS" "$log"
        echo "PASS"
    else
        record "$name" "FAIL" "$log"
        echo "FAIL ($log)"
    fi
}

cd "$PROJECT_ROOT"

echo "=== WebBridgeKit UI v4 Regression ==="

run_gate "Services start and verify" "bash scripts/services.sh start && bash scripts/services.sh verify"
run_gate "SwiftLint" "swiftlint --quiet"
run_gate "Design lint" "bash tools/ci-lint.sh"
run_gate "Visual static checks" "bash tools/visual-checks.sh"
run_gate "Crash scan" "bash scripts/scan-crash-logs.sh --json | grep '\"total\": 0'"

if xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
    run_gate "Screenshot capture" "bash tools/capture-screenshots.sh --build"
    run_gate "Visual regression" "bash tools/run-visual-regression.sh"
else
    record "Screenshot capture" "FAIL" "No booted simulator"
    record "Visual regression" "FAIL" "Skipped because no booted simulator"
    echo "SKIP screenshot/visual regression: no booted simulator"
fi

{
    echo "{"
    echo "  \"gate\": \"ui-v4-regression\","
    echo "  \"pass\": $PASS,"
    echo "  \"fail\": $FAIL,"
    echo "  \"results\": ["
    local_count=${#JSON_ROWS[@]}
    for i in "${!JSON_ROWS[@]}"; do
        suffix=","
        if [ "$i" -eq $((local_count - 1)) ]; then suffix=""; fi
        echo "    ${JSON_ROWS[$i]}$suffix"
    done
    echo "  ]"
    echo "}"
} >"$REPORT_JSON"

{
    echo "# UI v4 Regression Report"
    echo ""
    echo "| Gate | Result | Evidence |"
    echo "|---|---|---|"
    printf "%s\n" "${RESULT_ROWS[@]}"
    echo ""
    echo "Summary: $PASS passed, $FAIL failed"
} >"$REPORT_MD"

echo "Reports:"
echo "  $REPORT_JSON"
echo "  $REPORT_MD"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
