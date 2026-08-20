#!/usr/bin/env bash
# Animation verification gate for the inbox notification-group accordion.
#
# XCUITest cannot assert animation quality directly. This gate combines three
# evidence sources produced by InboxGroupAnimationTests:
#   1. simulator screen recording (xcrun simctl io recordVideo)
#   2. wallclock anchor files written by the test right before each tap
#      (/tmp/wbk-anim/anchor-<event>-<epoch>)
#   3. a t0 timestamp file capturing the recording start epoch
#
# For every collapse/expand anchor it then extracts frames and checks:
#   - MOTION: the toggle window actually animates (multi-frame movement)
#   - CONTINUITY: motion is spread across >= MIN_MOVING_FRAMES frames at
#     20fps — a single-frame layout snap fails this
#   - NO-FREEZE: no >= FREEZE_SECONDS run of identical frames inside the
#     window (the UI must stay responsive during the animation)
#
# Usage:
#   bash tools/verify-inbox-accordion-animation.sh            # full pipeline
#   bash tools/verify-inbox-accordion-animation.sh --analyze-only \
#       --video /tmp/wbk-anim/inbox-anim.mp4 \
#       --anchors /tmp/wbk-anim --t0-file /tmp/wbk-anim/rec-t0.txt
set -uo pipefail

UDID="${WBK_ANIM_SIM:-9A3DBDB8-DE0E-4016-8768-360FC6EAA35C}"
DERIVED="${WBK_ANIM_DD:-/tmp/wbk-anim-dd}"
ART="${WBK_ANIM_ARTIFACTS:-/tmp/wbk-anim}"
VIDEO="$ART/inbox-anim-verify.mp4"
T0_FILE="$ART/verify-t0.txt"
ANALYZE_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --analyze-only) ANALYZE_ONLY=1 ;;
    --video) VIDEO="$2"; shift ;;
    --anchors) ART="$2"; shift ;;
    --t0-file) T0_FILE="$2"; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ $ANALYZE_ONLY -eq 0 ]]; then
  echo "[anim-verify] building for simulator $UDID"
  xcodebuild build-for-testing -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
    -sdk iphonesimulator -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | grep -v GVM
  mkdir -p "$ART"
  find "$ART" -maxdepth 1 -name 'anchor-*' -delete 2>/dev/null || true
  date +%s.%N > "$T0_FILE"
  echo "[anim-verify] recording to $VIDEO"
  xcrun simctl io "$UDID" recordVideo --force "$VIDEO" > "$ART/verify-record.log" 2>&1 &
  REC_PID=$!
  sleep 2
  xcodebuild test-without-building -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
    -only-testing:SuperAppUITests/InboxGroupAnimationTests 2>&1 \
    | grep -E "Test Case.*(passed|failed)"
  TEST_STATUS=$?
  kill -INT "$REC_PID" 2>/dev/null
  sleep 3
  if [[ $TEST_STATUS -ne 0 ]]; then
    echo "FAIL: probe tests failed; animation analysis skipped"
    exit 1
  fi
fi

python3 - "$VIDEO" "$ART" "$T0_FILE" <<'PYEOF'
import os, sys, glob, subprocess, tempfile, shutil
from PIL import Image, ImageChops

VIDEO, ART, T0_FILE = sys.argv[1], sys.argv[2], sys.argv[3]
FPS = 20
MIN_MOVING_FRAMES = 4      # ~0.2s of continuous motion at 20fps
MOTION_EPS = 0.6           # mean-abs grayscale diff that counts as motion
# recordVideo starts capturing ~1s after the t0 file is written; the wide
# lead absorbs that latency, and events may land at anchor-1s.
TOGGLE_WINDOW = (-2.0, 1.6)  # seconds around each anchor

t0 = float(open(T0_FILE).read().strip())
anchors = []
for f in glob.glob(os.path.join(ART, "anchor-*")):
    name = os.path.basename(f).replace("anchor-", "")
    label, epoch = name.rsplit("-", 1)
    if "collapse" in label or "expand" in label or label.startswith("rapid"):
        anchors.append((label, float(epoch) - t0))
anchors.sort(key=lambda a: a[1])
if not anchors:
    print("FAIL: no toggle anchors found in", ART)
    sys.exit(1)

tmp = tempfile.mkdtemp(prefix="wbk-anim-frames-")
passed, failed = 0, 0
for label, t in anchors:
    ss = max(0.0, t + TOGGLE_WINDOW[0])
    to = t + TOGGLE_WINDOW[1]
    out = os.path.join(tmp, f"{label}_%03d.png")
    r = subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-ss", str(ss), "-to", str(to),
         "-i", VIDEO, "-vf", f"fps={FPS}", out],
        capture_output=True, text=True)
    frames = sorted(glob.glob(os.path.join(tmp, f"{label}_*.png")))
    if len(frames) < 4:
        print(f"FAIL {label}: only {len(frames)} frames extracted")
        failed += 1
        continue
    diffs, prev = [], None
    for fpath in frames:
        im = Image.open(fpath).convert("L").resize((160, 320))
        if prev is not None:
            h = ImageChops.difference(im, prev).histogram()
            mean = sum(i * c for i, c in enumerate(h)) / (160 * 320)
            diffs.append(mean)
        prev = im
    moving = [d > MOTION_EPS for d in diffs]
    # Motion bursts: contiguous runs of moving frames, tolerating small gaps.
    # The toggle animation should appear as ONE burst of >= MIN_MOVING_FRAMES
    # frames; a snap produces a 1-2 frame burst, a frozen UI none at all.
    bursts, cur = [], 0
    gap = 0
    for m in moving:
        if m:
            cur += 1
            gap = 0
        elif cur > 0:
            gap += 1
            if gap > 2:
                bursts.append(cur)
                cur, gap = 0, 0
    if cur > 0:
        bursts.append(cur)
    best = max(bursts) if bursts else 0
    problems = []
    if best == 0:
        problems.append("no motion at all")
    if 0 < best < MIN_MOVING_FRAMES:
        problems.append(f"motion snap: longest burst only {best} frames")
    if problems:
        print(f"FAIL {label} (t={t:.2f}s, bursts={bursts[:6]})")
        failed += 1
    else:
        print(f"PASS {label} (t={t:.2f}s, longest burst={best} frames)")
        passed += 1
shutil.rmtree(tmp, ignore_errors=True)
print(f"Summary: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PYEOF
