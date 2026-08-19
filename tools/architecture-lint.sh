#!/bin/bash
set -euo pipefail

MODE="${1:-check}"
CI_MODE=false
[[ "${1:-}" == "--ci" ]] && CI_MODE=true

cd "$(dirname "$0")/.."

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo "╔══════════════════════════════════════════╗"
echo "║  Architecture Lint                       ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Rule 1: File size limits (500 ERROR, 300 WARNING) — ratchet baseline.
# Oversized files grandfathered in tools/architecture-lint-baseline.txt are
# tolerated at their recorded size but fail the moment they GROW; new files
# must satisfy the limit outright. Shrink a file below 500 and remove its
# baseline entry to tighten the ratchet.
BASELINE_FILE="$(dirname "$0")/architecture-lint-baseline.txt"

echo "📋 Rule 1: File size limits (300w / 500e)"
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    lines=$(wc -l < "$file" | tr -d ' ')
    if [ "$lines" -gt 500 ]; then
        allowed=$(awk -v f="$file" '$1==f {print $2}' "$BASELINE_FILE" 2>/dev/null)
        allowed=${allowed:-0}
        if [ "$lines" -le "$allowed" ]; then
            echo -e "  ${YELLOW}DEBT${NC}  $file has ${lines} lines (baseline $allowed, do not grow)"
        else
            echo -e "  ${RED}ERROR${NC} $file has ${lines} lines (baseline $allowed / max 500)"
            ((ERRORS++)) || true
        fi
    elif [ "$lines" -gt 300 ]; then
        echo -e "  ${YELLOW}WARN${NC}  $file has ${lines} lines (consider splitting, soft max 300)"
        ((WARNINGS++)) || true
    fi
done < <(find Sources/ SuperApp/Sources/ -name "*.swift" \
    ! -name "*Tests.swift" ! -name "*Test*.swift" 2>/dev/null || true)
echo ""

# Rule 2: Force unwrap in production code
echo "📋 Rule 2: Force unwrap (!) in production code"
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        echo -e "  ${YELLOW}WARN${NC}  $file:$match"
        ((WARNINGS++)) || true
    done < <(grep -n '[a-zA-Z)]!' "$file" 2>/dev/null \
        | grep -v '// ' \
        | grep -v 'fatalError\|preconditionFailure\|assertionFailure\|XCTAssert\|\.toggle()\|@IBOutlet\|unwrapped\|!' \
        || true)
done < <(find Sources/ SuperApp/Sources/ -name "*.swift" \
    ! -name "*Tests.swift" ! -name "*Test*.swift" 2>/dev/null || true)
echo ""

# Rule 3: sleep() in test files — ratcheted per file against
# tools/architecture-lint-sleep-baseline.txt: existing counts are DEBT (do
# not grow), anything above a file's baseline or new files with sleeps fail.
SLEEP_BASELINE="$(dirname "$0")/architecture-lint-sleep-baseline.txt"
echo "📋 Rule 3: sleep() in test files"
sleep_count=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    allowed=$(awk -v f="$file" '$1==f {print $2}' "$SLEEP_BASELINE" 2>/dev/null)
    allowed=${allowed:-0}
    current=$(grep -c 'sleep(' "$file" 2>/dev/null | grep -v '// ' || echo 0)
    current=${current:-0}
    if [ "$current" -gt 0 ]; then
        if [ "$current" -le "$allowed" ]; then
            echo -e "  ${YELLOW}DEBT${NC}  $file has $current sleep() calls (baseline $allowed, do not grow)"
        else
            while IFS= read -r match; do
                [[ -z "$match" ]] && continue
                echo -e "  ${RED}ERROR${NC} $file:$match (use XCTExpectation instead)"
                ((ERRORS++)) || true
                ((sleep_count++)) || true
            done < <(grep -n 'sleep(' "$file" 2>/dev/null | grep -v '// ' || true)
        fi
    fi
done < <(find Tests/ SuperAppUITests/ -name "*.swift" 2>/dev/null || true)
[[ "$sleep_count" -eq 0 ]] && echo "  ${GREEN}OK${NC}   No NEW sleep() debt (ratchet baseline active)"
echo ""

