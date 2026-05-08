#!/bin/bash
# ============================================================
# UI Fidelity Screenshot Diff Tool
# Usage: ./tools/diff-screenshots.sh <reference_dir> <actual_dir> [output_dir] [threshold]
# Example: ./tools/diff-screenshots.sh docs/ui-fidelity/references build/screenshots/actual
#         ./tools/diff-screenshots.sh refs actual output 5.0
# ============================================================

set -euo pipefail

REFERENCE_DIR="${1:?Usage: diff-screenshots.sh <reference_dir> <actual_dir> [output_dir] [threshold]}"
ACTUAL_DIR="${2:?Usage: diff-screenshots.sh <reference_dir> <actual_dir> [output_dir] [threshold]}"
OUTPUT_DIR="${3:-docs/ui-fidelity/diff-report}"
THRESHOLD="${4:-5}"

mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo "  UI Fidelity Screenshot Diff"
echo "  Reference: $REFERENCE_DIR"
echo "  Actual:    $ACTUAL_DIR"
echo "  Output:    $OUTPUT_DIR"
echo "  Threshold: ${THRESHOLD}%"
echo "============================================"

# Python inline script for image comparison
PYTHON_SCRIPT=$(cat <<'PYEOF'
import sys
import json
import os
import base64
from datetime import datetime, timezone
from PIL import Image, ImageChops, ImageDraw, ImageFont

def compare_images(ref_path, act_path, threshold):
    """Compare two images and return (diff_percent, diff_image, status)."""
    try:
        ref = Image.open(ref_path).convert("RGB")
        act = Image.open(act_path).convert("RGB")
    except Exception as e:
        return None, None, f"ERROR: {e}"

    if ref.size != act.size:
        act = act.resize(ref.size)

    diff = ImageChops.difference(ref, act)
    histogram = diff.histogram()
    total_pixels = ref.size[0] * ref.size[1]

    if total_pixels == 0:
        return 0.0, diff.convert("RGB"), "PASS"

    sum_diff = sum(i * v for i, v in enumerate(histogram))
    diff_pct = (sum_diff / (total_pixels * 255 * 3)) * 100

    # Generate visual diff with red highlight on differences
    diff_img = diff.convert("RGB")
    # Create a red overlay for pixels that differ significantly
    highlight = Image.new("RGBA", ref.size, (255, 0, 0, 0))
    for y in range(ref.size[1]):
        for x in range(ref.size[0]):
            r, g, b = diff.getpixel((x, y))
            if r + g + b > 30:  # Significant difference
                highlight.putpixel((x, y), (255, 0, 0, 100))

    # Composite reference + actual side by side with diff below
    composite = Image.new("RGB", (ref.size[0] * 2, ref.size[1] * 2), (240, 240, 240))
    composite.paste(ref, (0, 0))
    composite.paste(act, (ref.size[0], 0))
    composite.paste(diff_img, (0, ref.size[1]))

    status = "FAIL" if diff_pct > float(threshold) else "PASS"
    return round(diff_pct, 2), composite, status


def main():
    if len(sys.argv) < 5:
        print(json.dumps({"error": "Insufficient arguments"}))
        sys.exit(1)

    ref_dir = sys.argv[1]
    act_dir = sys.argv[2]
    out_dir = sys.argv[3]
    threshold = sys.argv[4]

    os.makedirs(out_dir, exist_ok=True)

    results = []
    actual_files = [f for f in os.listdir(act_dir) if f.lower().endswith(".png")]
    ref_files = set(os.listdir(ref_dir))

    total_pass = 0
    total_fail = 0
    total_new = 0

    for fname in sorted(actual_files):
        act_path = os.path.join(act_dir, fname)
        ref_path = os.path.join(ref_dir, fname)

        entry = {"name": fname}

        if fname not in ref_files:
            entry["status"] = "NEW"
            entry["diff_percent"] = null_val()
            entry["message"] = "No reference image — new screenshot"
            total_new += 1
            # Copy actual as baseline candidate
            import shutil
            shutil.copy2(act_path, os.path.join(out_dir, f"new_{fname}"))
        else:
            diff_pct, diff_img, status = compare_images(ref_path, act_path, threshold)
            entry["status"] = status
            entry["diff_percent"] = diff_pct
            if diff_img:
                diff_img.save(os.path.join(out_dir, f"diff_{fname}"))

            if status == "PASS":
                total_pass += 1
            else:
                total_fail += 1
                entry["message"] = f"Diff {diff_pct}% exceeds threshold {threshold}%"

        results.append(entry)

    # Check for removed references
    for fname in sorted(ref_files - set(actual_files)):
        if fname.lower().endswith(".png"):
            results.append({
                "name": fname,
                "status": "REMOVED",
                "diff_percent": null_val(),
                "message": "Reference exists but no actual screenshot"
            })

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "threshold": float(threshold),
        "reference_dir": os.path.abspath(ref_dir),
        "actual_dir": os.path.abspath(act_dir),
        "summary": {
            "total": len(results),
            "pass": total_pass,
            "fail": total_fail,
            "new": total_new,
            "overall_status": "FAIL" if total_fail > 0 else "PASS"
        },
        "results": results
    }

    report_path = os.path.join(out_dir, "results.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    print(json.dumps(report))
    sys.exit(1 if total_fail > 0 else 0)


def null_val():
    return None


if __name__ == "__main__":
    main()
PYEOF
)

