#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/wbk-dd}"
LOG_PATH="${LOG_PATH:-/tmp/wbk-build.log}"
BUILD_ARCH="${BUILD_ARCH:-arm64}"

ensure_pods_integrated() {
    if grep -q "Pods_SuperApp.framework" WebBridgeKit.xcodeproj/project.pbxproj \
        && grep -q "Pods_WebBridgeKit.framework" WebBridgeKit.xcodeproj/project.pbxproj; then
        return 0
    fi

    if ! command -v pod >/dev/null 2>&1; then
        echo "[verify-build] CocoaPods integration is missing, and 'pod' is not installed."
        exit 1
    fi

    echo "[verify-build] CocoaPods integration missing; running pod install"
    pod install
}

cd "$PROJECT_ROOT"
ensure_pods_integrated
rm -rf "$DERIVED_DATA_PATH"

echo "[verify-build] Building SuperApp for iOS Simulator"
echo "[verify-build] DerivedData: $DERIVED_DATA_PATH"
echo "[verify-build] Architecture: $BUILD_ARCH"
echo "[verify-build] Log: $LOG_PATH"

if xcodebuild build \
    -workspace WebBridgeKit.xcworkspace \
    -scheme SuperApp \
    -sdk iphonesimulator \
    -arch "$BUILD_ARCH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    > "$LOG_PATH" 2>&1; then
    warning_count=$(grep -c "warning:" "$LOG_PATH" || true)
    echo "BUILD_EXIT_CODE=0"
    echo "WARNINGS=$warning_count"
else
    status=$?
    echo ""
    echo "[verify-build] Build failed. Last 40 log lines:"
    tail -40 "$LOG_PATH" || true
    echo "BUILD_EXIT_CODE=$status"
    exit "$status"
fi
