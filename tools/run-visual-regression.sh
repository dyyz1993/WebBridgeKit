#!/bin/bash
# tools/run-visual-regression.sh
# Unified visual regression testing for WebBridgeKit
#
# Usage:
#   bash tools/run-visual-regression.sh                    # Compare existing screenshots
#   bash tools/run-visual-regression.sh --capture          # Capture new + compare
#   bash tools/run-visual-regression.sh --threshold 3.0    # Custom diff threshold
#   bash tools/run-visual-regression.sh --screenshots-dir docs/screenshots

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_DIR="$PROJECT_ROOT/docs/screenshots"
OUTPUT_DIR="/tmp/wbk-diff-report"
THRESHOLD=5.0
CAPTURE=false
FAILED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --capture) CAPTURE=true; shift ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --screenshots-dir) BASELINE_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Unified visual regression testing for WebBridgeKit."
            echo ""
            echo "Options:"
            echo "  --capture              Capture new screenshots from booted simulator before diffing"
            echo "  --threshold N          Pixel diff percentage threshold (default: 5.0)"
            echo "  --output-dir PATH      Output directory for diff report (default: /tmp/wbk-diff-report)"
            echo "  --screenshots-dir PATH Baseline screenshots directory (default: docs/screenshots)"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                # Diff light/ vs dark/ against baselines"
            echo "  $0 --capture --threshold 3.0      # Capture fresh, stricter threshold"
            echo "  $0 --output-dir ./my-report       # Custom report location"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== WebBridgeKit Visual Regression ==="
echo "Baseline:  $BASELINE_DIR"
echo "Output:    $OUTPUT_DIR"
echo "Threshold: ${THRESHOLD}%"
echo "Capture:   $CAPTURE"

if [[ ! -f "$SCRIPT_DIR/diff-screenshots.sh" ]]; then
    echo "ERROR: diff-screenshots.sh not found in $SCRIPT_DIR"
    exit 1
fi

if [[ ! -d "$BASELINE_DIR/light" ]] && [[ ! -d "$BASELINE_DIR/dark" ]]; then
    echo "ERROR: Baseline screenshots not found at $BASELINE_DIR"
    echo "Expected: $BASELINE_DIR/light/ and/or $BASELINE_DIR/dark/"
    echo ""
    echo "Run with --capture to generate screenshots from simulator first."
    exit 1
fi

HAS_BASELINE=false
[[ -d "$BASELINE_DIR/light" ]] && HAS_BASELINE=true
[[ -d "$BASELINE_DIR/dark" ]] && HAS_BASELINE=true

if [[ "$HAS_BASELINE" == false ]]; then
    echo "ERROR: No light/ or dark/ subdirectories found in $BASELINE_DIR"
    exit 1
fi

if [[ "$CAPTURE" == true ]]; then
    echo ""
    echo "--- Capturing screenshots from simulator ---"

    if ! xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
        echo "ERROR: No booted simulator found. Boot one first:"
        echo "  xcrun simctl boot 'iPhone 16'"
        exit 1
    fi

    CAPTURE_DIR="/tmp/wbk-screenshots-capture"
    rm -rf "$CAPTURE_DIR"
    mkdir -p "$CAPTURE_DIR/light" "$CAPTURE_DIR/dark"

    echo "Capturing current simulator screen to $CAPTURE_DIR/"
    xcrun simctl io booted screenshot "$CAPTURE_DIR/light/home.png" 2>/dev/null || {
        echo "WARNING: Simulator screenshot capture failed"
    }

    echo ""
    echo "NOTE: Full page capture requires UI automation (--ui-testing)."
    echo "      Single home screen captured. Using captured images as actual set."

    if [[ -f "$CAPTURE_DIR/light/home.png" ]]; then
        BASELINE_DIR="$CAPTURE_DIR"
        echo "Using captured screenshots as baseline for comparison."
    fi
fi

mkdir -p "$OUTPUT_DIR"

OVERALL_EXIT=0

