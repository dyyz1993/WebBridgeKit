#!/bin/bash
# verify-release-no-debug.sh — 断言 Release 构建二进制不含 DEBUG-only 功能
#
# 机制：入口与引用点均用 #if DEBUG 门控后，Release 编译不再引用这些类型，
# 链接期 dead-strip 会把它们及其字符串常量裁掉。本脚本用 strings 扫描
# Release 产物里的特征字符串做实证（同 NSE ASCII marker 的取证手法）。
#
# 用法：
#   bash tools/verify-release-no-debug.sh [app-bundle-path]
#   不传路径时自动构建 Release（模拟器平台）并扫描产物。
#
# Pass signal: 所有 marker 0 命中，输出 "PASS ... 0 leaked markers"。

set -euo pipefail

cd "$(dirname "$0")/.."

# Debug-only 功能的特征字符串（视图名 / 页面标题 / 独有文案）。
# 新增 DEBUG-only 页面时必须在此追加 marker，规则见 AGENTS.md。
MARKERS=(
  "BridgeLabHomeView"
  "DebugCenterHomeView"
  "TokenPushHomeView"
  "WebCacheHomeView"
  "DeepLinkHomeView"
  "DiagnosticsView"
  "DebugPanelViewController"
  "NotificationDebugViewController"
  "NetworkDebugViewController"
  "ManifestCacheTestViewController"
  "ManifestTestCasesViewController"
  "ManifestCacheDemo"
  "Bridge 实验室"
  "调试中心"
  "Push 调试"
  "Bridge 调试"
  "网页缓存调试"
  "协议跳转工具"
)

APP_PATH="${1:-}"

if [[ -z "$APP_PATH" ]]; then
  DD=/tmp/wbk-rel-gate
  echo "==> Building Release (simulator) ..."
  xcodebuild build \
    -workspace WebBridgeKit.xcworkspace \
    -scheme SuperApp \
    -sdk iphonesimulator \
    -configuration Release \
    -arch arm64 \
    -derivedDataPath "$DD" \
    -quiet
  APP_PATH=$(find "$DD/Build/Products/Release-iphonesimulator" -name "SuperApp.app" -maxdepth 1 -type d | head -1)
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "FAIL: SuperApp.app not found (path: ${APP_PATH:-<empty>})"
  exit 1
fi

BINARY="$APP_PATH/SuperApp"
if [[ ! -f "$BINARY" ]]; then
  echo "FAIL: binary not found at $BINARY"
  exit 1
fi

echo "==> Scanning $(basename "$APP_PATH") binary for DEBUG-only markers ..."
LEAKED=0
for marker in "${MARKERS[@]}"; do
  COUNT=$(strings -a "$BINARY" | grep -cF -- "$marker" || true)
  if [[ "$COUNT" -gt 0 ]]; then
    echo "  LEAK  '$marker' x$COUNT"
    LEAKED=$((LEAKED+1))
  else
    echo "  clean '$marker'"
  fi
done

echo ""
if [[ "$LEAKED" -gt 0 ]]; then
  echo "FAIL: $LEAKED leaked DEBUG marker(s) in Release binary."
  echo "      修复方式：给对应视图文件加文件级 #if DEBUG，或检查是否有未门控的引用点。"
  exit 1
fi
echo "PASS: Release binary contains 0 leaked DEBUG markers."
