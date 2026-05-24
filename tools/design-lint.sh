#!/bin/bash
set -euo pipefail

DESIGN_LINT_VERSION="1.0.0"

CI_MODE=false
VERBOSE=false
FIX_MODE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ci)       CI_MODE=true ;;
        --verbose)  VERBOSE=true ;;
        --fix)      FIX_MODE=true ;;
        --help|-h)
            echo "Usage: bash tools/design-lint.sh [--ci] [--verbose] [--fix]"
            echo ""
            echo "  --ci       Exit 1 on any ERROR (for CI pipelines)"
            echo "  --verbose  Show files scanned and skip details"
            echo "  --fix      Print suggested fixes (no auto-edit)"
            exit 0
            ;;
    esac
    shift
done

cd "$(dirname "$0")/.."

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
ERROR_FILE_LIST=""

EXEMPT_GLOBS=(--glob '!ThemeTokens.swift' --glob '!ThemeManager.swift' --glob '!*Tests.swift' --glob '!*Test*.swift')

scan_pattern() {
    local pattern="$1"
    local rule="$2"
    local severity="$3"
    shift 3

    local results
    results=$(rg -n "$pattern" Sources/ SuperApp/Sources/ --glob '*.swift' "${EXEMPT_GLOBS[@]}" "$@" 2>/dev/null || true)

    if [ -z "$results" ]; then
        return
    fi

    echo "$results" | while IFS=: read -r file line_num content; do
        [ -z "$file" ] && continue
        local trimmed
        trimmed=$(echo "$content" | sed 's/^[[:space:]]*//')
        [[ "$trimmed" == //* ]] && continue
        [[ "$trimmed" == \** ]] && continue

        local rel="${file#$(pwd)/}"

        if [ "$severity" = "error" ]; then
            echo -e "  ${RED}ERROR${NC} ${CYAN}[$rule]${NC} $rel:$line_num"
            if [ "$VERBOSE" = true ]; then
                echo -e "         ${content:0:120}"
            fi
        else
            echo -e "  ${YELLOW}WARN ${NC} ${CYAN}[$rule]${NC} $rel:$line_num"
            if [ "$VERBOSE" = true ]; then
                echo -e "         ${content:0:120}"
            fi
        fi
    done

    local count
    count=$(echo "$results" | while IFS=: read -r file line_num content; do
        [ -z "$file" ] && continue
        local trimmed
        trimmed=$(echo "$content" | sed 's/^[[:space:]]*//')
        [[ "$trimmed" == //* ]] && continue
        [[ "$trimmed" == \** ]] && continue
        echo 1
    done | wc -l | tr -d ' ')

    if [ "$severity" = "error" ]; then
        ERRORS=$((ERRORS + count))
        echo "$results" | cut -d: -f1 | sort -u | while read -r f; do
            rel="${f#$(pwd)/}"
            ERROR_FILE_LIST="$ERROR_FILE_LIST $rel"
        done
    else
        WARNINGS=$((WARNINGS + count))
    fi
}

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Design System Lint v${DESIGN_LINT_VERSION}                        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Rule 1: Hardcoded Colors ──────────────────────────────────
echo -e "${BOLD}Rule 1: Hardcoded Colors (ERROR)${NC}"
scan_pattern 'UIColor\s*\(\s*red\s*:' 'color:hardcoded-rgba' 'error'
scan_pattern 'UIColor\s*\(\s*hex\s*:' 'color:hex-init' 'error'
scan_pattern '#colorLiteral|colorLiteralColor' 'color:color-literal' 'error'
scan_pattern '\.systemBlue\b|\.systemRed\b|\.systemGreen\b|\.systemOrange\b|\.systemPurple\b|\.systemPink\b|\.systemTeal\b|\.systemIndigo\b|\.systemMint\b|\.systemCyan\b|\.systemBrown\b|\.systemYellow\b' 'color:system-color' 'error'
scan_pattern '(?<!\w)\.label\b(?!\s*=)' 'color:semantic-label' 'error'
scan_pattern '(?<!\w)\.secondaryLabel\b' 'color:semantic-label' 'error'
scan_pattern '(?<!\w)\.tertiaryLabel\b' 'color:semantic-label' 'error'
scan_pattern '\bWKColor\.' 'deprecated:WKColor' 'error'

# ── Rule 2: Deprecated API ────────────────────────────────────
echo ""
echo -e "${BOLD}Rule 2: Deprecated API Usage (ERROR)${NC}"
scan_pattern '\bThemeColors\.' 'deprecated:ThemeColors' 'error'
scan_pattern '\bThemeTypography\.' 'deprecated:ThemeTypography' 'error'
scan_pattern '\bThemeFonts\.' 'deprecated:ThemeFonts' 'error'
scan_pattern '\bThemeSpacing\.' 'deprecated:ThemeSpacing' 'error'
scan_pattern '\bThemeCornerRadius\.' 'deprecated:ThemeCornerRadius' 'error'

# ── Rule 3: Hardcoded Fonts ───────────────────────────────────
echo ""
echo -e "${BOLD}Rule 3: Hardcoded Fonts (WARNING)${NC}"
scan_pattern 'UIFont\.systemFont\(' 'font:hardcoded-system' 'warning'
scan_pattern 'UIFont\.boldSystemFont\(' 'font:hardcoded-system' 'warning'
scan_pattern 'UIFont\.italicSystemFont\(' 'font:hardcoded-system' 'warning'
scan_pattern 'monospacedSystemFont\(ofSize:' 'font:hardcoded-monospace' 'warning'

# ── Rule 4: SF Symbols in Feature Code ────────────────────────
echo ""
echo -e "${BOLD}Rule 4: SF Symbols in Feature Code (WARNING)${NC}"
scan_pattern 'UIImage\(systemName:' 'icon:sf-symbol' 'warning' \
    --glob '!LucideIcon.swift' --glob '!Lucide.swift' --glob '!LetterIcon.swift'

# ── Rule 5: Deprecated ThemeBadge init ────────────────────────
echo ""
echo -e "${BOLD}Rule 5: Deprecated ThemeBadge init (WARNING)${NC}"
scan_pattern 'ThemeBadge\(' 'deprecated:ThemeBadge-init' 'warning' \
    --glob '!ThemeBadge.swift'

# ── Summary ────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${BOLD}Summary${NC}"
echo -e "  ───────"
echo -e "  Errors:   ${RED}${ERRORS}${NC}"
echo -e "  Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ -n "$ERROR_FILE_LIST" ]; then
    echo -e "  ${RED}Files with errors:${NC}"
    echo "$ERROR_FILE_LIST" | tr ' ' '\n' | sort -u | grep -v '^$' | while read -r f; do
        [ -n "$f" ] && echo -e "    - $f"
    done
    echo ""
fi

if [ "$FIX_MODE" = true ] && [ "$ERRORS" -gt 0 ]; then
    echo -e "  ${CYAN}Fix suggestions:${NC}"
    echo -e "    - Replace UIColor(red:...) → ThemeTokens.Color.*"
    echo -e "    - Replace .systemBlue → ThemeTokens.Color.primary"
    echo -e "    - Replace ThemeColors.* → ThemeTokens.Color.*"
    echo -e "    - Replace WKColor.* → ThemeTokens.Color.*"
    echo -e "    - Replace .label → ThemeTokens.Color.text"
    echo -e "    - Replace .secondaryLabel → ThemeTokens.Color.textSecondary"
    echo ""
fi

if [ "$ERRORS" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}Design lint FAILED${NC} — ${ERRORS} error(s) found"
    if [ "$CI_MODE" = true ]; then
        exit 1
    fi
    echo -e "  ${YELLOW}(Run with --ci to fail CI on errors)${NC}"
else
    echo -e "  ${GREEN}${BOLD}Design lint PASSED${NC} — 0 errors, ${WARNINGS} warnings"
fi

echo ""
