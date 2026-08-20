#!/bin/bash
# Verify the generic, secret-free HTML app gateway contract.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/build/reports"
REPORT="$REPORT_DIR/open-gateway-verification.md"
BASE_URL="${WBK_GATEWAY_URL:-http://127.0.0.1:5800}"
BASE_URL="${BASE_URL%/}"
EXPECTED_PUBLIC_BASE_URL="${WBK_GATEWAY_PUBLIC_URL:-$BASE_URL}"
EXPECTED_PUBLIC_BASE_URL="${EXPECTED_PUBLIC_BASE_URL%/}"
EXPECTED_APP_ID="${WBK_GATEWAY_APP_ID:-com.webbridgekit.fixture.chat}"
PYTHON3="${PYTHON3:-/usr/bin/python3}"
CURL_COMMON=(-sS --connect-timeout 10 --max-time 20)

mkdir -p "$REPORT_DIR"

PASS=0
FAIL=0
ROWS=()

add_row() {
    local name="$1" result="$2" path="$3" expected="$4" actual="$5" evidence="$6"
    ROWS+=("| $name | $result | \`$path\` | $expected | $actual | \`$evidence\` |")
}

request() {
    local method="$1" path="$2" output="$3"
    curl "${CURL_COMMON[@]}" -X "$method" -H 'Content-Type: application/json' \
        -d "${4:-}" -o "$output" -w '%{http_code}' "$BASE_URL$path"
}

check_status() {
    local name="$1" method="$2" path="$3" expected="$4" body="${5:-}"
    local slug output status
    slug="$(printf '%s' "$name" | tr '[:upper:] /' '[:lower:]--' | tr -cd '[:alnum:]-')"
    output="$REPORT_DIR/open-gateway-$slug.json"

    if status="$(request "$method" "$path" "$output" "$body")" && [ "$status" = "$expected" ]; then
        add_row "$name" "PASS" "$method $path" "HTTP $expected" "HTTP $status" "$output"
        PASS=$((PASS + 1))
    else
        status="${status:-curl-error}"
        add_row "$name" "FAIL" "$method $path" "HTTP $expected" "HTTP $status" "$output"
        FAIL=$((FAIL + 1))
    fi
}

check_gateway_document() {
    local output="$REPORT_DIR/open-gateway-configuration.json"
    local status result
    status="$(request GET /api/v1/gateway "$output")"

    if [ "$status" = "200" ] && result="$($PYTHON3 - "$output" "$EXPECTED_PUBLIC_BASE_URL" <<'PY'
import base64
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)

required = ["id", "name", "baseURL", "healthPath", "manifestPath", "publicKeyID", "publicKey"]
for key in required:
    assert isinstance(value.get(key), str) and value[key], f"missing {key}"
assert value["healthPath"].startswith("/"), "healthPath must be absolute"
assert value["manifestPath"].startswith("/"), "manifestPath must be absolute"
assert value["baseURL"].rstrip("/") == sys.argv[2], "advertised baseURL mismatch"
assert "privateKey" not in value and "apiKey" not in value, "gateway response exposes a secret"
padding = "=" * ((4 - len(value["publicKey"]) % 4) % 4)
key_bytes = base64.urlsafe_b64decode(value["publicKey"] + padding)
assert len(key_bytes) == 32, "Ed25519 public key must be 32 bytes"
print(f'{value["id"]}; key={value["publicKeyID"]}; base={value["baseURL"]}')
PY
    )"; then
        add_row "Gateway configuration" "PASS" "GET /api/v1/gateway" "portable public configuration" "$result" "$output"
        PASS=$((PASS + 1))
    else
        result="${result:-HTTP $status or invalid JSON}"
        add_row "Gateway configuration" "FAIL" "GET /api/v1/gateway" "portable public configuration" "$result" "$output"
        FAIL=$((FAIL + 1))
    fi
}

check_manifest_list() {
    local output="$REPORT_DIR/open-gateway-manifests.json"
    local status result
    status="$(request GET /api/v1/html-apps "$output")"

    if [ "$status" = "200" ] && result="$($PYTHON3 - "$output" "$EXPECTED_APP_ID" <<'PY'
import base64
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)

apps = value.get("manifests")
assert isinstance(apps, list) and apps, "manifests must be a non-empty list"
manifest = next((app for app in apps if app.get("appId") == sys.argv[2]), None)
assert manifest is not None, f"missing appId {sys.argv[2]}"
assert manifest.get("schemaVersion") == "1", "schemaVersion mismatch"
assert isinstance(manifest.get("allowedOrigins"), list) and manifest["allowedOrigins"], "missing allowedOrigins"
assert isinstance(manifest.get("routes"), list) and manifest["routes"], "missing routes"
signature = manifest.get("signature")
assert isinstance(signature, dict), "missing signature"
assert signature.get("algorithm") == "ed25519", "signature algorithm mismatch"
assert isinstance(signature.get("keyId"), str) and signature["keyId"], "missing keyId"
encoded = signature.get("value")
assert isinstance(encoded, str) and encoded, "missing signature value"
padding = "=" * ((4 - len(encoded) % 4) % 4)
assert len(base64.urlsafe_b64decode(encoded + padding)) == 64, "Ed25519 signature must be 64 bytes"
print(f'{manifest["appId"]}; routes={len(manifest["routes"])}; signed={signature["keyId"]}')
PY
    )"; then
        add_row "Signed manifest list" "PASS" "GET /api/v1/html-apps" "signed $EXPECTED_APP_ID" "$result" "$output"
        PASS=$((PASS + 1))
    else
        result="${result:-HTTP $status or invalid JSON}"
        add_row "Signed manifest list" "FAIL" "GET /api/v1/html-apps" "signed $EXPECTED_APP_ID" "$result" "$output"
        FAIL=$((FAIL + 1))
    fi
}

rm -f "$REPORT_DIR"/open-gateway-*.json

echo "Verifying open gateway: $BASE_URL"
check_status "Health" GET /health 200
check_gateway_document
check_manifest_list
check_status "Manifest by app ID" GET "/api/v1/html-apps/$EXPECTED_APP_ID" 200
check_status "Anonymous mutation rejected" POST /api/v1/html-apps 401 '{}'

{
    echo "# Open Gateway Verification"
    echo
    echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- Base URL: \`$BASE_URL\`"
    echo "- Expected HTML app: \`$EXPECTED_APP_ID\`"
    echo
    echo "| Check | Result | Request | Expected | Actual | Evidence |"
    echo "|---|---|---|---|---|---|"
    printf '%s\n' "${ROWS[@]}"
    echo
    echo "Summary: $PASS passed, $FAIL failed."
    echo
    echo "This checks the public gateway contract and signed-manifest shape. Cryptographic verification is covered by server tests and the iOS import flow. It does not prove real-device APNs delivery."
} >"$REPORT"

echo "Report: $REPORT"
echo "Summary: $PASS passed, $FAIL failed."

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
