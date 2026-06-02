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

register_body="{\"deviceToken\":\"$device_token\",\"key\":\"$device_key\"}"
push_body="{\"device_key\":\"$device_key\",\"title\":\"$escaped_title\",\"body\":\"$escaped_body\",\"url\":\"webbridgekit://open?url=https%3A%2F%2Fexample.com\"}"
test_body="{\"device_key\":\"test\",\"title\":\"$escaped_title\",\"body\":\"$escaped_body\"}"
command_body="{\"type\":\"plainText\",\"data\":\"public command ${timestamp}\"}"

echo "Verifying shanbox backend: $BASE_URL"

expect_status "Health" "GET" "/health" "200"
expect_status "Stats" "GET" "/api/v1/stats" "200"
expect_status "Manifest list" "GET" "/api/v1/manifests" "200"
expect_status "Register fake device" "POST" "/register" "200" "$register_body"
expect_status "JSON push route" "POST" "/push" "200" "$push_body"
expect_status "Test push endpoint" "POST" "/test" "200" "$test_body"
expect_status "Command generation" "POST" "/api/v1/commands" "200" "$command_body"
expect_status "Bark compatible GET" "GET" "/test_resources/Codex/route%20check" "200"

expect_unavailable_status "Node admin console" "GET" "/admin" "404"
expect_unavailable_status "Node admin push console" "GET" "/admin-push" "404"
expect_unavailable_status "Node websocket status" "GET" "/ws/status" "404"
expect_unavailable_status "Node messages API" "GET" "/messages" "404"
expect_unavailable_status "Node packages API" "GET" "/packages" "404"

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
    echo "- Node admin routes are tracked as unavailable because the public shanbox host currently serves the Swift backend, not \`Server/node/server.js\`."
} >"$REPORT"

echo "Report: $REPORT"
echo "Summary: $PASS passed, $FAIL failed, $UNAVAILABLE unavailable/needs deployment."

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
