#!/bin/bash
# Verify real-device push/Bark readiness without claiming APNs delivery.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/real-device-push-readiness.md"
DERIVED_DATA="/tmp/wbk-dd-device-smoke"
DEVICE_ID="${DEVICE_ID:-}"

mkdir -p "$REPORT_DIR"
cd "$PROJECT_ROOT"
rm -rf "$DERIVED_DATA"

PASS=0
FAIL=0
MANUAL=0
ROWS=()

record() {
    local name="$1"
    local status="$2"
    local evidence="$3"
    ROWS+=("| $name | $status | $evidence |")
    case "$status" in
        PASS) PASS=$((PASS + 1)) ;;
        FAIL) FAIL=$((FAIL + 1)) ;;
        MANUAL) MANUAL=$((MANUAL + 1)) ;;
    esac
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

if [ -z "$DEVICE_ID" ] && command -v xcrun >/dev/null 2>&1; then
    DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | awk '
        /iPhone/ && $0 !~ /unavailable/ && /(available|connected)/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[A-F0-9-]{36}$/) {
                    print $i
                    exit
                }
            }
        }
    ' || true)"
fi

if [ -n "$DEVICE_ID" ]; then
    record "Paired iPhone available" "PASS" "$DEVICE_ID"
else
    record "Paired iPhone available" "FAIL" "Set DEVICE_ID to an available paired iPhone identifier"
fi

run_gate "shanbox backend routes" "bash tools/verify-shanbox-backend.sh"
run_gate "shanbox backend supervision" "bash tools/verify-shanbox-supervision.sh"

if [ -n "$DEVICE_ID" ]; then
    run_gate "Real-device build install launch" "DEVICE_ID='$DEVICE_ID' bash tools/run-real-device-smoke.sh"
else
    record "Real-device build install launch" "FAIL" "Skipped because no paired iPhone was discovered"
fi

ENTITLEMENTS_PATH="$(
    awk -F': *' '/CODE_SIGN_ENTITLEMENTS:/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        gsub(/^"|"$/, "", $2)
        print $2
        exit
    }' project.yml
)"
if [ -n "$ENTITLEMENTS_PATH" ] &&
   [ -f "$ENTITLEMENTS_PATH" ] &&
   rg -q "aps-environment|com.apple.developer.aps-environment" "$ENTITLEMENTS_PATH"; then
    record "APNs entitlement configured in project" "PASS" "project.yml -> $ENTITLEMENTS_PATH"
else
    record "APNs entitlement configured in project" "FAIL" "project.yml does not point SuperApp to an entitlements file containing aps-environment"
fi

if [ -d "$DERIVED_DATA" ]; then
    APP_PATH="$(find "$DERIVED_DATA" -name 'SuperApp.app' -maxdepth 6 2>/dev/null | head -1 || true)"
else
    APP_PATH=""
fi
if [ -n "$APP_PATH" ]; then
    ENTITLEMENTS_LOG="$REPORT_DIR/real-device-app-entitlements.log"
    if codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS_LOG" 2>&1 &&
       rg -q "aps-environment|com.apple.developer.aps-environment" "$ENTITLEMENTS_LOG"; then
        record "Signed app contains APNs entitlement" "PASS" "$ENTITLEMENTS_LOG"
    else
        record "Signed app contains APNs entitlement" "FAIL" "$ENTITLEMENTS_LOG"
    fi
else
    record "Signed app contains APNs entitlement" "FAIL" "SuperApp.app not found under $DERIVED_DATA"
fi

if rg -q "PushNotificationManager\\.shared\\.didRegisterForRemoteNotifications\\(withDeviceToken:[[:space:]]*deviceToken\\)" \
    SuperApp/Sources/AppDelegate.swift; then
    record "APNs token forwarded to PushNotificationManager" "PASS" "SuperApp/Sources/AppDelegate.swift"
else
    record "APNs token forwarded to PushNotificationManager" "FAIL" "AppDelegate receives the APNs token but does not forward it to PushNotificationManager"
fi

if rg -q "https://wbk\\.shanbox\\.19930810\\.xyz:8443" \
    SuperApp/Sources/Push SuperApp/Sources/Views/TokenPush SuperApp/Resources; then
    record "Default Bark server is shanbox" "PASS" "Default server points to https://wbk.shanbox.19930810.xyz:8443"
else
    record "Default Bark server is shanbox" "FAIL" "Default shanbox Bark server URL not found in push UI/config paths"
fi

record "Notification permission prompt observed on iPhone" "MANUAL" "Open iPhone app -> Push -> 注册推送; verify the iOS notification permission prompt or current permission state"
record "Real APNs device token registered to shanbox" "MANUAL" "After permission allow, verify token state changes to 已注册 and shanbox receives a real token for the configured Bark key"
record "Bark end-to-end notification received" "MANUAL" "Send a Bark-compatible URL to the configured key and confirm the iPhone receives it"
record "Background or lock-screen notification behavior" "MANUAL" "Lock/background the iPhone, send Bark push, confirm delivery and tap routing"

{
    echo "# Real Device Push Readiness"
    echo ""
    echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- Device ID: \`${DEVICE_ID:-not-discovered}\`"
    echo ""
    echo "| Gate | Status | Evidence |"
    echo "|---|---|---|"
    printf "%s\n" "${ROWS[@]}"
    echo ""
    echo "Summary: $PASS passed, $FAIL failed, $MANUAL manual."
    echo ""
    echo "Interpretation:"
    echo "- PASS means the gate is proven automatically."
    echo "- FAIL means the current project/runtime evidence contradicts readiness."
    echo "- MANUAL means the step requires real iPhone UI/notification observation before it can be marked available."
} >"$REPORT"

echo "Report: $REPORT"
echo "Summary: $PASS passed, $FAIL failed, $MANUAL manual."

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
