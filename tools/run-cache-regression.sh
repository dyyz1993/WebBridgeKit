#!/bin/bash
# WebBridgeKit cache regression gate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/cache-regression.md"
mkdir -p "$REPORT_DIR"
cd "$PROJECT_ROOT"

# Prefer the booted iPhone so local CI and developer simulators need not share a name.
SIMULATOR_DESTINATION="${WBK_SIMULATOR_DESTINATION:-}"
if [ -z "$SIMULATOR_DESTINATION" ]; then
    SIMULATOR_UDID=$(xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' '/iPhone/ { print $2; exit }')
    if [ -n "$SIMULATOR_UDID" ]; then
        SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
    else
        SIMULATOR_DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro"
    fi
fi

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
run_gate "Strong offline package fixture" "bash tools/verify-strong-offline-package.sh"
run_gate "CacheTests" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme CacheTests -sdk iphonesimulator -destination '$SIMULATOR_DESTINATION' -derivedDataPath /tmp/wbk-dd-cache CODE_SIGNING_ALLOWED=NO"
run_gate "HandlerTests cache" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme HandlerTests -sdk iphonesimulator -destination '$SIMULATOR_DESTINATION' -derivedDataPath /tmp/wbk-dd-cache CODE_SIGNING_ALLOWED=NO -only-testing:HandlerTests/LazyManifestLoaderTests -only-testing:HandlerTests/WebPageCacheHandlerTests"

if xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
    run_gate "Cache UI tests" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -destination '$SIMULATOR_DESTINATION' -derivedDataPath /tmp/wbk-dd-cache CODE_SIGNING_ALLOWED=NO -only-testing:SuperAppUITests/CacheDashboardTests"
else
    ROWS+=("| Cache UI tests | FAIL | No booted simulator |")
    FAIL=$((FAIL + 1))
fi

{
    echo "# Cache Regression Report"
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
