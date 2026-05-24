#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=========================================================="
echo "  WebBridgeKit — Design Token Sync"
echo "=========================================================="
echo ""

if [ ! -f "docs/design-tokens.json" ]; then
    echo "ERROR Missing docs/design-tokens.json"
    exit 1
fi

if [ ! -f "docs/design-tokens.schema.json" ]; then
    echo "WARN  Missing docs/design-tokens.schema.json (validation skipped)"
fi

echo "Running sync script..."
if [ -d "tools/TokenGenerators" ]; then
    echo "  Using modular TokenGenerators/ (multi-file compilation)"
    swiftc -parse-as-library \
        tools/TokenGenerators/TokenModel.swift \
        tools/TokenGenerators/SwiftGenerator.swift \
        tools/TokenGenerators/CSSGenerator.swift \
        tools/TokenGenerators/KotlinGenerator.swift \
        tools/TokenGenerators/ValidationReport.swift \
        tools/sync-design-tokens.swift \
        -o /tmp/wbk-token-sync
    /tmp/wbk-token-sync
    rm -f /tmp/wbk-token-sync
else
    echo "  Using single-file mode"
    swift tools/sync-design-tokens.swift
fi

echo ""
echo "Validating JSON against schema..."
if command -v ajv &>/dev/null; then
    ajv validate -s docs/design-tokens.schema.json -d docs/design-tokens.json
elif command -v check-jsonschema &>/dev/null; then
    check-jsonschema --schemafile docs/design-tokens.schema.json docs/design-tokens.json
else
    echo "WARN  No JSON Schema validator found (ajv or check-jsonschema). Schema validation skipped."
fi

echo ""
echo "Token sync complete."
echo "   Source:  docs/design-tokens.json"
echo "   Outputs: Sources/Theme/ThemeTokens.swift"
echo "            docs/prototype/design-tokens.css"
echo "            tools/output/android/ThemeTokens.kt"
echo "            tools/output/android/res/"
