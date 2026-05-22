#!/bin/bash
# WebBridgeKit Static Visual Checks
# Usage: bash tools/visual-checks.sh
# Checks: UILabel numberOfLines, placeholder text, constraint values, etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
WARN=0
FAIL=0

check_pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
check_warn() { echo "  ⚠️  WARN: $1"; WARN=$((WARN + 1)); }
check_fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "========================================"
echo "  WebBridgeKit Visual Checks"
echo "========================================"
echo ""

# ── 1. UILabel numberOfLines in WBK components ──
echo "── 1. UILabel numberOfLines in WBK components ──"
COMPONENTS=(Sources/Theme/Components/WBK*.swift)
LABEL_ISSUES=0
for f in "${COMPONENTS[@]}"; do
    if [ ! -f "$f" ]; then continue; fi
    UILabelS=$(grep -c 'UILabel()' "$f" 2>/dev/null || true)
    NUM_LINES=$(grep -c 'numberOfLines' "$f" 2>/dev/null || true)
    UILabelS=${UILabelS:-0}
    NUM_LINES=${NUM_LINES:-0}
    if [ "$UILabelS" -gt "$NUM_LINES" ]; then
        LABEL_ISSUES=$((LABEL_ISSUES + 1))
        check_warn "$(basename "$f"): $UILabelS UILabel(s) but $NUM_LINES numberOfLines"
        grep -n 'UILabel()' "$f" | head -5
    fi
done
if [ "$LABEL_ISSUES" -eq 0 ]; then
    check_pass "All WBK components set numberOfLines on UILabels"
fi
echo ""

# ── 2. WBKSearchField placeholder ──
echo "── 2. WBKSearchField placeholder ──"
if grep -q 'placeholder' Sources/Theme/Components/WBKSearchField.swift; then
    DEFAULT=$(grep 'public init(placeholder' Sources/Theme/Components/WBKSearchField.swift | head -1)
    if echo "$DEFAULT" | grep -q '"搜索"'; then
        check_pass "WBKSearchField default placeholder = '搜索'"
    else
        check_warn "WBKSearchField placeholder: $DEFAULT"
    fi
else
    check_fail "WBKSearchField missing placeholder property"
fi
echo ""

# ── 3. WBKListRow height constraints ──
echo "── 3. WBKListRow height constraints ──"
LISTROW_FILE="Sources/Theme/Components/WBKListRow.swift"
if [ -f "$LISTROW_FILE" ]; then
    if grep -q 'make.height.greaterThanOrEqualTo(52)' "$LISTROW_FILE" && \
       grep -q 'make.height.lessThanOrEqualTo(60)' "$LISTROW_FILE"; then
        check_pass "WBKListRow height: 52...60pt (matches ThemeTokens.ComponentContract)"
    else
        MIN_H=$(grep 'height.greaterThanOrEqualTo' "$LISTROW_FILE" | head -1 || echo "not found")
        MAX_H=$(grep 'height.lessThanOrEqualTo' "$LISTROW_FILE" | head -1 || echo "not found")
        check_warn "WBKListRow height constraints: min=$MIN_H max=$MAX_H"
    fi
else
    check_fail "WBKListRow.swift not found"
fi
echo ""

# ── 4. WBKResourceCard height constraints ──
echo "── 4. WBKResourceCard height constraints ──"
RESOURCE_FILE="Sources/Theme/Components/WBKResourceCard.swift"
if [ -f "$RESOURCE_FILE" ]; then
    if grep -q 'ComponentContract.ResourceCard.minHeight' "$RESOURCE_FILE" && \
       grep -q 'ComponentContract.ResourceCard.maxHeight' "$RESOURCE_FILE"; then
        check_pass "WBKResourceCard uses ThemeTokens.ComponentContract (80...140pt)"
    else
        check_warn "WBKResourceCard does not use ComponentContract"
        grep 'height' "$RESOURCE_FILE" | grep -i 'constraint\|snp\|greater\|less' | head -3
    fi
else
    check_fail "WBKResourceCard.swift not found"
fi
echo ""

# ── 5. WBKFilterPill height ──
echo "── 5. WBKFilterPill height ──"
PILL_FILE="Sources/Theme/Components/WBKFilterPill.swift"
if [ -f "$PILL_FILE" ]; then
    if grep -q 'make.height.equalTo(32)' "$PILL_FILE"; then
        check_pass "WBKFilterPill height = 32pt"
    else
        PILL_H=$(grep 'height.equalTo' "$PILL_FILE" | head -1 || echo "not found")
        check_warn "WBKFilterPill height: $PILL_H"
    fi
    INTRINSIC=$(grep 'intrinsicContentSize' "$PILL_FILE" 2>/dev/null | grep 'height: 32' | head -1 || true)
    if [ -n "$INTRINSIC" ]; then
        check_pass "WBKFilterPill intrinsicContentSize height = 32"
    else
        check_warn "WBKFilterPill intrinsicContentSize may not match 32pt"
    fi
else
    check_fail "WBKFilterPill.swift not found"
fi
echo ""

# ── 6. WBKEmptyState action button ──
echo "── 6. WBKEmptyState action button ──"
EMPTY_FILE="Sources/Theme/Components/WBKEmptyState.swift"
if [ -f "$EMPTY_FILE" ]; then
    if grep -q 'actionButton' "$EMPTY_FILE" && grep -q 'onActionTapped' "$EMPTY_FILE"; then
        check_pass "WBKEmptyState has actionButton + onActionTapped callback"
    else
        check_fail "WBKEmptyState missing actionButton or onActionTapped"
    fi
    BTN_H=$(grep 'make.height.equalTo(44)' "$EMPTY_FILE" | head -1 || true)
    if [ -n "$BTN_H" ]; then
        check_pass "WBKEmptyState actionButton height = 44pt (Apple HIG minimum)"
    else
        check_warn "WBKEmptyState actionButton height may not be 44pt"
    fi
else
    check_fail "WBKEmptyState.swift not found"
fi
echo ""

# ── 7. Hardcoded colors check (source files only) ──
echo "── 7. Hardcoded colors in WBK components ──"
VIOLATIONS=0
for f in "${COMPONENTS[@]}"; do
    if [ ! -f "$f" ]; then continue; fi
    BAD=$(grep -n 'UIColor(red:\|UIColor(red :\|\.systemBlue\|\.systemRed\|\.systemGray\|\.label\b' "$f" 2>/dev/null || true)
    if [ -n "$BAD" ]; then
        VIOLATIONS=$((VIOLATIONS + 1))
        check_warn "$(basename "$f") has hardcoded colors:"
        echo "$BAD" | head -3
    fi
done
if [ "$VIOLATIONS" -eq 0 ]; then
    check_pass "No hardcoded system/RGB colors in WBK components"
fi
echo ""

# ── 8. Tab bar height in ThemeTokens ──
echo "── 8. Tab bar height in ThemeTokens ──"
TAB_H=$(grep -i 'tabBar\|tab_bar\|tabbarheight' Sources/Theme/ThemeTokens.swift 2>/dev/null | head -3 || true)
if [ -n "$TAB_H" ]; then
    check_pass "ThemeTokens has tab bar references: $(echo "$TAB_H" | tr '\n' ' ')"
else
    check_warn "No explicit tabBar height in ThemeTokens (uses system default)"
fi
echo ""

# ── Summary ──
echo "========================================"
echo "  Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
