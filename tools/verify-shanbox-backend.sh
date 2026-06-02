#!/bin/bash
# Verify the public shanbox backend routes used by WebBridgeKit.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/shanbox-backend-verification.md"
BASE_URL="${WBK_SHANBOX_URL:-https://wbk.shanbox.19930810.xyz:8443}"
CURL_COMMON=(-k -sS --connect-timeout 10 --max-time 20)

mkdir -p "$REPORT_DIR"

PASS=0
FAIL=0
UNAVAILABLE=0
ROWS=()

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"
}

url_encode() {
    python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

request() {
    local method="$1"
    local path="$2"
    local body="${3:-}"
    local output_file="$4"
    local http_code

    if [ -n "$body" ]; then
        http_code="$(curl "${CURL_COMMON[@]}" -X "$method" "$BASE_URL$path" \
            -H 'Content-Type: application/json' \
            -d "$body" \
            -o "$output_file" \
            -w '%{http_code}')"
    else
        http_code="$(curl "${CURL_COMMON[@]}" -X "$method" "$BASE_URL$path" \
            -o "$output_file" \
            -w '%{http_code}')"
    fi

    printf "%s" "$http_code"
}

expect_json_value() {
    local name="$1"
    local evidence="$2"
    local key="$3"
    local expected="$4"
    local actual

    echo "== $name =="
    if actual="$(python3 - "$evidence" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    value = data
    for part in key.split("."):
        value = value[part]
    if isinstance(value, bool):
        print("true" if value else "false")
    else:
        print(value)
except Exception as error:
    print(f"json-error:{error}")
    sys.exit(1)
PY
    )"; then
        if [ "$actual" = "$expected" ]; then
            add_row "$name" "PASS" "ASSERT" "json.$key" "$expected" "$actual" "$evidence"
            PASS=$((PASS + 1))
            echo "PASS ($key=$actual)"
        else
            add_row "$name" "FAIL" "ASSERT" "json.$key" "$expected" "$actual" "$evidence"
            FAIL=$((FAIL + 1))
            echo "FAIL (expected $key=$expected, got $actual; $evidence)"
        fi
    else
        add_row "$name" "FAIL" "ASSERT" "json.$key" "$expected" "$actual" "$evidence"
        FAIL=$((FAIL + 1))
        echo "FAIL (json assertion error; $evidence)"
    fi
}

add_row() {
    local name="$1"
    local result="$2"
    local method="$3"
    local path="$4"
    local expected="$5"
    local actual="$6"
    local evidence="$7"

    ROWS+=("| $name | $result | \`$method $path\` | $expected | $actual | \`$evidence\` |")
}

expect_status() {
    local name="$1"
    local method="$2"
    local path="$3"
    local expected="$4"
    local body="${5:-}"
    local slug
    local evidence
    local status

    slug="$(echo "$name" | tr '[:upper:] /' '[:lower:]--' | tr -cd '[:alnum:]-')"
    evidence="$REPORT_DIR/shanbox-$slug.json"
    : >"$evidence"

    echo "== $name =="
    if status="$(request "$method" "$path" "$body" "$evidence")"; then
        if [ "$status" = "$expected" ]; then
            add_row "$name" "PASS" "$method" "$path" "$expected" "$status" "$evidence"
            PASS=$((PASS + 1))
            echo "PASS ($status)"
        else
            add_row "$name" "FAIL" "$method" "$path" "$expected" "$status" "$evidence"
            FAIL=$((FAIL + 1))
            echo "FAIL (expected $expected, got $status; $evidence)"
        fi
    else
        add_row "$name" "FAIL" "$method" "$path" "$expected" "curl-error" "$evidence"
        FAIL=$((FAIL + 1))
        echo "FAIL (curl-error; $evidence)"
    fi
}

expect_unavailable_status() {
    local name="$1"
    local method="$2"
    local path="$3"
    local expected="$4"
    local slug
    local evidence
    local status

    slug="$(echo "$name" | tr '[:upper:] /' '[:lower:]--' | tr -cd '[:alnum:]-')"
    evidence="$REPORT_DIR/shanbox-$slug.json"
    : >"$evidence"

    echo "== $name =="
    if status="$(request "$method" "$path" "" "$evidence")"; then
        if [ "$status" = "$expected" ]; then
            add_row "$name" "UNAVAILABLE" "$method" "$path" "$expected" "$status" "$evidence"
            UNAVAILABLE=$((UNAVAILABLE + 1))
            echo "UNAVAILABLE as expected ($status)"
        else
            add_row "$name" "CHECK" "$method" "$path" "$expected" "$status" "$evidence"
            UNAVAILABLE=$((UNAVAILABLE + 1))
            echo "CHECK (expected unavailable status $expected, got $status; $evidence)"
        fi
    else
        add_row "$name" "UNAVAILABLE" "$method" "$path" "$expected" "curl-error" "$evidence"
        UNAVAILABLE=$((UNAVAILABLE + 1))
        echo "UNAVAILABLE (curl-error; $evidence)"
    fi
}

