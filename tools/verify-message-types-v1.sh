#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${WBK_MESSAGE_TYPES_URL:-http://localhost:8080}"
DEVICE_KEY="${WBK_MESSAGE_TYPES_DEVICE_KEY:-test}"
RUN_ID="message-types-$(date +%s)-$$"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wbk-message-types-v1.XXXXXX")"
PASS=0
FAIL=0

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass() {
  PASS=$((PASS + 1))
  echo "PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "FAIL: $1"
}

python3 - "$TMP_DIR" "$DEVICE_KEY" "$RUN_ID" <<'PY'
import json
import pathlib
import sys

directory = pathlib.Path(sys.argv[1])
device_key = sys.argv[2]
run_id = sys.argv[3]
common = {
    "schema": "webbridgekit.message.v1",
    "deviceKey": device_key,
    "title": "Message type contract",
    "body": "Readable fallback body",
}
valid = {
    "plain": {**common, "type": "plain"},
    "markdown": {**common, "type": "markdown", "markdown": "## Result"},
    "image": {**common, "type": "image", "image": "https://example.com/preview.png"},
    "qr": {**common, "type": "qr", "qrPayload": "webbridgekit://login/42"},
    "otp": {**common, "type": "otp", "verificationCode": "482901"},
    "chat": {
        **common,
        "type": "chat",
        "appId": "com.example.team-chat",
        "route": "/conversations/42",
        "params": {"conversationId": "42"},
    },
    "approval": {
        **common,
        "type": "approval",
        "id": run_id,
        "requestId": run_id,
        "revision": 1,
        "state": "pending",
        "presentation": "native",
        "approval": {
            "actions": [
                {"id": "approve", "title": "Approve", "style": "primary", "resultState": "approved"}
            ],
            "responseMode": "poll",
        },
    },
}
invalid = {
    "markdown": {**common, "type": "markdown"},
    "image": {**common, "type": "image"},
    "qr": {**common, "type": "qr"},
    "otp": {**common, "type": "otp"},
    "chat": {**common, "type": "chat"},
    "raw-html": {**common, "type": "plain", "html": "<button>Run</button>"},
}
for group, fixtures in (("valid", valid), ("invalid", invalid)):
    target = directory / group
    target.mkdir()
    for name, payload in fixtures.items():
        (target / f"{name}.json").write_text(json.dumps(payload), encoding="utf-8")
PY

if python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
import json
import pathlib
import sys
import jsonschema

root = pathlib.Path(sys.argv[1])
fixtures = pathlib.Path(sys.argv[2])
schema = json.loads((root / "docs/api/schemas/message-v1.schema.json").read_text())
validator = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
for path in sorted((fixtures / "valid").glob("*.json")):
    validator.validate(json.loads(path.read_text()))
for path in sorted((fixtures / "invalid").glob("*.json")):
    errors = list(validator.iter_errors(json.loads(path.read_text())))
    if not errors:
        raise SystemExit(f"expected schema rejection: {path.name}")
PY
then
  pass "schema accepts 7 valid types and rejects incomplete fixtures"
else
  fail "message type schema validation"
fi

if curl --silent --fail "$BASE_URL/health" > "$TMP_DIR/health.json"; then
  pass "message backend is reachable"
else
  fail "message backend is reachable at $BASE_URL"
fi

for FIXTURE in "$TMP_DIR"/valid/*.json; do
  NAME="$(basename "$FIXTURE" .json)"
  STATUS="$(curl --silent --output "$TMP_DIR/$NAME-response.json" --write-out '%{http_code}' \
    --request POST "$BASE_URL/push" --header 'Content-Type: application/json' --data-binary "@$FIXTURE")"
  if [[ "$STATUS" == "200" ]]; then
    pass "$NAME message is accepted"
  else
    fail "$NAME message returned HTTP $STATUS"
  fi
done

for FIXTURE in "$TMP_DIR"/invalid/*.json; do
  NAME="$(basename "$FIXTURE" .json)"
  STATUS="$(curl --silent --output "$TMP_DIR/invalid-$NAME-response.json" --write-out '%{http_code}' \
    --request POST "$BASE_URL/push" --header 'Content-Type: application/json' --data-binary "@$FIXTURE")"
  if [[ "$STATUS" == "400" ]]; then
    pass "invalid $NAME message is rejected"
  else
    fail "invalid $NAME message returned HTTP $STATUS instead of 400"
  fi
done

echo "Summary: $PASS passed, $FAIL failed"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
