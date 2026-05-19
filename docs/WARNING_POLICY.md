# Build Warning Policy

## Rule: Business Code Warnings Must Be 0

Any PR that introduces a new warning in `Sources/` or `SuperApp/` code must fix it before merge.

## Accepted Warnings (do not fix)

These are Apple toolchain or third-party library noise:

| Warning | Source | Reason |
|---------|--------|--------|
| Metadata extraction skipped | appintentsmetadataprocessor | Apple toolchain, no AppIntents in project |
| `NSError+RLMSync.o` has no symbols | libtool | Realm Sync empty compilation unit |
| `RLMRealm+Sync.o` has no symbols | libtool | Realm Sync empty compilation unit |
| `_RX.o` has no symbols | libtool | RxSwift empty object file |

## Test Runtime Noise

378 duplicate class warnings appear during test runs due to CocoaPods `inherit! :complete` linking pod copies per test target. These are harmless and do not affect test results. See `Podfile` for details.

## How to Check

```bash
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd 2>&1 | grep "warning:" | grep -v "libtool" | grep -v "appintentsmetadata"
```

This should return 0 lines.
