#!/bin/bash
# Drel 1.0 cannot claim Apple's restricted Critical Alerts capability.
set -euo pipefail

SERVER="Server/Sources/WebBridgeServer/Services/APNsService.swift"
CATALOG="SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

if rg -q 'case "critical": return "time-sensitive"' "$SERVER" &&
   ! rg -q '"critical": 1' "$SERVER"; then
  pass "Unsupported critical requests degrade to time-sensitive APNs payloads"
else
  fail "Server can still emit an unapproved critical-alert payload"
fi

if rg -q '#if !DREL_CONTAINER_ONLY' "$CATALOG" &&
   rg -q 'examples\.insert\(criticalExample' "$CATALOG"; then
  pass "Release catalog compiles out the unsupported critical-alert example"
else
  fail "Critical-alert example is not guarded from the Release catalog"
fi

echo "Summary: $PASS passed, $FAIL failed"
test "$FAIL" -eq 0
