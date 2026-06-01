#!/bin/bash
# WebBridgeKit real-device smoke gate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/real-device-smoke.md"
DERIVED_DATA="/tmp/wbk-dd-device-smoke"
BUNDLE_ID="com.webbridgekit.superapp"
DEVICE_ID="${DEVICE_ID:-}"
mkdir -p "$REPORT_DIR"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
ROWS=()

record() {
    local name="$1"
    local status="$2"
    local evidence="$3"
    ROWS+=("| $name | $status | $evidence |")
    if [ "$status" = "PASS" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
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

if [ -z "$DEVICE_ID" ]; then
    if command -v xcrun >/dev/null 2>&1; then
        DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /connected/ {print $NF; exit}' || true)"
    fi
fi

if [ -z "$DEVICE_ID" ]; then
    record "Device discovery" "FAIL" "Set DEVICE_ID to a connected iPhone UDID"
else
    record "Device discovery" "PASS" "$DEVICE_ID"
    run_gate "Build for device" "xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -destination 'id=$DEVICE_ID' -derivedDataPath '$DERIVED_DATA' -allowProvisioningUpdates"
    APP_PATH="$(find "$DERIVED_DATA" -name 'SuperApp.app' -maxdepth 6 | head -1 || true)"
    if [ -n "$APP_PATH" ]; then
        run_gate "Install device app" "xcrun devicectl device install app --device '$DEVICE_ID' '$APP_PATH'"
        run_gate "Launch device app" "xcrun devicectl device process launch --device '$DEVICE_ID' '$BUNDLE_ID'"
    else
        record "Find device app" "FAIL" "SuperApp.app not found under $DERIVED_DATA"
    fi
fi

{
    echo "# Real Device Smoke Report"
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