timestamp="$(date +%s)"
device_key="codex-${timestamp}"
device_token="codex-test-token-${timestamp}"
title="Codex"
body_text="route check ${timestamp}"
escaped_title="$(json_escape "$title")"
escaped_body="$(json_escape "$body_text")"
encoded_cn_title="$(url_encode "Codex 中文 标题")"
encoded_cn_body="$(url_encode "route check ${timestamp} / 中文 body")"
encoded_group="$(url_encode "Codex Group")"
encoded_bark_url="$(url_encode "webbridgekit://open?url=https%3A%2F%2Fexample.com%2Ffrom-bark")"

register_body="{\"deviceToken\":\"$device_token\",\"key\":\"$device_key\"}"
push_body="{\"device_key\":\"$device_key\",\"title\":\"$escaped_title\",\"body\":\"$escaped_body\",\"sound\":\"bell\",\"badge\":1,\"icon\":\"https://example.com/icon.png\",\"group\":\"Codex Group\",\"url\":\"webbridgekit://open?url=https%3A%2F%2Fexample.com\",\"copy\":\"copy route check\",\"isArchive\":false}"
test_body="{\"device_key\":\"test\",\"title\":\"$escaped_title\",\"body\":\"$escaped_body\",\"sound\":\"bell\",\"group\":\"Codex Group\",\"url\":\"webbridgekit://open?url=https%3A%2F%2Fexample.com\"}"
command_body="{\"type\":\"plainText\",\"data\":\"public command ${timestamp}\"}"

echo "Verifying shanbox backend: $BASE_URL"

expect_status "Health" "GET" "/health" "200"
expect_status "Stats" "GET" "/api/v1/stats" "200"
expect_status "Manifest list" "GET" "/api/v1/manifests" "200"
expect_status "Register fake device" "POST" "/register" "200" "$register_body"
expect_json_value "Register response code" "$REPORT_DIR/shanbox-register-fake-device.json" "code" "200"
expect_status "JSON push route" "POST" "/push" "200" "$push_body"
expect_json_value "JSON push response code" "$REPORT_DIR/shanbox-json-push-route.json" "code" "200"
expect_status "Test push endpoint" "POST" "/test" "200" "$test_body"
expect_json_value "Test push response success" "$REPORT_DIR/shanbox-test-push-endpoint.json" "success" "true"
expect_status "Command generation" "POST" "/api/v1/commands" "200" "$command_body"
expect_status "Bark compatible GET" "GET" "/test_resources/Codex/route%20check" "200"
expect_json_value "Bark GET response code" "$REPORT_DIR/shanbox-bark-compatible-get.json" "code" "200"
expect_status "Bark compatible POST" "POST" "/test_resources/Codex/post%20route" "200"
expect_json_value "Bark POST response code" "$REPORT_DIR/shanbox-bark-compatible-post.json" "code" "200"
expect_status "Bark encoded query route" "GET" "/test_resources/$encoded_cn_title/$encoded_cn_body?sound=bell&group=$encoded_group&url=$encoded_bark_url" "200"
expect_json_value "Bark encoded query response code" "$REPORT_DIR/shanbox-bark-encoded-query-route.json" "code" "200"

expect_status "Node admin console" "GET" "/admin" "200"
expect_status "Node admin push console" "GET" "/admin-push" "200"
expect_status "Node admin stats API" "GET" "/admin/api/stats" "200"
expect_status "Node admin devices API" "GET" "/admin/api/devices" "200"
expect_status "Node admin commands API" "GET" "/admin/api/commands" "200"
expect_status "Node admin manifests API" "GET" "/admin/api/manifests" "200"
expect_status "Node admin push history API" "GET" "/admin/api/push-history" "200"
expect_status "Node websocket status" "GET" "/ws/status" "200"
expect_status "Node messages API" "GET" "/messages" "200"
expect_status "Node packages API" "GET" "/packages" "200"

{
    echo "# shanbox Backend Verification"
    echo ""
    echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- Base URL: \`$BASE_URL\`"
    echo "- Generated test key: \`$device_key\`"
    echo ""
    echo "| Check | Result | Request | Expected | Actual | Evidence |"
    echo "|---|---|---|---|---|---|"
    printf "%s\n" "${ROWS[@]}"
    echo ""
    echo "Summary: $PASS passed, $FAIL failed, $UNAVAILABLE unavailable/needs deployment."
    echo ""
    echo "Notes:"
    echo "- The fake registration and push checks prove route-level behavior only; they do not prove APNs delivery to a real iPhone."
    echo "- Node admin routes are expected to be publicly reachable on the \`wbk\` shanbox host via the supervised \`webbridge-node-admin\` process and path-based nginx proxy."
} >"$REPORT"

echo "Report: $REPORT"
echo "Summary: $PASS passed, $FAIL failed, $UNAVAILABLE unavailable/needs deployment."

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
