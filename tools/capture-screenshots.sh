#!/bin/bash
# WebBridgeKit UI screenshot capture.
# Usage: bash tools/capture-screenshots.sh [--build]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${WBK_SCREENSHOT_OUTPUT_DIR:-$PROJECT_DIR/build/screenshots/ui-redesign}"
DERIVED_DATA="${WBK_SCREENSHOT_DERIVED_DATA:-/tmp/wbk-dd-screenshots}"
TEST_OUTPUT_DIR="/tmp/wbk-screenshots"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

check_simulator() {
    if ! xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
        err "No booted simulator found. Boot one first:"
        echo "  xcrun simctl boot 'iPhone 16 Pro'"
        exit 1
    fi
    log "Simulator ready: $(xcrun simctl list devices booted | grep Booted | head -1)"
}

set_appearance() {
    xcrun simctl ui booted appearance "$1" 2>/dev/null || true
}

run_capture_test() {
    local test_name="$1"
    local log_path="$PROJECT_DIR/build/reports/screenshot-${test_name}.log"
    mkdir -p "$(dirname "$log_path")"
    log "Running ScreenshotCaptureTests/$test_name..."
    xcodebuild test \
        -workspace "$PROJECT_DIR/WebBridgeKit.xcworkspace" \
        -scheme SuperApp \
        -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
        -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"SuperAppUITests/ScreenshotCaptureTests/$test_name" \
        >"$log_path" 2>&1
}

log "=== WebBridgeKit Screenshot Capture ==="
check_simulator
SIMULATOR_UDID=$(xcrun simctl list devices booted | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p' | head -1)
if [ -z "$SIMULATOR_UDID" ]; then
    err "Unable to resolve booted simulator UDID"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' -delete
EXPECTED_SCREENSHOTS=(
    01-home-light.png 02-inbox-light.png 03-settings-light.png
    04-home-dark.png 05-inbox-dark.png 06-settings-dark.png
)
for name in "${EXPECTED_SCREENSHOTS[@]}"; do
    rm -f "$TEST_OUTPUT_DIR/$name"
done

log "=== Light Mode Screenshots ==="
set_appearance light
run_capture_test "testLightModeScreenshots"

log "=== Dark Mode Screenshots ==="
set_appearance dark
run_capture_test "testDarkModeScreenshots"

set_appearance light
for name in "${EXPECTED_SCREENSHOTS[@]}"; do
    if [ ! -s "$TEST_OUTPUT_DIR/$name" ]; then
        err "Missing screenshot: $TEST_OUTPUT_DIR/$name"
        exit 1
    fi
    cp "$TEST_OUTPUT_DIR/$name" "$OUTPUT_DIR/$name"
done

log "=== Done ==="
log "Screenshots saved to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
