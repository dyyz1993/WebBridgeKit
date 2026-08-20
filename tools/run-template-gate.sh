#!/bin/bash
# AppTemplate readiness gate. This is intentionally independent of SuperApp UI.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/template-gate.md"
DERIVED_DATA_DEBUG="/tmp/wbk-template-gate-debug"
DERIVED_DATA_RELEASE="/tmp/wbk-template-gate-release"
SWIFTLINT_BIN="$(command -v swiftlint)"
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

run_gate "Deliverable boundaries" \
    "bash tools/verify-deliverable-boundaries.sh"
run_gate "AppTemplate SwiftLint" \
    "'$SWIFTLINT_BIN' lint --quiet --config .swiftlint-template.yml AppTemplate/Sources/"
run_gate "AppTemplate Debug build" \
    "xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme AppTemplate -sdk iphonesimulator -arch arm64 -configuration Debug -derivedDataPath '$DERIVED_DATA_DEBUG' CODE_SIGNING_ALLOWED=NO"
run_gate "AppTemplate credential scan" \
    "! rg -n -i --glob '*.swift' --glob '*.plist' --glob '*.json' 'test_key|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|BarkChannel\\([^)]*key:[[:space:]]*\"[^\"]+\"|barkDeviceKey:[[:space:]]*\"[^\"]+\"|((api|webhook)[_-]?(key|secret)|apns[_-]?(token|key)|device[_-]?token|private[_-]?key)[[:space:]]*[:=][[:space:]]*\"[^\"[:space:]][^\"]*\"' AppTemplate/Sources"
run_gate "AppTemplate Release surface" \
    "! rg -n 'CacheShowcaseViewController|MessageShowcaseViewController|CommandShowcaseViewController|ThemeShowcaseViewController|DebugPanelViewController' AppTemplate/Sources/TabBarController.swift && xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme AppTemplate -sdk iphonesimulator -arch arm64 -configuration Release -derivedDataPath '$DERIVED_DATA_RELEASE' CODE_SIGNING_ALLOWED=NO"

{
    echo "# AppTemplate Gate Report"
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
