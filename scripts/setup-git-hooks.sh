#!/bin/bash
# Setup git hooks for WebBridgeKit project

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/git-hooks"
GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

echo "🔗 Installing git hooks..."

mkdir -p "$GIT_HOOKS_DIR"

for hook in "$HOOKS_DIR"/*; do
    hook_name=$(basename "$hook")
    cp "$hook" "$GIT_HOOKS_DIR/$hook_name"
    chmod +x "$GIT_HOOKS_DIR/$hook_name"
    echo "  ✅ $hook_name"
done

echo ""
echo "✅ Git hooks installed successfully!"
echo "   commit-msg: Enforces conventional commit format"
echo "   pre-commit: Runs SwiftLint on staged files"
