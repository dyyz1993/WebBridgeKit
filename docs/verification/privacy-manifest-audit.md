# Privacy manifest audit — 2026-08-25

This audit covers Drel's first container-only Store build. Each target owns a
separate `PrivacyInfo.xcprivacy`; dependency manifests remain the responsibility
of their respective SDKs.

| Target | Required-reason APIs | Approved reason | Evidence |
| --- | --- | --- | --- |
| WebBridgeKit framework | File metadata in its app/app-group cache; disk capacity and elapsed runtime used by diagnostics; app and App Group defaults | `C617.1`, `85F4.1`, `35F9.1`, `CA92.1`, `1C8F.1` | `DiskCache`, `EnvironmentInfo`, `AIReadOnlyTools`, `PushCipher`, and `UserDefaultsMessageStore` |
| Drel app | File metadata in its container; app and App Group defaults | `C617.1`, `CA92.1`, `1C8F.1` | cache/package management, app settings, and push preferences |
| Notification Service Extension | App Group defaults shared with Drel | `1C8F.1` | `NotificationServiceExtension/PushCrypto.swift` |

The app manifest declares no tracking. It declares a non-linked, non-tracking
device identifier and gateway credential/configuration data only for push and
gateway functionality: Drel sends the APNs token and selected gateway key when
the user activates push. Notification content is received by the device; it is
not collected by Drel for advertising or analytics.

`getDiagnosticReport` is available only in DEBUG builds. The SDK privacy
manifest still declares the matching `SystemBootTime` reason because the
framework contains the generic elapsed-runtime diagnostic implementation; this
keeps the bundled declaration complete if Xcode retains that implementation.

## Verification

```bash
plutil -lint Resources/PrivacyInfo.xcprivacy \
  SuperApp/Resources/PrivacyInfo.xcprivacy \
  NotificationServiceExtension/PrivacyInfo.xcprivacy
xcodegen generate && pod install
xcodebuild archive -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -configuration Release -sdk iphoneos -archivePath /private/tmp/drel-privacy.xcarchive \
  CODE_SIGNING_ALLOWED=NO
find /private/tmp/drel-privacy.xcarchive/Products/Applications -name PrivacyInfo.xcprivacy -print
```

The archive must contain manifests in Drel, WebBridgeKit.framework, and the
Notification Service Extension. Before submission, also review the generated
privacy report and complete matching App Store Connect App Privacy answers.
