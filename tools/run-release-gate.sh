#!/bin/bash
# WebBridgeKit release readiness gate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/release-gate.md"
DERIVED_DATA="/tmp/wbk-dd-release-gate"
ARCHIVE_PATH="/tmp/wbk-release-gate/SuperApp.xcarchive"
SWIFTLINT_BIN="$(command -v swiftlint)"
mkdir -p "$REPORT_DIR" /tmp/wbk-release-gate
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
ROWS=()

run_gate() {
    local name="$1"
    local command="$2"
    local log="$REPORT_DIR/$(echo "$name" | tr '[:upper:] /' '[:lower:]--').log"

    echo "== $name =="
    if bash -lc "$command" >"$log" 2>&1; then
        ROWS+=("| $name | PASS | $log |")
        PASS=$((PASS + 1))
        echo "PASS"
    else
        ROWS+=("| $name | FAIL | $log |")
        FAIL=$((FAIL + 1))
        echo "FAIL ($log)"
    fi
}

run_gate "Services start and verify" "bash scripts/services.sh start && bash scripts/services.sh verify"
run_gate "Deliverable boundaries" "bash tools/verify-deliverable-boundaries.sh"
run_gate "SwiftLint" "'$SWIFTLINT_BIN' --quiet"
run_gate "Design lint" "bash tools/ci-lint.sh"
run_gate "Build Debug" "xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath '$DERIVED_DATA' CODE_SIGNING_ALLOWED=NO"
run_gate "Crash scan" "bash scripts/scan-crash-logs.sh --json | grep '\"total\": 0'"
run_gate "Archive Release" "xcodebuild archive -workspace WebBridgeKit.xcworkspace -scheme SuperApp -archivePath '$ARCHIVE_PATH' -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO SKIP_INSTALL=NO"
run_gate "No Release test HTML" "if [ -d '$ARCHIVE_PATH/Products/Applications/SuperApp.app' ]; then ! find '$ARCHIVE_PATH/Products/Applications/SuperApp.app' -iname '*test*.html' | grep -q .; else exit 1; fi"
run_gate "No DEBUG-only code in Release" "bash tools/verify-release-no-debug.sh '$ARCHIVE_PATH/Products/Applications/SuperApp.app'"

{
    echo "# Release Gate Report"
    echo ""
    echo "| Gate | Result | Evidence |"
    echo "|---|---|---|"
    printf "%s\n" "${ROWS[@]}"
    echo ""
    echo "Summary: $PASS passed, $FAIL failed"
    echo ""
    echo "AppTemplate readiness is verified independently by: bash tools/run-template-gate.sh"
} >"$REPORT"

echo "Report: $REPORT"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
