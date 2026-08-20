#!/bin/bash
# Verify public shanbox static fixture pages used by physical iPhone WebView/cache/JSBridge checks.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
BASE_URL="${WBK_SHANBOX_STATIC_URL:-https://ae8fcb.shanbox.19930810.xyz:8443/test_resources}"
BASE_URL="${BASE_URL%/}"

mkdir -p "$REPORT_DIR"

REPORT="$REPORT_DIR/shanbox-fixtures-verification.md"
ROWS=()
PASSED=0
FAILED=0

slugify() {
    printf "%s" "$1" | tr '/: ?&=#' '--------' | tr -cs 'A-Za-z0-9._-' '-'
}

add_row() {
    local name="$1" result="$2" path="$3" expected="$4" actual="$5" evidence="$6"
    ROWS+=("| $name | $result | \`$path\` | $expected | $actual | \`$evidence\` |")
}

check_url() {
    local name="$1" path="$2" expected_status="$3"
    shift 3
    local markers=()
    local marker_count="$#"
    if [ "$#" -gt 0 ]; then
        markers=("$@")
    fi
    local url="$BASE_URL$path"
    local slug output status marker marker_errors
    slug="$(slugify "$path")"
    output="$REPORT_DIR/shanbox-fixture-$slug.out"
    marker_errors=""

    status="$(curl -k -L -sS --connect-timeout 10 --max-time 30 -o "$output" -w "%{http_code}" "$url" 2>>"$REPORT_DIR/shanbox-fixtures-curl.log" || printf "000")"
    if [ "$status" != "$expected_status" ]; then
        add_row "$name" "FAIL" "$path" "HTTP $expected_status" "HTTP $status" "$output"
        FAILED=$((FAILED + 1))
        return
    fi

    if [ "$marker_count" -gt 0 ]; then
        for marker in "${markers[@]}"; do
            if ! grep -qF "$marker" "$output"; then
                marker_errors="${marker_errors}${marker}; "
            fi
        done
    fi

    if [ -n "$marker_errors" ]; then
        add_row "$name" "FAIL" "$path" "markers present" "missing: $marker_errors" "$output"
        FAILED=$((FAILED + 1))
    else
        add_row "$name" "PASS" "$path" "HTTP $expected_status + markers" "HTTP $status" "$output"
        PASSED=$((PASSED + 1))
    fi
}

rm -f "$REPORT_DIR"/shanbox-fixture-*.out "$REPORT_DIR/shanbox-fixtures-curl.log"

echo "Verifying shanbox static fixtures: $BASE_URL"

check_url "Fixture index" "/index.html" "200" "WebBridgeKit" "测试"
check_url "Bridge hub" "/bridge-hub.html" "200" "WebBridgeKit Bridge 测试中心" "35 个 Bridge Handler"
check_url "Bridge Promise smoke" "/bridge-promise-smoke.html" "200" "Bridge Promise Smoke" "Bridge Smoke Script Ready"
check_url "Cache showcase" "/cache-showcase.html" "200" "Cache Showcase" "WebBridgeKit"
check_url "Engine dashboard" "/engine-dashboard.html" "200" "WebBridgeKit Engine Dashboard" "四引擎状态总览"
check_url "All-in-one tester" "/all-in-one-tester.html" "200" "WebBridgeKit 全功能测试"
check_url "Message showcase" "/message-showcase.html" "200" "Message Engine Showcase" "Hello from WebBridgeKit"
check_url "WebSocket showcase" "/websocket-showcase.html" "200" "WebSocket Engine Showcase" "getSystemInfo"
check_url "Bridge device" "/bridge-device.html" "200" "Bridge 测试 — Device"
check_url "Bridge interaction" "/bridge-interaction.html" "200" "Bridge 测试 — Interaction"
check_url "Bridge cache" "/bridge-cache.html" "200" "Bridge 测试 — Cache"
check_url "Manifest demo" "/manifest_demo.html" "200" "Manifest 配置演示" "\"version\""
check_url "Image cache test" "/image_cache_test.html" "200" "图片缓存测试" "WebBridgeKit 图片缓存"
check_url "WebBridge.js" "/WebBridge.js" "200" "window.WebBridgeKit" "callNative"
check_url "Manifest JSON" "/manifest.json" "200" "\"version\"" "resources"
check_url "CSS resource" "/css/styles.css" "200"
check_url "JS resource" "/js/app.js" "200"
check_url "Image resource" "/images/logo.png" "200"

{
    echo "# shanbox Static Fixture Verification"
    echo ""
    echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- Base URL: \`$BASE_URL\`"
    echo ""
    echo "| Check | Result | Path | Expected | Actual | Evidence |"
    echo "|---|---|---|---|---|---|"
    printf "%s\n" "${ROWS[@]}"
    echo ""
    echo "Summary: $PASSED passed, $FAILED failed."
    echo ""
    echo "Notes:"
    echo "- This verifies public fixture reachability and static content markers for physical-phone WebView/cache/JSBridge testing."
    echo "- It does not prove native Bridge execution, APNs delivery, or offline cache behavior on a physical iPhone."
} > "$REPORT"

echo "Report: $REPORT"
echo "Summary: $PASSED passed, $FAILED failed."

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