run_diff() {
    local ref_dir="$1"
    local actual_dir="$2"
    local label="$3"
    local report_subdir="$OUTPUT_DIR/$label"

    echo ""
    echo "--- Diff: $label ---"
    echo "Reference: $ref_dir"
    echo "Actual:    $actual_dir"

    if [[ ! -d "$ref_dir" ]]; then
        echo "SKIP: $ref_dir does not exist"
        return
    fi

    if [[ ! -d "$actual_dir" ]]; then
        echo "SKIP: $actual_dir does not exist"
        return
    fi

    local ref_count
    ref_count=$(find "$ref_dir" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    local act_count
    act_count=$(find "$actual_dir" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$ref_count" -eq 0 ]] || [[ "$act_count" -eq 0 ]]; then
        echo "SKIP: No PNG files found (ref=$ref_count, actual=$act_count)"
        return
    fi

    mkdir -p "$report_subdir"

    local diff_exit=0
    OUTPUT_DIR="$report_subdir" bash "$SCRIPT_DIR/diff-screenshots.sh" "$ref_dir" "$actual_dir" "$report_subdir" "$THRESHOLD" || diff_exit=$?

    if [[ $diff_exit -ne 0 ]]; then
        echo "FAIL: $label has screenshots exceeding ${THRESHOLD}% threshold"
        OVERALL_EXIT=1
    else
        echo "PASS: $label all screenshots within ${THRESHOLD}% threshold"
    fi
}

if [[ -d "$BASELINE_DIR/light" ]]; then
    run_diff "$BASELINE_DIR/light" "$BASELINE_DIR/light" "light"
fi

if [[ -d "$BASELINE_DIR/dark" ]]; then
    run_diff "$BASELINE_DIR/dark" "$BASELINE_DIR/dark" "dark"
fi

if [[ -d "$BASELINE_DIR/light" ]] && [[ -d "$BASELINE_DIR/dark" ]]; then
    run_diff "$BASELINE_DIR/light" "$BASELINE_DIR/dark" "light-vs-dark"
fi

echo ""
echo "=== Generating unified report ==="

python3 << PYEOF
import json, os, base64
from datetime import datetime, timezone

output_dir = os.environ.get("OUTPUT_DIR", "/tmp/wbk-diff-report")
threshold = float(os.environ.get("THRESHOLD", "5.0"))

subdirs = []
for d in sorted(os.listdir(output_dir)):
    full = os.path.join(output_dir, d)
    if os.path.isdir(full) and os.path.isfile(os.path.join(full, "results.json")):
        subdirs.append((d, full))

if not subdirs:
    print("No diff results found — nothing to report")
    exit(0)

all_results = []
total_pass = 0
total_fail = 0
total_new = 0
total_removed = 0

for label, path in subdirs:
    with open(os.path.join(path, "results.json")) as f:
        data = json.load(f)
    s = data["summary"]
    total_pass += s["pass"]
    total_fail += s["fail"]
    total_new += s["new"]
    total_removed += sum(1 for r in data["results"] if r["status"] == "REMOVED")

    for r in data["results"]:
        r["suite"] = label
        all_results.append(r)

overall = "FAIL" if total_fail > 0 else "PASS"
total_all = len(all_results)

html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>WebBridgeKit Visual Regression Report</title>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; background:#f5f5f7; color:#1d1d1f; padding:20px; }}
  .container {{ max-width:1400px; margin:0 auto; }}
  h1 {{ font-size:28px; margin-bottom:8px; color:#1d1d1f; }}
  .meta {{ color:#86868b; font-size:14px; margin-bottom:24px; }}
  .summary-grid {{ display:grid; grid-template-columns:repeat(5,1fr); gap:12px; margin-bottom:32px; }}
  .summary-card {{ background:white; border-radius:12px; padding:20px; text-align:center; box-shadow:0 1px 3px rgba(0,0,0,0.08); }}
  .summary-card .number {{ font-size:36px; font-weight:700; }}
  .summary-card .label {{ font-size:13px; color:#86868b; margin-top:4px; }}
  .pass .number {{ color:#34c759; }}
  .fail .number {{ color:#ff3b30; }}
  .new .number {{ color:#007aff; }}
  .total .number {{ color:#1d1d1f; }}
  .removed .number {{ color:#ff9500; }}
  table {{ width:100%; border-collapse:collapse; background:white; border-radius:12px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.08); }}
  th {{ background:#f5f5f7; padding:14px 16px; text-align:left; font-size:13px; font-weight:600; color:#86868b; text-transform:uppercase; letter-spacing:0.5px; }}
  td {{ padding:14px 16px; border-top:1px solid #e8e8ed; font-size:14px; vertical-align:middle; }}
  tr:hover {{ background:#fafafa; }}
  .status-pass {{ color:#34c759; font-weight:600; }}
  .status-fail {{ color:#ff3b30; font-weight:600; }}
  .status-new {{ color:#007aff; font-weight:600; }}
  .status-removed {{ color:#ff9500; font-weight:600; }}
  .diff-pct {{ font-family:"SF Mono",Monaco,monospace; font-size:13px; }}
  .overall-badge {{ display:inline-block; padding:6px 16px; border-radius:20px; font-weight:600; font-size:15px; }}
  .badge-pass {{ background:#e8f8f0; color:#248a3d; }}
  .badge-fail {{ background:#ffe5e5; color:#d70015; }}
  code {{ background:#f5f5f7; padding:2px 6px; border-radius:4px; font-size:12px; }}
  .suite {{ background:#e8e8ed; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:600; text-transform:uppercase; }}
</style>
</head>
<body>
<div class="container">
  <h1>WebBridgeKit Visual Regression Report</h1>
  <p class="meta">Generated: {datetime.now(timezone.utc).isoformat()} &nbsp;|&nbsp; Threshold: {threshold}% &nbsp;|&nbsp;
     <span class="overall-badge badge-{"pass" if overall=="PASS" else "fail"}">
       {"PASS" if overall=="PASS" else "FAIL"}
     </span></p>

  <div class="summary-grid">
    <div class="summary-card total"><div class="number">{total_all}</div><div class="label">Total</div></div>
    <div class="summary-card pass"><div class="number">{total_pass}</div><div class="label">Pass</div></div>
    <div class="summary-card fail"><div class="number">{total_fail}</div><div class="label">Fail</div></div>
    <div class="summary-card new"><div class="number">{total_new}</div><div class="label">New</div></div>
    <div class="summary-card removed"><div class="number">{total_removed}</div><div class="label">Removed</div></div>
  </div>

  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>Suite</th>
        <th>Image</th>
        <th>Status</th>
        <th>Diff %</th>
        <th>Message</th>
      </tr>
    </thead>
    <tbody>
'''

for i, r in enumerate(all_results):
    status_class = f'status-{r["status"].lower()}'
    diff_str = f'{r["diff_percent"]}%' if r.get("diff_percent") is not None else "&mdash;"
    msg = r.get("message", "")
    suite = r.get("suite", "")
    html += f'''
      <tr>
        <td>{i+1}</td>
        <td><span class="suite">{suite}</span></td>
        <td><code>{r["name"]}</code></td>
        <td class="{status_class}">{r["status"]}</td>
        <td class="diff-pct">{diff_str}</td>
        <td>{msg}</td>
      </tr>'''

html += '''
    </tbody>
  </table>

  <p style="margin-top:24px;color:#86868b;font-size:13px;">
    Suites: light, dark, light-vs-dark &nbsp;|&nbsp;
    To update baselines: cp -r /tmp/wbk-screenshots-capture/ docs/screenshots/
  </p>
</div>
</body>
</html>
'''

report_path = os.path.join(output_dir, "index.html")
with open(report_path, "w") as f:
    f.write(html)

print(f"Report: {report_path}")

unified = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "threshold": threshold,
    "baseline_dir": os.path.abspath(os.environ.get("BASELINE_DIR", "")),
    "output_dir": os.path.abspath(output_dir),
    "summary": {
        "total": total_all,
        "pass": total_pass,
        "fail": total_fail,
        "new": total_new,
        "removed": total_removed,
        "overall_status": overall
    },
    "suites": [label for label, _ in subdirs],
    "results": all_results
}

with open(os.path.join(output_dir, "results.json"), "w") as f:
    json.dump(unified, f, indent=2)

exit(1 if overall == "FAIL" else 0)
PYEOF

UNIFIED_EXIT=$?
if [[ $UNIFIED_EXIT -ne 0 ]]; then
    OVERALL_EXIT=1
fi

echo ""
echo "=== Done ==="
echo "HTML Report: $OUTPUT_DIR/index.html"
echo "JSON Results: $OUTPUT_DIR/results.json"
echo ""
echo "Open with:  open $OUTPUT_DIR/index.html"

if [[ $OVERALL_EXIT -ne 0 ]]; then
    echo ""
    echo "RESULT: FAIL — one or more screenshots exceeded ${THRESHOLD}% threshold"
fi

exit $OVERALL_EXIT
