# App Size Budget

## Current Measurements (Debug, iphonesimulator arm64)

| Component | Size |
|-----------|------|
| SuperApp.app (Debug) | 56 MB |
| WebBridgeKit.framework | 45 MB |
| WBKMessage.framework | 1.9 MB |
| Assets.car | 465 KB |
| SuperApp.debug.dylib | 7.0 MB |
| Lucide icons | 73 imagesets |

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
| Assets.car | < 1 MB | 465 KB | PASS |
| Lucide imagesets | < 100 | 73 | PASS |
| Non-Lucide icon resources | 0 | 0 | PASS |
| Hardcoded color violations | 0 | 0 | PASS |
| Embedded HTML test files | < 200 KB | ~250 KB | WARN |
| Framework total (Release) | < 30 MB | TBD | PENDING |

### Release Projection

| Metric | Debug | Release (est.) |
|--------|-------|----------------|
| SuperApp.app total | 56 MB | ~20-25 MB |
| Frameworks | 48 MB | ~15-20 MB |
| Assets.car | 465 KB | ~350 KB |

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
grep -rn 'UIColor(red:' Sources/ SuperApp/ --include='*.swift' | grep -v ThemeTokens | grep -v ThemeManager | grep -v Test

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

1. **Remove embedded HTML test files from bundle** — ~250 KB of test HTML/JS/CSS files are included in the app bundle. These should be excluded from Release builds via `EXCLUDED_SOURCE_FILE_NAMES` or moved to a test-only target.
2. **Measure Release build** — Debug numbers include symbols. Archive with Release config for accurate App Store sizing.
3. **Monitor Lucide icons** — Currently at 73/100 budget. Adding more icons requires audit.
4. **Consider On-Demand Resources** — If app grows beyond 50 MB Release, consider ODR for test HTML resources.