echo ""
echo "--- Comparing screenshots ---"

# Run Python comparison
python3 -c "$PYTHON_SCRIPT" "$REFERENCE_DIR" "$ACTUAL_DIR" "$OUTPUT_DIR" "$THRESHOLD" || DIFF_FAILED=true

echo ""

if [ "${DIFF_FAILED:-false}" = "true" ]; then
    echo "⚠️  Some screenshots exceeded the ${THRESHOLD}% threshold"
else
    echo "✅ All screenshots within ${THRESHOLD}% threshold"
fi

# Generate HTML Report
python3 << 'HTMLEOF'
import json, os, sys, base64

output_dir = os.environ.get("OUTPUT_DIR", "docs/ui-fidelity/diff-report")
results_file = os.path.join(output_dir, "results.json")

try:
    with open(results_file) as f:
        data = json.load(f)
except FileNotFoundError:
    print("No results.json found — skipping HTML report")
    sys.exit(0)

summary = data["summary"]
results = data["results"]

def img_tag(path, size=(120, 80)):
    full_path = os.path.join(output_dir, path)
    if os.path.exists(full_path):
        with open(full_path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        return f'<img src="data:image/png;base64,{b64}" style="max-width:{size[0]}px;max-height:{size[1]}px;border-radius:4px;" />'
    return '<span style="color:#999">N/A</span>'

html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>UI Fidelity Diff Report</title>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; background:#f5f5f7; color:#1d1d1f; padding:20px; }}
  .container {{ max-width:1400px; margin:0 auto; }}
  h1 {{ font-size:28px; margin-bottom:8px; color:#1d1d1f; }}
  .meta {{ color:#86868b; font-size:14px; margin-bottom:24px; }}
  .summary-grid {{ display:grid; grid-template-columns:repeat(4,1fr); gap:12px; margin-bottom:32px; }}
  .summary-card {{ background:white; border-radius:12px; padding:20px; text-align:center; box-shadow:0 1px 3px rgba(0,0,0,0.08); }}
  .summary-card .number {{ font-size:36px; font-weight:700; }}
  .summary-card .label {{ font-size:13px; color:#86868b; margin-top:4px; }}
  .pass .number {{ color:#34c759; }}
  .fail .number {{ color:#ff3b30; }}
  .new .number {{ color:#007aff; }}
  .total .number {{ color:#1d1d1f; }}
  table {{ width:100%; border-collapse:collapse; background:white; border-radius:12px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.08); }}
  th {{ background:#f5f5f7; padding:14px 16px; text-align:left; font-size:13px; font-weight:600; color:#86868b; text-transform:uppercase; letter-spacing:0.5px; }}
  td {{ padding:14px 16px; border-top:1px solid #e8e8ed; font-size:14px; vertical-align:middle; }}
  tr:hover {{ background:#fafafa; }}
  .status-pass {{ color:#34c759; font-weight:600; }}
  .status-fail {{ color:#ff3b30; font-weight:600; }}
  .status-new {{ color:#007aff; font-weight:600; }}
  .status-removed {{ color:#ff9500; font-weight:600; }}
  .diff-pct {{ font-family:"SF Mono",Monaco,monospace; font-size:13px; }}
  .thumb {{ border-radius:6px; overflow:hidden; display:inline-block; }}
  .overall-badge {{ display:inline-block; padding:6px 16px; border-radius:20px; font-weight:600; font-size:15px; }}
  .badge-pass {{ background:#e8f8f0; color:#248a3d; }}
  .badge-fail {{ background:#ffe5e5; color:#d70015; }}
  code {{ background:#f5f5f7; padding:2px 6px; border-radius:4px; font-size:12px; }}
</style>
</head>
<body>
<div class="container">
  <h1>🎨 UI Fidelity Diff Report</h1>
  <p class="meta">Generated: {data["timestamp"]} &nbsp;|&nbsp; Threshold: {data["threshold"]}% &nbsp;|&nbsp;
     <span class="overall-badge badge-{"pass" if summary["overall_status"]=="PASS" else "fail"}">
       {"✅ PASS" if summary["overall_status"]=="PASS" else "❌ FAIL"}
     </span></p>

  <div class="summary-grid">
    <div class="summary-card total"><div class="number">{summary["total"]}</div><div class="label">Total</div></div>
    <div class="summary-card pass"><div class="number">{summary["pass"]}</div><div class="label">Pass</div></div>
    <div class="summary-card fail"><div class="number">{summary["fail"]}</div><div class="label">Fail</div></div>
    <div class="summary-card new"><div class="number">{summary["new"]}</div><div class="label">New</div></div>
  </div>

  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>Image Name</th>
        <th>Status</th>
        <th>Diff %</th>
        <th>Reference</th>
        <th>Actual</th>
        <th>Diff Visualization</th>
      </tr>
    </thead>
    <tbody>
'''

for i, r in enumerate(results):
    status_class = f'status-{r["status"].lower()}'
    diff_str = f'{r["diff_percent"]}%' if r["diff_percent"] is not None else '—'
    ref_thumb = img_tag(r["name"]) if r["status"] != "NEW" else '<span style="color:#999">—</span>'
    act_thumb = img_tag(r["name"])
    diff_thumb = img_tag(f'diff_{r["name"]}') if r["status"] not in ("NEW", "REMOVED") else (
        img_tag(f'new_{r["name"]}') if r["status"] == "NEW" else '<span style="color:#999">—</span>'
    )
    html += f'''
      <tr>
        <td>{i+1}</td>
        <td><code>{r["name"]}</code></td>
        <td class="{status_class}">{r["status"]}</td>
        <td class="diff-pct">{diff_str}</td>
        <td class="thumb">{ref_thumb}</td>
        <td class="thumb">{act_thumb}</td>
        <td class="thumb">{diff_thumb}</td>
      </tr>'''

html += '''
    </tbody>
  </table>

  <p style="margin-top:24px;color:#86868b;font-size:13px;">
    Tip: To update baselines, copy images from <code>build/screenshots/actual/</code> to <code>docs/ui-fidelity/references/</code>
  </p>
</div>
</body>
</html>
'''

with open(os.path.join(output_dir, "index.html"), "w") as f:
    f.write(html)
print(f"HTML report written to {os.path.join(output_dir, 'index.html')}")
HTMLEOF

echo ""
echo "Report saved to: $OUTPUT_DIR/index.html"
echo "Results JSON:   $OUTPUT_DIR/results.json"
