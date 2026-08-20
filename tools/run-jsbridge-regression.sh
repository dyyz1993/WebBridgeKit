#!/bin/bash
# WebBridgeKit JSBridge regression gate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/jsbridge-regression.md"
mkdir -p "$REPORT_DIR"
cd "$PROJECT_ROOT"

SIMULATOR_ID="${WBK_SIMULATOR_ID:-$(xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' '/Booted/{print $2; exit}')}"
if [ -z "$SIMULATOR_ID" ]; then
    echo "No booted simulator. Boot one before running the JSBridge regression gate." >&2
    exit 1
fi
DESTINATION="id=$SIMULATOR_ID"

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

run_gate "Browser fallback JS" "node tools/verify-webbridge-browser-fallback.js"
run_gate "Services start and verify" "bash scripts/services.sh start && bash scripts/services.sh verify"
run_gate "CoreTests JSBridge" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme CoreTests -sdk iphonesimulator -destination '$DESTINATION' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO -only-testing:CoreTests/WebJavaScriptBridgeTests"
run_gate "BridgeTests" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme BridgeTests -sdk iphonesimulator -destination '$DESTINATION' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO"
# Keep this module gate scoped to handlers used by managed-PWA authorization.
# Cache and other hardware handlers have independent regression gates. The
# smaller project-defined test shards also avoid XCTest losing its host scene
# after hundreds of unrelated UIKit-heavy handler tests in one process.
run_gate "Capability handlers core" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme HandlerTests-Part1 -sdk iphonesimulator -destination '$DESTINATION' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO -only-testing:HandlerTests-Part1/HandlerRegistryTests -only-testing:HandlerTests-Part1/WebBluetoothHandlerTests -only-testing:HandlerTests-Part1/WebClipboardHandlerTests -only-testing:HandlerTests-Part1/SimpleHandlerTests/testClipboardHandler_ReadAction -only-testing:HandlerTests-Part1/SimpleHandlerTests/testClipboardHandler_WriteAction_WithText -only-testing:HandlerTests-Part1/SimpleHandlerTests/testClipboardHandler_WriteAction_WithParamsDict -only-testing:HandlerTests-Part1/SimpleHandlerTests/testClipboardHandler_WriteAction_MissingText_ReturnsError -only-testing:HandlerTests-Part1/SimpleHandlerTests/testClipboardHandler_InvalidAction_ReturnsError -only-testing:HandlerTests-Part1/SimpleHandlerTests/testClipboardHandler_DefaultActionIsRead"
run_gate "Capability handlers permission" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme HandlerTests-Part2 -sdk iphonesimulator -destination '$DESTINATION' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO -only-testing:HandlerTests-Part2/WebPermissionHandlerTests -only-testing:HandlerTests-Part2/WebPermissionStatusHandlerTests -only-testing:HandlerTests-Part2/WebOpenSettingsHandlerTests"

if xcrun simctl list devices booted 2>/dev/null | grep -q "$SIMULATOR_ID"; then
    run_gate "JSBridge UI tests" "xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -destination '$DESTINATION' -derivedDataPath /tmp/wbk-dd-jsbridge CODE_SIGNING_ALLOWED=NO -only-testing:SuperAppUITests/FunctionalTests"
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
