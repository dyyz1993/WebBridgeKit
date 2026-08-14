#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${WBK_APPROVAL_URL:-http://localhost:8080}"
DEVICE_KEY="${WBK_APPROVAL_DEVICE_KEY:-test}"
REQUEST_ID="approval-contract-$(date +%s)-$$"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wbk-approval-v1.XXXXXX")"
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

write_fixtures() {
  python3 - "$TMP_DIR" "$DEVICE_KEY" "$REQUEST_ID" <<'PY'
import json
import pathlib
import sys

directory = pathlib.Path(sys.argv[1])
device_key = sys.argv[2]
request_id = sys.argv[3]

common = {
    "schema": "webbridgekit.message.v1",
    "type": "approval",
    "deviceKey": device_key,
    "id": request_id,
    "requestId": request_id,
    "revision": 1,
    "state": "pending",
    "title": "是否发布生产环境？",
    "body": "版本 2.4.0 已通过测试",
}

native = {
    **common,
    "presentation": "native",
    "approval": {
        "actions": [
            {
                "id": "approve",
                "title": "通过",
                "style": "primary",
                "resultState": "approved",
            },
            {
                "id": "reject",
                "title": "拒绝",
                "style": "destructive",
                "requiresReason": True,
                "resultState": "rejected",
            },
        ],
        "responseMode": "poll",
    },
}

web = {
    **common,
    "id": request_id + "-web",
    "requestId": request_id + "-web",
    "presentation": "web",
    "url": "https://example.com/approvals/42",
    "display": "sheet",
}

pwa = {
    **common,
    "id": request_id + "-pwa",
    "requestId": request_id + "-pwa",
    "presentation": "pwa",
    "appId": "com.example.approvals",
    "route": "/requests/42",
    "params": {"requestId": request_id},
    "display": "sheet",
}

invalid_webhook = {
    **native,
    "id": request_id + "-private",
    "requestId": request_id + "-private",
    "approval": {
        **native["approval"],
        "responseMode": "webhook",
        "responseURL": "https://127.0.0.1/callback",
    },
}

raw_html = {
    "schema": "webbridgekit.message.v1",
    "type": "plain",
    "deviceKey": device_key,
    "title": "Unsupported raw HTML",
    "body": "This must be rejected",
    "html": "<button>Approve</button>",
}

submission = {
    "actionId": "approve",
    "expectedRevision": 1,
    "values": {},
}

for name, value in {
    "native": native,
    "web": web,
    "pwa": pwa,
    "invalid-webhook": invalid_webhook,
    "raw-html": raw_html,
    "submission": submission,
}.items():
    (directory / f"{name}.json").write_text(
        json.dumps(value, ensure_ascii=False), encoding="utf-8"
    )
PY
}

validate_schemas() {
  if python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
import json
import pathlib
import sys

try:
    import jsonschema
except ImportError as error:
    raise SystemExit(f"jsonschema is required: {error}")

root = pathlib.Path(sys.argv[1])
fixtures = pathlib.Path(sys.argv[2])
schema = json.loads((root / "docs/api/schemas/message-v1.schema.json").read_text())
validator = jsonschema.Draft202012Validator(
    schema,
    format_checker=jsonschema.FormatChecker(),
)
for name in ("native", "web", "pwa"):
    payload = json.loads((fixtures / f"{name}.json").read_text())
    errors = sorted(validator.iter_errors(payload), key=lambda item: list(item.path))
    if errors:
        details = "; ".join(error.message for error in errors)
        raise SystemExit(f"{name}: {details}")

submission_schema = json.loads(
    (root / "docs/api/schemas/approval-submission-v1.schema.json").read_text()
)
jsonschema.Draft202012Validator(submission_schema).validate(
    json.loads((fixtures / "submission.json").read_text())
)
PY
  then
    pass "native/web/pwa examples conform to message-v1.schema.json"
  else
    fail "message schema conformance"
  fi
}

schema_conforms() {
  local schema="$1"
  local document="$2"
  python3 - "$schema" "$document" <<'PY'
import json
import sys
import jsonschema

schema = json.loads(open(sys.argv[1], encoding="utf-8").read())
document = json.loads(open(sys.argv[2], encoding="utf-8").read())
jsonschema.Draft202012Validator(
    schema,
    format_checker=jsonschema.FormatChecker(),
).validate(document)
PY
}

assert_json() {
  local file="$1"
  local expression="$2"
  python3 - "$file" "$expression" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
if not eval(sys.argv[2], {"__builtins__": {}}, {"value": payload}):
    raise SystemExit(f"assertion failed: {sys.argv[2]}\npayload={payload}")
PY
}

write_fixtures
validate_schemas

if curl --silent --fail "$BASE_URL/health" > "$TMP_DIR/health.json"; then
  pass "approval backend is reachable"
