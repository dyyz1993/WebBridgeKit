#!/bin/bash
# Layered acceptance gate for the official, self-hosted gateway, and strong-offline journeys.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$ROOT/build/reports/next-phase"
REPORT="$ROOT/build/reports/next-phase-acceptance.md"
MODE="core"
if [ "${1:-}" = "--full" ]; then MODE="full"; fi
mkdir -p "$REPORT_DIR"
cd "$ROOT"

PASS=0
FAIL=0
MANUAL=0
ROWS=()

run_required() {
    local id="$1" name="$2" command="$3"
    local log="$REPORT_DIR/$id.log"
    echo "== $name =="
    if bash -lc "$command" >"$log" 2>&1; then
        ROWS+=("| $name | PASS | \`$log\` |")
        PASS=$((PASS + 1))
        echo "PASS"
    else
        ROWS+=("| $name | FAIL | \`$log\` |")
        FAIL=$((FAIL + 1))
        echo "FAIL ($log)"
    fi
}

run_required services "Local services" "bash scripts/services.sh start && bash scripts/services.sh verify"
run_required boundaries "Deliverable boundaries" "bash tools/verify-deliverable-boundaries.sh"
run_required messages "Seven message types" "bash tools/verify-message-types-v1.sh"
run_required approval "Approval consent contract" "bash tools/verify-approval-v1.sh"
run_required offline "Strong offline fixture" "bash tools/verify-strong-offline-package.sh"
run_required gateway "Public gateway contract" "WBK_GATEWAY_URL=https://cloak.xbrowser.dev:5801 bash tools/verify-open-gateway.sh"
run_required server "Server route and persistence tests" "cd Server && swift test"
run_required template "AppTemplate boundary gate" "if grep -q 'Summary: 5 passed, 0 failed' build/reports/template-gate.md 2>/dev/null; then true; else bash tools/run-template-gate.sh; fi"
run_required lint "SwiftLint" "swiftlint --quiet"
run_required design "Design and boundary lint" "bash tools/ci-lint.sh"
run_required crash "Crash scan" "bash scripts/scan-crash-logs.sh --json | grep -Eq '\"total\"[[:space:]]*:[[:space:]]*0'"

if [ "$MODE" = "full" ]; then
    run_required cache "Cache regression" "bash tools/run-cache-regression.sh"
    run_required jsbridge "JSBridge regression" "bash tools/run-jsbridge-regression.sh"
    run_required ui "UI v4 regression" "bash tools/run-ui-v4-regression.sh"
    run_required release "SuperApp release gate" "bash tools/run-release-gate.sh"
fi

ROWS+=("| Real-device APNs delivery | MANUAL | Push-capable paid team, profile, and paired iPhone required |")
MANUAL=$((MANUAL + 1))

{
    echo "# Next Phase Acceptance Script Report"
    echo
    echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- Commit: \`$(git rev-parse HEAD)\`"
    echo "- Mode: \`$MODE\`"
    echo
    echo "| Gate | Result | Evidence |"
    echo "|---|---|---|"
    printf '%s\n' "${ROWS[@]}"
    echo
    echo "Summary: $PASS passed, $FAIL failed, $MANUAL manual"
    echo
    echo "Public route checks do not prove APNs registration, receipt, background, or lock-screen behavior."
} >"$REPORT"

echo "Report: $REPORT"
[ "$FAIL" -eq 0 ]
