#!/bin/bash
# Compare reviewed UI baselines with freshly captured simulator screenshots.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_DIR="$PROJECT_ROOT/docs/screenshots/ui-redesign"
ACTUAL_DIR="$PROJECT_ROOT/build/screenshots/ui-redesign"
OUTPUT_DIR="/tmp/wbk-diff-report"
THRESHOLD="5.0"
CAPTURE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --capture) CAPTURE=true; shift ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --screenshots-dir) BASELINE_DIR="$2"; shift 2 ;;
        --actual-dir) ACTUAL_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--capture] [--threshold N] [--output-dir PATH]"
            echo "          [--screenshots-dir BASELINE] [--actual-dir ACTUAL]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== WebBridgeKit Visual Regression ==="
echo "Baseline:  $BASELINE_DIR"
echo "Actual:    $ACTUAL_DIR"
echo "Output:    $OUTPUT_DIR"
echo "Threshold: ${THRESHOLD}%"

if [[ "$CAPTURE" == true ]]; then
    WBK_SCREENSHOT_OUTPUT_DIR="$ACTUAL_DIR" bash "$SCRIPT_DIR/capture-screenshots.sh" --build
fi

if [[ ! -d "$BASELINE_DIR" ]]; then
    echo "ERROR: Baseline screenshots not found: $BASELINE_DIR"
    exit 1
fi
if [[ ! -d "$ACTUAL_DIR" ]]; then
    echo "ERROR: Actual screenshots not found: $ACTUAL_DIR"
    echo "Run tools/capture-screenshots.sh --build or pass --capture."
    exit 1
fi

baseline_real=$(cd "$BASELINE_DIR" && pwd -P)
actual_real=$(cd "$ACTUAL_DIR" && pwd -P)
if [[ "$baseline_real" == "$actual_real" ]]; then
    echo "ERROR: Baseline and actual screenshot directories must be different"
    exit 1
fi

EXPECTED_SCREENSHOTS=(
    01-home-light.png 02-inbox-light.png 03-settings-light.png
    04-home-dark.png 05-inbox-dark.png 06-settings-dark.png
)
for image in "${EXPECTED_SCREENSHOTS[@]}"; do
    if [[ ! -s "$BASELINE_DIR/$image" ]]; then
        echo "ERROR: Missing baseline screenshot: $image"
        exit 1
    fi
    if [[ ! -s "$ACTUAL_DIR/$image" ]]; then
        echo "ERROR: Missing actual screenshot: $image"
        exit 1
    fi
done

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$OUTPUT_DIR" bash "$SCRIPT_DIR/diff-screenshots.sh" \
    "$BASELINE_DIR" "$ACTUAL_DIR" "$OUTPUT_DIR" "$THRESHOLD"

echo "HTML Report: $OUTPUT_DIR/index.html"
echo "JSON Results: $OUTPUT_DIR/results.json"