else
  fail "approval backend is reachable at $BASE_URL"
  echo "Summary: $PASS passed, $FAIL failed"
  exit 1
fi

CREATE_STATUS="$(curl --silent --output "$TMP_DIR/create.json" --write-out '%{http_code}' \
  --request POST "$BASE_URL/push" \
  --header 'Content-Type: application/json' \
  --data-binary "@$TMP_DIR/native.json")"
if [[ "$CREATE_STATUS" == "200" ]]; then
  pass "native approval is accepted by /push"
else
  fail "native approval creation returned HTTP $CREATE_STATUS"
fi

for PRESENTATION in web pwa; do
  ROUTED_STATUS="$(curl --silent --output "$TMP_DIR/$PRESENTATION-response.json" --write-out '%{http_code}' \
    --request POST "$BASE_URL/push" \
    --header 'Content-Type: application/json' \
    --data-binary "@$TMP_DIR/$PRESENTATION.json")"
  if [[ "$ROUTED_STATUS" == "200" ]]; then
    pass "$PRESENTATION approval routing envelope is accepted by /push"
  else
    fail "$PRESENTATION approval routing returned HTTP $ROUTED_STATUS"
  fi
done

POLL_STATUS="$(curl --silent --output "$TMP_DIR/poll.json" --write-out '%{http_code}' \
  "$BASE_URL/api/v1/approvals/$REQUEST_ID" \
  --header "Authorization: Bearer $DEVICE_KEY")"
if [[ "$POLL_STATUS" == "200" ]] \
  && assert_json "$TMP_DIR/poll.json" \
    'value["schema"] == "webbridgekit.approval-status.v1" and value["requestId"] and value["state"] == "pending" and value["revision"] == 1 and "responseURL" not in value' \
  && schema_conforms "$ROOT_DIR/docs/api/schemas/approval-status-v1.schema.json" "$TMP_DIR/poll.json"; then
  pass "official status endpoint returns pending revision without callback secrets"
else
  fail "official pending status contract"
fi

RESPOND_STATUS="$(curl --silent --output "$TMP_DIR/respond.json" --write-out '%{http_code}' \
  --request POST "$BASE_URL/api/v1/approvals/$REQUEST_ID/respond" \
  --header "Authorization: Bearer $DEVICE_KEY" \
  --header 'Content-Type: application/json' \
  --data-binary "@$TMP_DIR/submission.json")"
if [[ "$RESPOND_STATUS" == "200" ]] \
  && assert_json "$TMP_DIR/respond.json" \
    'value["requestId"] and value["state"] == "approved" and value["revision"] == 2 and value["actionId"] == "approve"'; then
  pass "approval response resolves state and increments revision"
else
  fail "approval response contract returned HTTP $RESPOND_STATUS"
fi

FINAL_STATUS="$(curl --silent --output "$TMP_DIR/final.json" --write-out '%{http_code}' \
  "$BASE_URL/api/v1/approvals/$REQUEST_ID" \
  --header "Authorization: Bearer $DEVICE_KEY")"
if [[ "$FINAL_STATUS" == "200" ]] \
  && assert_json "$TMP_DIR/final.json" \
    'value["state"] == "approved" and value["revision"] == 2'; then
  pass "resolved state remains queryable"
else
  fail "resolved status contract"
fi

SECOND_STATUS="$(curl --silent --output "$TMP_DIR/second.json" --write-out '%{http_code}' \
  --request POST "$BASE_URL/api/v1/approvals/$REQUEST_ID/respond" \
  --header "Authorization: Bearer $DEVICE_KEY" \
  --header 'Content-Type: application/json' \
  --data '{"actionId":"reject","expectedRevision":2,"values":{"reason":"late"}}')"
if [[ "$SECOND_STATUS" == "409" ]]; then
  pass "first valid response wins"
else
  fail "second response returned HTTP $SECOND_STATUS instead of 409"
fi

PRIVATE_STATUS="$(curl --silent --output "$TMP_DIR/private.json" --write-out '%{http_code}' \
  --request POST "$BASE_URL/push" \
  --header 'Content-Type: application/json' \
  --data-binary "@$TMP_DIR/invalid-webhook.json")"
if [[ "$PRIVATE_STATUS" == "400" ]]; then
  pass "private webhook destinations are rejected"
else
  fail "private webhook validation returned HTTP $PRIVATE_STATUS instead of 400"
fi

RAW_HTML_STATUS="$(curl --silent --output "$TMP_DIR/raw-html-response.json" --write-out '%{http_code}' \
  --request POST "$BASE_URL/push" \
  --header 'Content-Type: application/json' \
  --data-binary "@$TMP_DIR/raw-html.json")"
if [[ "$RAW_HTML_STATUS" == "400" ]]; then
  pass "raw HTML push content is rejected"
else
  fail "raw HTML validation returned HTTP $RAW_HTML_STATUS instead of 400"
fi

echo "Summary: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
