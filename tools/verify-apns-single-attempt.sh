#!/bin/bash
# Prevent alert delivery retries that can become delayed duplicate notifications.
set -euo pipefail

SOURCE="Server/Sources/WebBridgeServer/Services/APNsService.swift"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

if ! rg -q 'for _ in 0\.\.\.1' "$SOURCE"; then
  pass "APNs does not retry the same alert request"
else
  fail "APNs still retries the same alert request"
fi

if rg -q 'status == 400, index == 0, hosts\.count > 1' "$SOURCE" &&
   rg -q 'continue' "$SOURCE"; then
  pass "Only explicit primary-host BadDeviceToken can try the alternate environment"
else
  fail "Alternate APNs environment fallback is missing or unsafe"
fi

if rg -q 'not retrying alert' "$SOURCE"; then
  pass "Uncertain or rejected delivery is recorded without a duplicate send"
else
  fail "Non-retry delivery diagnostics are missing"
fi

echo "Summary: $PASS passed, $FAIL failed"
test "$FAIL" -eq 0
