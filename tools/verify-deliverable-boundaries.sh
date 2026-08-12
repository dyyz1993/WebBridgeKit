#!/bin/bash
# Verify that the SDK, starter template, and complete product app stay separate.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0

pass() {
    echo "  PASS  $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  FAIL  $1"
    if [ -n "${2:-}" ]; then
        echo "$2" | sed 's/^/         /'
    fi
    FAIL=$((FAIL + 1))
}

echo ""
echo "=== Deliverable Boundary Verification ==="
echo ""

CREDENTIAL_MATCHES=$(rg -n -i \
    --glob '*.swift' \
    --glob '*.plist' \
    --glob '*.json' \
    'test_key|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|BarkChannel\([^)]*key:[[:space:]]*"[^"]+"|barkDeviceKey:[[:space:]]*"[^"]+"|((api|webhook)[_-]?(key|secret)|apns[_-]?(token|key)|device[_-]?token|private[_-]?key)[[:space:]]*[:=][[:space:]]*"[^"[:space:]][^"]*"' \
    AppTemplate/Sources 2>/dev/null || true)
if [ -z "$CREDENTIAL_MATCHES" ]; then
    pass "AppTemplate contains no literal credentials or private keys"
else
    fail "AppTemplate contains no literal credentials or private keys" "$CREDENTIAL_MATCHES"
fi

if awk '
    /^schemes:/ { in_schemes = 1; next }
    in_schemes && /^[^[:space:]]/ { in_schemes = 0 }
    in_schemes && /^  AppTemplate:$/ { found = 1 }
    END { exit(found ? 0 : 1) }
' project.yml; then
    pass "AppTemplate scheme is declared in project.yml"
else
    fail "AppTemplate scheme is declared in project.yml" "Missing schemes.AppTemplate"
fi

SUPERAPP_TEMPLATE_REFS=$(rg -n \
    'import[[:space:]]+AppTemplate|AppTemplate/Sources' \
    SuperApp/Sources --glob '*.swift' 2>/dev/null || true)
if [ -z "$SUPERAPP_TEMPLATE_REFS" ]; then
    pass "SuperApp does not import AppTemplate sources"
else
    fail "SuperApp does not import AppTemplate sources" "$SUPERAPP_TEMPLATE_REFS"
fi

SDK_PRODUCT_REFS=$(rg -n \
    'import[[:space:]]+SuperApp|SuperApp/Sources' \
    Sources --glob '*.swift' 2>/dev/null || true)
if [ -z "$SDK_PRODUCT_REFS" ]; then
    pass "SDK sources do not import SuperApp product code"
else
    fail "SDK sources do not import SuperApp product code" "$SDK_PRODUCT_REFS"
fi

README_MISSING=()
for term in "WebBridgeKit SDK" "AppTemplate" "SuperApp"; do
    if ! rg -q -F "$term" README.md; then
        README_MISSING+=("$term")
    fi
done
if [ "${#README_MISSING[@]}" -eq 0 ]; then
    pass "README distinguishes SDK, AppTemplate, and SuperApp"
else
    fail "README distinguishes SDK, AppTemplate, and SuperApp" \
        "Missing terms: ${README_MISSING[*]}"
fi

if rg -q -F 'WebBridgeKit.shared.initialize()' README.md AppTemplate/Sources; then
    fail "Starter uses the current SDK bootstrap API" \
        "Replace stale WebBridgeKit.shared.initialize() with WebBridgeKitManager.shared.initialize()"
else
    pass "Starter uses the current SDK bootstrap API"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
