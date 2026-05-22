#!/bin/bash
# WebBridgeKit CI Lint — runs all design system checks
# Exit 1 if any check fails

set -euo pipefail
cd "$(dirname "$0")/.."
PASS=0
FAIL=0

check() {
    local name="$1"
    local result
    result=$(eval "$2" 2>&1)
    if [ -z "$result" ]; then
        echo "  PASS  $name"
        ((PASS++)) || true
    else
        echo "  FAIL  $name"
        echo "$result" | sed 's/^/         /'
        ((FAIL++)) || true
    fi
}

echo ""
echo "=== CI Design System Lint ==="
echo ""

# 1. Hardcoded colors
check "No hardcoded UIColor(red:)" \
    'rg "UIColor\s*\(\s*red\s*:" Sources/ SuperApp/ --glob "*.swift" -l | grep -v ThemeTokens | grep -v ThemeManager || true'

# 2. System colors
check "No .systemBlue/Red/Gray" \
    'rg "\.systemBlue|\.systemRed|\.systemGray|\.systemGreen" Sources/ SuperApp/ --glob "*.swift" -l || true'

# 3. WKColor
check "No WKColor (deprecated)" \
    'rg "WKColor" Sources/ SuperApp/ --glob "*.swift" -l || true'

# 4. Old API
check "No ThemeColors.current" \
    'rg "ThemeColors\.current" Sources/ SuperApp/ --glob "*.swift" -l || true'

check "No ThemeTypography.current" \
    'rg "ThemeTypography\.current" Sources/ SuperApp/ --glob "*.swift" -l || true'

check "No ThemeSpacing.default" \
    'rg "ThemeSpacing\.default" Sources/ SuperApp/ --glob "*.swift" -l || true'

# 5. Emoji in code (non-comment)
check "No UI emoji in Swift code" \
    'rg -n "[✅❌⚠️🔥🔒🚀🎨📦🔧🧪📊▶️📋🔐]" Sources/ SuperApp/ --glob "*.swift" | grep -v "^\s*//" | grep -v "^\s*\*" || true'

# 6. .opencode tracked by git
check ".opencode not tracked in git" \
    'git ls-files .opencode/ || true'

# 7. Crash logs
check "No crash logs in simulator" \
    'APP_DATA=$(xcrun simctl get_app_container booted com.webbridgekit.superapp data 2>/dev/null); if [ -d "$APP_DATA/Documents/crash_logs" ]; then ls "$APP_DATA/Documents/crash_logs/"*.json 2>/dev/null; fi'

# 8. Token JSON parseable
check "design-tokens.json parseable" \
    'python3 -c "import json; json.load(open(\"docs/design-tokens.json\"))" 2>&1 || echo "FAIL"'

# 9. Deprecated ThemeBadge usage
check "No deprecated ThemeBadge init" \
    'rg "ThemeBadge\(" Sources/ SuperApp/ --glob "*.swift" -l | grep -v "ThemeBadge.swift" | grep -v "ComponentCatalog" | grep -v "Showcase" || true'

# 10. Hardcoded monospacedSystemFont
check "No hardcoded monospacedSystemFont" \
    'rg "monospacedSystemFont" Sources/ SuperApp/ --glob "*.swift" -l | grep -v ThemeTokens || true'

# 11. Hardcoded systemFont
check "No hardcoded UIFont.systemFont" \
    'rg "UIFont\.systemFont\(ofSize:" Sources/ SuperApp/ --glob "*.swift" -l | grep -v ThemeTokens | grep -v ThemeManager | grep -v LucideIcon | grep -v LetterIcon | grep -v ManifestModels || true'

# 12. SF Symbol usage in feature code
check "No SF Symbols in feature code" \
    'rg "UIImage\(systemName:" Sources/ SuperApp/ --glob "*.swift" -l | grep -v ThemeTokens | grep -v ThemeManager | grep -v LucideIcon | grep -v WBK || true'

# 13. Button minimum tap area (height < 40)
check "No buttons with height < 40pt" \
    'rg "height.*equalTo\(([2-3][0-9]|[0-9])\)" Sources/ SuperApp/ --glob "*.swift" -n | grep -i "button\|tap\|click" || true'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
