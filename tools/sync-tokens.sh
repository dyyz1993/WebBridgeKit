#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "╔══════════════════════════════════════════╗"
echo "║  WebBridgeKit — Design Token Sync        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Validate JSON exists
if [ ! -f "docs/design-tokens.json" ]; then
    echo "❌ Missing docs/design-tokens.json"
    exit 1
fi

# Validate schema exists
if [ ! -f "docs/design-tokens.schema.json" ]; then
    echo "⚠️  Missing docs/design-tokens.schema.json (validation skipped)"
fi

# Run sync
echo "Running sync script..."
swift tools/sync-design-tokens.swift

echo ""
echo "Validating JSON against schema..."
if command -v ajv &>/dev/null; then
    ajv validate -s docs/design-tokens.schema.json -d docs/design-tokens.json
elif command -v check-jsonschema &>/dev/null; then
    check-jsonschema --schemafile docs/design-tokens.schema.json docs/design-tokens.json
else
    echo "⚠️  No JSON Schema validator found (ajv or check-jsonschema). Schema validation skipped."
fi

echo ""
echo "✅ Token sync complete."
echo "   Source:  docs/design-tokens.json"
echo "   Outputs: Sources/Theme/ThemeTokens.swift"
echo "           docs/prototype/design-tokens.css"