# Rule 4: XCTSkip without reason
echo "📋 Rule 4: XCTSkip without reason"
skip_issues=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        echo -e "  ${YELLOW}WARN${NC}  $file:$match (XCTSkip should have a reason)"
        ((WARNINGS++)) || true
        ((skip_issues++)) || true
    done < <(grep -n 'XCTSkip(' "$file" 2>/dev/null | grep -v 'XCTSkip("' || true)
done < <(find Tests/ SuperAppUITests/ -name "*.swift" 2>/dev/null || true)
[[ "$skip_issues" -eq 0 ]] && echo "  ${GREEN}OK${NC}   All XCTSkip calls have reasons"
echo ""

# Rule 5: import UIKit in non-UI files (Sources/Cache/ Sources/Core/)
echo "📋 Rule 5: import UIKit in Model/Service layer"
uikit_issues=0
for dir in Sources/Cache/ Sources/Core/ Sources/Models/ Sources/Services/; do
    [[ ! -d "$dir" ]] && continue
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            echo -e "  ${YELLOW}WARN${NC}  $file:$match (UIKit in non-UI layer)"
            ((WARNINGS++)) || true
            ((uikit_issues++)) || true
        done < <(grep -n 'import UIKit' "$file" 2>/dev/null || true)
    done < <(find "$dir" -name "*.swift" 2>/dev/null || true)
done
[[ "$uikit_issues" -eq 0 ]] && echo "  ${GREEN}OK${NC}   No UIKit imports in non-UI layers"
echo ""

# Rule 6: TODO/FIXME count
echo "📋 Rule 6: TODO/FIXME count"
todo_count=0
if [[ -d Sources/ ]]; then
    todo_count=$( (grep -rn "TODO\|FIXME" --include="*.swift" Sources/ SuperApp/Sources/ 2>/dev/null || true) | wc -l | tr -d ' ')
fi
echo "  ℹ️  Found ${todo_count} TODO/FIXME items in Sources/ and SuperApp/Sources/"
echo ""

# Rule 7: Large files (>1MB)
echo "📋 Rule 7: Large files (>1MB, excluding .xcassets/.framework/.a)"
large_found=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    echo -e "  ${RED}ERROR${NC} $file (exceeds 1MB)"
    ((ERRORS++)) || true
    ((large_found++)) || true
done < <(find Sources/ SuperApp/ -type f -size +1M 2>/dev/null \
    | grep -v '.xcassets' | grep -v '.framework' | grep -v '.a' || true)
[[ "$large_found" -eq 0 ]] && echo "  ${GREEN}OK${NC}   No large files found"
echo ""

# Rule 8: Handler completion coverage (check for missing completion calls)
echo "📋 Rule 8: Handler completion paths"
handler_issues=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    has_guard_weak=$(grep -c 'guard let self = self' "$file" 2>/dev/null || echo "0")
    has_dealloc_completion=$(grep -c 'managerDeallocated\|completion(.*failure' "$file" 2>/dev/null || echo "0")
    if [[ "$has_guard_weak" -gt 0 && "$has_dealloc_completion" -eq 0 ]]; then
        echo -e "  ${YELLOW}WARN${NC}  $file has [weak self] guard but no deallocated completion"
        ((WARNINGS++)) || true
        ((handler_issues++)) || true
    fi
done < <(find Sources/Handlers/ -name "*.swift" 2>/dev/null || true)
[[ "$handler_issues" -eq 0 ]] && echo "  ${GREEN}OK${NC}   All handlers have proper completion paths"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Errors:   ${RED}${ERRORS}${NC}"
echo -e "  Warnings: ${YELLOW}${WARNINGS}${NC}"
echo -e "  TODOs:    ${todo_count}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo -e "❌ Architecture lint FAILED with ${ERRORS} errors"
    [[ "$CI_MODE" == true ]] && exit 1
else
    echo -e "✅ Architecture lint passed (${WARNINGS} warnings)"
fi
