#!/bin/bash
# WebBridgeKit UI Screenshot Capture
# Usage: bash tools/capture-screenshots.sh
# Requires: booted simulator with app installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/docs/screenshots/ui-redesign"
DERIVED_DATA="/tmp/wbk-dd-screenshots"
BUNDLE_ID="com.webbridgekit.superapp"

mkdir -p "$OUTPUT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

check_simulator() {
    if ! xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
        err "No booted simulator found. Boot one first:"
        echo "  xcrun simctl boot 'iPhone 16 Pro'"
        exit 1
    fi
    log "Simulator ready: $(xcrun simctl list devices booted | grep Booted | head -1)"
}

build_and_install() {
    log "Building SuperApp..."
    xcodebuild build \
        -workspace "$PROJECT_DIR/WebBridgeKit.xcworkspace" \
        -scheme SuperApp \
        -sdk iphonesimulator \
        -arch arm64 \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        -quiet 2>&1 | tail -5

    APP=$(find "$DERIVED_DATA" -name "SuperApp.app" -maxdepth 5 | head -1)
    if [ -z "$APP" ]; then
        err "Build failed: SuperApp.app not found"
        exit 1
    fi
    log "Built: $APP"

    log "Installing to simulator..."
    xcrun simctl install booted "$APP"
    log "Installed"
}

capture_screen() {
    local name="$1"
    local path="$OUTPUT_DIR/$name.png"
    xcrun simctl io booted screenshot "$path" 2>/dev/null
    if [ -f "$path" ]; then
        local size
        size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo "0")
        log "Captured: $name.png ($(( size / 1024 ))KB)"
    else
        warn "Failed to capture: $name"
    fi
}

set_appearance() {
    local mode="$1"
    xcrun simctl ui booted appearance "$mode" 2>/dev/null || true
}

launch_app() {
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    xcrun simctl launch booted "$BUNDLE_ID" --ui-testing 2>/dev/null || true
    sleep 3
}

# ── Main ──

log "=== WebBridgeKit Screenshot Capture ==="
check_simulator

if [ "${1:-}" = "--build" ] || [ ! -d "$DERIVED_DATA" ]; then
    build_and_install
fi

# ── Light Mode ──
log "=== Light Mode Screenshots ==="
set_appearance light
launch_app
capture_screen "01-home-light"
sleep 1

# ── Dark Mode ──
log "=== Dark Mode Screenshots ==="
set_appearance dark
sleep 2
launch_app
capture_screen "02-home-dark"
sleep 1

# ── Reset ──
set_appearance light
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true

log "=== Done ==="
log "Screenshots saved to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"

echo ""
echo "For full tab navigation screenshots, run XCUITest:"
echo "  xcodebuild test \\"
echo "    -workspace WebBridgeKit.xcworkspace \\"
echo "    -scheme SuperApp \\"
echo "    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \\"
echo "    -only-testing:SuperAppUITests/ScreenshotCaptureTests"
