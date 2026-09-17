# WebBridgeKit Release Closeout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Turn the current simulator-ready product into a reviewable TestFlight build, then an App Store 1.0 submission without expanding the feature set.

**Architecture:** Keep the official hosted journey as the default, configuration-free user path. Keep QR/paste gateway import as a distinct self-hosted path. Treat push, approval, and strong offline packages as release contracts: first prove them through automation, then verify the parts that only a production-signed iPhone can prove.

**Tech Stack:** Swift 5, SwiftUI/UIKit, XcodeGen, XCTest/XCUITest, APNs, App Store Connect, Hummingbird, Bash release gates.

---

## Release decision

- Current state: **NO-GO for App Store submission**.
- Immediate code blocker cleared on 2026-08-24: `WBKGateTrace` now has a Release no-op implementation and `bash tools/run-release-gate.sh` passes 9/9.
- Do not add new native capabilities, handlers, message formats, gateway fields, or offline-package formats in this closeout.

## Execution record (2026-08-24)

- Task 1 complete locally: Release archive, HTML exclusion, and DEBUG-only binary scan all passed.
- Task 2 complete locally: the developer home remains a Release feature. Simulator coverage passes for the address/copy state, the first-push/API/documentation entry points, and all seven canonical push examples.
- Task 4 product implementation complete locally: opening a strong-offline-eligible HTML app now verifies and atomically prepares the package before launch; App Center shows pending/update/installed version and actual disk size. `HTMLAppOfflinePackageInstallerTests` passed 9/9, `verify-strong-offline-package.sh` passed 4/4, `run-cache-regression.sh` passed 5/5 (including CacheTests 557/557), and the final Release Gate passed 9/9.
- Task 4 public integration complete: the timed-out `cloak.xbrowser.dev:5801` target was a retired gateway still present in automation, not the configured official service. Verification now targets `https://wbk.shanbox.19930810.xyz:8443`: `verify-open-gateway.sh` passed 5/5 and the simulator's validate-before-activate journey passed 1/1. HTTPS, signature, and offline-package checks remain unchanged.
- Remaining release blockers are device- or store-bound: production signing/TestFlight APNs acceptance, legal/support URLs and App Store Connect privacy/metadata, plus final store media.

### Task 1: Restore Release compilation and make the gate regression-proof

**Files:**
- Modify: `Sources/Core/WebJavaScriptBridge.swift:278,365,449,453,1075-1091`
- Modify: `tools/run-release-gate.sh`
- Modify: `docs/verification/module-availability-verification.md`

**Step 1: Add a failing Release build reproduction.**

Run:

```bash
xcodebuild archive -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -archivePath /tmp/wbk-release-closeout/SuperApp.xcarchive \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO SKIP_INSTALL=NO
```

Expected before the fix: `cannot find 'WBKGateTrace' in scope` at the four call sites.

**Step 2: Make tracing compile in every configuration but write only in Debug.**

Keep a single `WBKGateTrace` type outside `#if DEBUG`; compile `log(_:)` in all configurations and put only its file-writing body behind `#if DEBUG`.

```swift
enum WBKGateTrace {
    static func log(_ line: String) {
        #if DEBUG
        // existing /tmp/wbk-gate-trace.log implementation
        #endif
    }
}
```

Do not remove the existing trace call sites: they are useful Debug instrumentation and the Release no-op keeps the production binary free of file tracing.

**Step 3: Verify the archive and release scans.**

Run:

```bash
bash tools/run-release-gate.sh
```

Expected: `Summary: 9 passed, 0 failed`. Confirm that the archive exists before interpreting the `No Release test HTML` and `No DEBUG-only code` rows.

**Step 4: Record evidence.**

Update the availability report with the command, current commit, archive path, and 9/9 result. Do not overwrite the historical failed run.

**Step 5: Commit.**

```bash
git add Sources/Core/WebJavaScriptBridge.swift tools/run-release-gate.sh docs/verification/module-availability-verification.md
git commit -m "fix(release): make bridge tracing configuration-safe"
```

