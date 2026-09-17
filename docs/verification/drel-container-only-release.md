# Drel Store Container-Only Release Verification

Date: 2026-08-25

## Scope

Drel's first App Store release is a notification and web-container product.
Remote webpages can render in `WKWebView`, but must not receive a native
JavaScript bridge, native message handler, or injected launch payload.

## Compile-Time Policy

`project.yml` defines `DREL_CONTAINER_ONLY` for both the `WebBridgeKit` and
`SuperApp` Release targets. `DrelContainerBuildPolicy.nativeBridgeEnabled`
therefore resolves to `false` in Drel's Store build, while conditional source
also excludes the Store-only app's Bridge-management screens. The SDK remains
bridge-capable in its other host/configuration combinations.

The policy is enforced at both live web-view construction paths:

- `WebBrowserViewModel` does not inject `WebBridge.js` or register
  `BarkBridge`.
- `WebViewController` does not use a bridged warm pool, inject its legacy
  compatibility shim, register either case of the Bark handler, or install the
  gesture interceptor.
- `WebBrowserViewController.configure(with:)` does not configure a managed
  native bridge or inject route payloads.
- `WebBridgeKitManager.initialize()` does not warm a bridged pool.
- `PWAPermissionCenterViewController` and `WebOriginGrantsView` are not
  compiled into the Store product; the App Center does not offer a Bridge
  permission action and the settings/grants presenters are unavailable.

## Simulator Evidence

The Release simulator app was built successfully with:

```bash
xcodebuild build -quiet -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -configuration Release -sdk iphonesimulator -arch arm64 \
  -derivedDataPath /private/tmp/drel-container-only-sim CODE_SIGNING_ALLOWED=NO
```

`bash tools/verify-release-no-debug.sh` passed against the resulting app
bundle, with zero known DEBUG-only markers.

The built app was installed on an iOS 26.4 simulator and opened through the
normal `webbridgekit://open?url=...` route. The local fixture
`test_resources/drel-container-only-check.html` reported:

```text
PASS — container-only: no native Bridge surface detected
window.BarkBridge: absent
window.WebBridgeKit: absent
messageHandlers.BarkBridge: absent
messageHandlers.barkBridge: absent
```

The captured simulator evidence is `/private/tmp/drel-container-only-check.png`
for the local verification session; it is not a release asset.

## Final release-plist inspection

After correcting the XcodeGen target configuration and building the current
Release simulator product with:

```bash
xcodegen generate && pod install
bash tools/verify-drel-container-only.sh
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -configuration Release -sdk iphonesimulator -arch arm64 \
  -derivedDataPath /tmp/drel-container-ui-gate CODE_SIGNING_ALLOWED=NO
```

the built bundle at
`/tmp/drel-container-ui-gate/Build/Products/Release-iphonesimulator/SuperApp.app`
reported the following through `plutil`:

```text
CFBundleIdentifier: com.webbridgekit.superapp
CFBundleDisplayName: Drel
CFBundleVersion: 9
NSCameraUsageDescription: present
```

No Bridge-only privacy declaration (Bluetooth, contacts, Face ID, location,
microphone, motion, photos, or speech) and no `NSAllowsArbitraryLoads` entry
remained in that Release app bundle. Camera is retained exclusively for the
optional self-hosted gateway QR scanner; paste import remains available.

## Remaining Release Evidence

This test proves that the container cannot expose the native bridge. It does
not prove APNs delivery. Before TestFlight upload, separately verify a routed
notification reaches the Release app and opens its intended URL or signed
`appId + route + parameters` destination. Strong-offline package tests are a
separate integrity/retention gate.
