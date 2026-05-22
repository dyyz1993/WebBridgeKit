# App Size Budget

## Current Measurements

| Component | Size |
|-----------|------|
| SuperApp.app (Debug) | 56 MB |
| SuperApp.app (Release/Archive) | **26 MB** |
| WebBridgeKit.framework (Debug) | 45 MB |
| WebBridgeKit.framework (Release) | 22 MB |
| WBKMessage.framework | 1.9 MB |
| Assets.car | 465 KB |
| SuperApp.debug.dylib | 7.0 MB |
| Lucide icons | 73 imagesets |
| Archive (.xcarchive) | 122 MB |

### Framework Breakdown

| Framework | Size |
|-----------|------|
| WebBridgeKit.framework | 45 MB |
| WBKMessage.framework | 1.9 MB |
| **Total Frameworks** | **~48 MB** |

> Note: Debug builds include DWARF symbols and are significantly larger than Release. Expect ~40-60% size reduction in Release/App Store builds after stripping and bitcode optimization.

## Budget Limits

| Component | Limit | Current | Status |
|-----------|-------|---------|--------|
| Assets.car | < 1 MB | 465 KB | ✅ PASS |
| Lucide imagesets | < 100 | 73 | ✅ PASS |
| Non-Lucide icon resources | 0 | 0 | ✅ PASS |
| Hardcoded color violations | 0 | 0 | ✅ PASS |
| Embedded HTML test/debug resources in Release | 0 files | 0 files | ✅ PASS |
| Framework total (Release) | < 30 MB | ~23.4 MB | ✅ PASS |

### Release Verified

| Metric | Debug | Release |
|--------|-------|---------|
| SuperApp.app total | 56 MB | **26 MB** |
| Frameworks | 48 MB | **~23.4 MB** |
| Assets.car | 465 KB | 465 KB |
| Test/debug HTML/JS resources | Debug only | **0 files** |

## How to Measure

```bash
# Full app size
APP=$(find /tmp/wbk-dd -name "SuperApp.app" -maxdepth 5 | head -1)
du -sh "$APP"

# Assets catalog
find "$APP" -name "*.car" -exec ls -lh {} \;

# Lucide icon count
find Sources/Theme/icons.xcassets -mindepth 1 -maxdepth 1 -name '*.imageset' | wc -l

# Framework breakdown
du -sh "$APP/Frameworks/"*.framework

# Hardcoded color violations
rg 'UIColor\(red:|\.systemBlue|\.secondaryLabel|\.tertiaryLabel|\.systemOrange' \
  Sources/ SuperApp/ AppTemplate/Sources --glob '*.swift' \
  | grep -v ThemeTokens.swift | grep -v ThemeManager.swift

# Archive build (Release, for accurate sizing)
xcodebuild archive \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -archivePath /tmp/WebBridgeKit.xcarchive \
  -sdk iphonesimulator -arch arm64 \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath /tmp/wbk-dd-archive
```

## Recommendations

1. **Keep Release strip script covered by output dependencies** — `project.yml` and `WebBridgeKit.xcodeproj` both record `$(DERIVED_FILE_DIR)/strip-test-resources.stamp`.
2. **Monitor Lucide icons** — Currently at 73/100 budget. Adding more icons requires audit.
3. **Track Release size per PR** — Re-run the archive command above when adding frameworks, media, or bundled web resources.
4. **Consider On-Demand Resources** — If app grows beyond 50 MB Release, consider ODR for optional demo/prototype assets.