### Task 2: Validate the Bark-style developer home as a release feature

**Files:**
- Modify: `SuperApp/Sources/Views/PWAHome/PWAHomeView.swift:62-406`
- Modify: `SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift:103-116`
- Modify: `SuperAppUITests/TabScreenshotTests.swift`
- Modify: `tools/verify-release-no-debug.sh`

**Product decision:** WebBridgeKit's home is for developers integrating a notification service. It must keep the personal push address, copy action, first-push sender, API examples, and troubleshooting/documentation entry in the Release build. These are not hidden Debug tools.

**Step 1: Define the developer-home contract in a UI test.**

Add a Release-surface assertion that the home exposes:

- notification enable/status action before registration;
- the personal push address and a working copy action after registration;
- a sender that delivers one test notification through the same public route developers use;
- API examples and documentation/troubleshooting actions;
- a visible custom/self-hosted gateway management entry.

Do not assert that `测试通知`, `全部 API 示例`, or `手册与调试` are absent: those labels represent the developer product.

**Step 2: Run the test before changing the UI.**

Run:

```bash
xcodebuild test -workspace WebBridgeKit.xcworkspace -scheme SuperApp \
  -destination 'platform=iOS Simulator,id=79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0' \
  -only-testing:SuperAppUITests/TabScreenshotTests
```

Expected: the interaction contract passes on simulator. If it fails, the failure identifies a real developer-onboarding regression rather than a cosmetic mismatch.

**Step 3: Make only evidence-driven usability improvements.**

Preserve the existing card structure unless testing finds friction. The desired order after notification activation is: personal push address and copy action, then one-tap/browser test send, then API examples and troubleshooting. Do not move the card behind an account/login wall or replace it with a consumer-style empty state.

**Step 4: Capture clean launch screenshots.**

Run the targeted test on a reset simulator. Capture Home, Inbox empty state, Inbox with one realistic official message, Settings, self-host gateway management, and offline package state. Never capture fake `13` unread messages for App Store media.

**Step 5: Record the approved home contract and commit.**

Do not add developer-home labels to `tools/verify-release-no-debug.sh`; that script remains for internal-only debug screens. Run the full release gate, then:

```bash
git add SuperAppUITests/TabScreenshotTests.swift docs/verification/module-availability-verification.md
git commit -m "test(onboarding): lock developer push-home contract"
```

### Task 3: Close the real-device and production-service gate

**Files:**
- Modify: `docs/verification/module-availability-verification.md`
- Modify if evidence exposes a defect: only the owning `SuperApp/`, `NotificationServiceExtension/`, or `Server/` file
- Verify: `tools/verify-shanbox-backend.sh`, `tools/verify-real-device-push-readiness.sh`, `SuperAppUITests/RealDevicePushSmokeTests.swift`

**Step 1: Produce a production-signed TestFlight candidate.**

In Xcode/App Store Connect, use the paid team and Push-enabled App ID for `com.webbridgekit.superapp`; confirm the archived app has the production `aps-environment` entitlement. Do not use a Personal Team or a no-push bundle-id workaround as release evidence.

**Step 2: Run automated route and signing checks.**

Run:

```bash
bash tools/verify-shanbox-backend.sh
DEVICE_ID=<paired-iphone-id> bash tools/verify-real-device-push-readiness.sh
```

Expected: public routes are green, and signing readiness has no entitlement/profile failure.

**Step 3: Perform the one manual APNs matrix.**

On the TestFlight build, test one plain push, one route push, and one approval push while foregrounded, backgrounded, and locked. For every push, verify the target `appId + route + parameters` opens the correct place but approval still needs an explicit tap in-app. Verify one named `.caf` sound on the locked phone.

**Step 4: Record only observed results.**

Add device model, TestFlight build number, server version, pass/fail result, and three-layer push logs to the verification document. A route-level HTTP 200 is not delivery proof.

**Step 5: Commit evidence-only documentation.**

```bash
git add docs/verification/module-availability-verification.md
git commit -m "docs(verification): record TestFlight push acceptance"
```

