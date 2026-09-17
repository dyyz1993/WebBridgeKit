#!/bin/bash
# Verify Drel self-hosted physical-device readiness without claiming APNs delivery.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/real-device-push-readiness.md"
DERIVED_DATA="/tmp/wbk-dd-device-smoke"
DEVICE_ID="${DEVICE_ID:-}"
BASE_URL="${DREL_SELFHOSTED_BASE_URL:-https://push.drel.app}"

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
    record "Paired iPhone available" "MANUAL" "A TestFlight iPhone need not be USB-paired to this Mac; supply DEVICE_ID only when doing an Xcode smoke test"
fi

run_gate "self-hosted public health and APNs signer" "curl --fail --silent --show-error '$BASE_URL/health' | rg -q '\"status\"[[:space:]]*:[[:space:]]*\"ok\"' && curl --fail --silent --show-error '$BASE_URL/health' | rg -q '\"apnsReady\"[[:space:]]*:[[:space:]]*true'"
run_gate "native self-hosted relay contract" "cd Server/native && env -u GOROOT -u GOTOOLDIR PATH='/usr/local/go/bin:'\"\$PATH\" go test ./... && env -u GOROOT -u GOTOOLDIR PATH='/usr/local/go/bin:'\"\$PATH\" go vet ./..."
run_gate "Drel Store self-hosted boundary" "bash tools/verify-drel-container-only.sh"

if [ -n "$DEVICE_ID" ]; then
    run_gate "Real-device build install launch" "DEVICE_ID='$DEVICE_ID' bash tools/run-real-device-smoke.sh"
else
    record "Real-device build install launch" "MANUAL" "Install the current TestFlight build on a real iPhone; a local USB/Xcode smoke is optional"
fi

BUILD_LOG="$REPORT_DIR/build-for-device.log"

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

if [ -n "$ENTITLEMENTS_PATH" ] &&
   [ -f "$ENTITLEMENTS_PATH" ] &&
   rg -q "aps-environment|com.apple.developer.aps-environment" "$ENTITLEMENTS_PATH"; then
    if [ -f "$BUILD_LOG" ] &&
       rg -q "do not support the Push Notifications capability|doesn't include the Push Notifications capability|doesn't include the aps-environment entitlement" "$BUILD_LOG"; then
        record "Provisioning profile supports Push Notifications" "FAIL" "$BUILD_LOG"
    elif [ -f "$BUILD_LOG" ] && rg -q "\\*\\* BUILD FAILED \\*\\*" "$BUILD_LOG"; then
        record "Provisioning profile supports Push Notifications" "FAIL" "$BUILD_LOG"
    else
        record "Provisioning profile supports Push Notifications" "PASS" "No Push Notifications provisioning rejection found in build log"
    fi
else
    record "Provisioning profile supports Push Notifications" "FAIL" "APNs entitlement is not configured, so provisioning support cannot be proven"
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
    if [ -f "$BUILD_LOG" ]; then
        record "Signed app contains APNs entitlement" "MANUAL" "No local device build was requested; the current TestFlight archive must be checked on the physical acceptance pass"
    else
        record "Signed app contains APNs entitlement" "MANUAL" "No local device build was requested; the current TestFlight archive must be checked on the physical acceptance pass"
    fi
fi

if rg -q "PushNotificationManager\\.shared\\.didRegisterForRemoteNotifications\\(withDeviceToken:[[:space:]]*deviceToken\\)" \
    SuperApp/Sources/AppDelegate.swift; then
    record "APNs token forwarded to PushNotificationManager" "PASS" "SuperApp/Sources/AppDelegate.swift"
else
    record "APNs token forwarded to PushNotificationManager" "FAIL" "AppDelegate receives the APNs token but does not forward it to PushNotificationManager"
fi

if rg -q "https://api\\.drel\\.app" \
    SuperApp/Sources/AppDelegate.swift SuperApp/Sources/Push SuperApp/Sources/Views/TokenPush \
    SuperApp/Sources/Managers/ServerConfigManager.swift SuperApp/Resources; then
    record "Default push server is Drel API" "PASS" "Default server points to https://api.drel.app"
else
    record "Default push server is Drel API" "FAIL" "Default https://api.drel.app URL not found in push UI/config paths"
fi

record "Self-hosted server paired on a TestFlight iPhone" "MANUAL" "Drel → 设置 → 自托管推送; scan/paste a fresh configuration and verify the selected server without recording secrets"
record "Direct APNs foreground/background/lock-screen/tap/exact-once" "MANUAL" "Follow docs/verification/drel-self-hosted-physical-device.md, including a background mode=immersive notification tap"
record "Sender-side encrypted envelope confidentiality" "MANUAL" "Use Server/examples/drel-encrypt-and-push.mjs and confirm the relay/APNs wrapper has no message plaintext"
record "Self-hosted decrypted inbox and source history" "MANUAL" "Verify the decrypted message appears once under the self-hosted source and never leaks into official history"
record "Self-hosted exact revocation" "MANUAL" "Remove the self-hosted server in Drel, then prove the old capability no longer delivers while official push remains independent"

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
