#!/bin/bash
# WebBridgeKit JSBridge regression gate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/jsbridge-regression.md"
mkdir -p "$REPORT_DIR"
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
run_gate "CoreTests JSBridge" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme CoreTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO -only-testing:CoreTests/WebJavaScriptBridgeTests"
run_gate "BridgeTests" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme BridgeTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO"
run_gate "HandlerTests bridge" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme HandlerTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO"

if xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
    run_gate "JSBridge UI tests" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO -only-testing:SuperAppUITests/FunctionalTests"
else
    ROWS+=("| JSBridge UI tests | FAIL | No booted simulator |")
    FAIL=$((FAIL + 1))
fi

{
    echo "# JSBridge Regression Report"
    echo ""
    echo "| Gate | Result | Evidence |"
    echo "|---|---|---|"
    printf "%s\n" "${ROWS[@]}"
    echo ""
    echo "Summary: $PASS passed, $FAIL failed"
} >"$REPORT"

echo "Report: $REPORT"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