### Task 4: Prove the two onboarding paths and strong offline journey end to end

**Files:**
- Modify: `SuperAppUITests/ModuleAvailabilityTests.swift` or a dedicated focused UI test
- Modify: `docs/verification/module-availability-verification.md`
- Verify: `tools/verify-open-gateway.sh`, `tools/verify-strong-offline-package.sh`, `tools/run-cache-regression.sh`

**Step 1: Add focused simulator UI coverage.**

Prove these visible states with stable identifiers:

- launch with the official gateway automatically selected, no QR/paste prompt;
- self-hosted QR/paste import opens only after the user chooses gateway management;
- validation report appears before activation;
- persistent package status exposes installed/version/size and a failure state.

**Step 2: Run the test before any UI additions.**

Expected: current offline package contract is covered at model/installer level, but does not yet have a dedicated end-to-end UI identifier.

**Step 3: Add the smallest missing identifiers or status rows.**

Do not redesign the App Center. Add only stable product evidence for onboarding confirmation and offline installed status.

**Step 4: Run the layered gates.**

```bash
bash tools/verify-open-gateway.sh
bash tools/verify-strong-offline-package.sh
bash tools/run-cache-regression.sh
```

Expected: all pass. Then manually enable airplane mode and open the packaged reference PWA after the source is unavailable.

**Step 5: Commit.**

```bash
git add SuperAppUITests docs/verification/module-availability-verification.md
git commit -m "test(product): prove gateway and offline release journeys"
```

### Task 5: Complete legal, support, and App Store assets

**External deliverables (no source-code substitute):**
- Publish a privacy-policy URL and a support URL with real contact information.
- Complete App Store Connect data-collection answers for the host app, gateway service, push registration, and every integrated SDK.
- Create product-page metadata: Chinese name, subtitle, description, keywords, category, age rating, copyright, review contact, and reviewer steps.
- Create six 6.9-inch iPhone screenshots in PNG/JPG with no alpha channel; localize English after the Chinese launch set is approved.

**Step 1: Add accessible in-app legal/support links.**

Add the two production URLs to Settings/About only after the public pages exist. Use `SFSafariViewController` or the system browser; do not ship placeholder URLs.

**Step 2: Verify links and privacy copy.**

On simulator and TestFlight, tap both links. Confirm the privacy policy explains permissions, push identifiers, gateway data, retention/deletion, and consent revocation.

**Step 3: Produce clean store screenshots.**

Use a production-like official account and one real PWA. First three screenshots must communicate: unified PWA home, relevant notification routing, and offline availability. Include one dark-mode screen later in the sequence.

**Step 4: Complete App Review notes.**

Give Apple the official gateway URL, a review-ready account or public test flow, a one-line explanation of native permission prompts, and a confirmation that push parameters navigate but never approve sensitive work.

**Step 5: Mark the release checklist ready.**

Attach URLs, exported media filenames, App Store Connect version, and reviewer instructions to the release handoff. Do not commit secrets or reviewer credentials.

### Task 6: Release candidate and staged rollout

**Files:**
- Modify: `docs/verification/module-availability-verification.md`
- Verify: `tools/verify-next-phase-acceptance.sh --full`

**Step 1: Freeze scope.**

Only accept release-blocker fixes after Task 5. Defer new handlers, additional sample PWAs, analytics, and visual redesigns.

**Step 2: Run the full acceptance gate.**

```bash
bash tools/verify-next-phase-acceptance.sh --full
```

Expected: all automated rows pass; only the completed, documented real-device rows remain manual evidence.

**Step 3: TestFlight rollout.**

Release first to internal testers, then a small external cohort. Monitor registration failures, notification delivery, gateway validation failures, offline install failures, and crash reports before widening access.

**Step 4: Submit App Store 1.0.**

Ship the official hosted path as the primary product. Keep self-hosted import available as a clearly secondary, one-time configuration path; never turn it into a first-launch prerequisite.

**Step 5: Post-release backlog.**

Move broader gateway catalog, more sample apps, optional app-preview video, and non-essential developer tooling to 1.1.
