# Drel 1.4 submission checklist

> Current App Store state (as of 2026-10-13): the live Store version still
> carries 1.0 and the Guideline 2.1 response built around Build 60. The
> working candidate is `1.4.0 (88)`, bumped locally in `project.yml`
> (`53d0860c`) on top of the communication-entitlement fix (`57ba339c`).
> 1.4.0 (80) was a release candidate on 2026-09-19 but is superseded:
> builds 81–87 added the favorites tap-crash fix, immersive web view
> geometry, fullscreen favorites, the NSE icon avatar, and the 30-day
> avatar disk cache. Do not attach Build 80 or any earlier 1.4.0 build.
>
> 1.4.0 (85–87) shipped the icon-avatar feature, but the main app lacked
> `com.apple.developer.usernotifications.communication`, so iOS silently
> downgrades donated intents to plain notifications. Build 88 is the first
> build where the icon avatar can actually render.

> 2026-10-13 release-readiness check: `tools/run-release-gate.sh` passes
> 14/14, `tools/verify-strong-offline-package.sh` passes 4/4 files, and the
> focused UI suite passes 13/13 after updating two stale assertions that
> expected the removed inbox filter buttons instead of the current filter
> menu. The deterministic v4 screenshot set is ready locally under
> `docs/release/media/drel-app-store-v4/final/zh-Hans/appstore-ready/`;
> App Store Connect still needs the media upload and owner confirmation
> before submission. The fourth image's source is a light home screen,
> despite its `04-home-dark` filename, so replace it first if a dark-screen
> contrast is mandatory.

## 0. Signing prerequisite (before archiving Build 88)

- [x] The **Communication Notifications** capability is enabled on the
  Drel App ID: the Xcode-managed team profile pulled on 2026-10-09
  11:01 embeds `com.apple.developer.usernotifications.communication`.
- [x] Distribution signing resolved via **Xcode cloud signing** (no portal
  login needed): archive with `CODE_SIGN_STYLE=Automatic
  CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER=""`,
  then export with `signingStyle=automatic` and
  `-allowProvisioningUpdates`. Xcode rebuilt the distribution profile
  (2026-10-13 08:36) embedding the communication entitlement. The manual
  `WebBridgeKit App Store` profile on disk remains stale; regenerate it
  only if the manual-signing pipeline is ever restored.
- [x] After archiving, inspect the signed binary: the exported
  `SuperApp.ipa` shows `com.apple.developer.usernotifications.communication`
  alongside `aps-environment=production` and `get-task-allow=false`
  (2026-10-13, cloud-signed export).

## 1. Scope and public claims

- [ ] V1 claims (developer push address, inbox, named sound, tap-to-HTTPS)
  remain true in 1.4 and are not regressed.
- [ ] The 1.4 additions are claimed explicitly and consistently across
  metadata, review notes, and the product site:
  - `drel://app` external launch links and message links that open
    registered HTML apps (builds 75–76, 74).
  - Strong-offline HTML app gateway import (builds 73–80).
  - Bark-style custom icon avatar on notifications (builds 85–88).
  - Favorites rework: pinned-float ordering, full-swipe pin, fullscreen
    reopen (builds 81–87).
- [ ] `drel://app` launch behavior is described for App Review: what it
  opens, where registered apps come from (gateway import by the user),
  and why a notification may hand off to an installed HTML app.
- [ ] Final archive scan confirms the Debug Panel, AI tooling, and demo
  chart/mock data do not appear in the Store build.

## 2. Code and binary verification

- [x] `bash tools/run-release-gate.sh` passes for Build 88 (14/14 on
  2026-10-13).
- [x] `bash tools/verify-drel-container-only.sh` passes — **40/40**
  (2026-10-13; baseline was 39 in the 1.0.1 round).
- [x] `bash tools/verify-drel-store-archive.sh /tmp/drel-build88/Drel.xcarchive`
  passes (2026-10-13). Exported `SuperApp.ipa` inspected: 1.4.0 (88),
  `aps-environment=production`, `get-task-allow=false`,
  `com.apple.developer.usernotifications.communication=true`, App Group
  present, NSE embedded.
- [x] `bash tools/verify-strong-offline-package.sh` passes for the bundled
  offline demo package (4 files, 0 failures on 2026-10-13).
- [ ] Fresh-data signed Release simulator smoke for Build 88: Home reaches
  ready state; favorites list renders (time-desc + pinned floats); no
  notification/camera/photo prompt at first launch.
- [ ] Favorites regression: tap a favorite (device SIGTRAP class bug fixed
  in `93e73295`), delete and pin take effect on first attempt
  (`37b57d4b`), swipe gestures match the inbox.

## 3. UI review

- [x] Automated: `FavoriteFlowTests` passes end-to-end on the
  "iPhone 16 Pro UI Test" simulator (2026-10-13) — inbox Pi Chat →
  open link → browser shell with hidden tab bar → favorite via ⋯ menu →
  favorites list → reopen with favorited state echo. Six screenshots in
  `/tmp/drel-fav-verify/` (web shell, favorites, reopened, menu states).
- [ ] Capture the remaining Build 88 simulator flow: Home, Inbox (80pt
  rows, right-swipe pin), message detail (markdown links), immersive web
  view first frame, Settings, offline app open.
- [ ] Light and Dark Mode both pass; layer borders re-resolve on trait
  changes (`a6e5d139`).
- [ ] No text truncation or overlap on the new favorites and inbox cells.

## 4. TestFlight and APNs (physical phone only)

- [x] Upload exact signed Build 88 exactly once (2026-10-13 08:53,
  cloud-signed export via `xcodebuild -exportArchive destination=upload
  -allowProvisioningUpdates`; log: `/tmp/drel88-upload.log` —
  "Upload succeeded", "Uploaded package is processing"). Do not re-upload.
- [x] ASC state verified via API (2026-10-13, key `4NXJ8HL7K9`, issuer
  `18f47979-0b65-4045-b969-00ba54177716`): Build 88 `processingState=VALID`,
  `usesNonExemptEncryption=false` (export compliance auto-declared), build
  attached to App Store Version 1.4.0 (`PATCH appStoreVersions` → 200), and
  visible to the internal beta group 内部测试 (internal groups auto-receive
  processed builds; the manual assignment API returns 422 by design).
- [x] **Icon avatar verification** (2026-10-13, physical iPhone 13,
  iOS 18.7.3): fully automated pipeline — `PushAddressProbeTests` extracted
  the device push address on the device, push sent via managed ingress
  (`POST /push` with `icon`), APNs accepted for 2/2 devices, and the owner
  visually confirmed the avatar rendered correctly in the app-icon slot.
  This closes the regression the communication entitlement fix
  (`57ba339c`) exists for. TestFlight Build 88 carries identical code and
  entitlements; a re-install from TestFlight restores the store build.
- [ ] Repeat one result each for foreground, background, locked-screen,
  named sound, and notification tap to an explicit HTTPS destination; no
  delayed duplicate delivery.
- [x] `drel://app` simulator verification (2026-10-13, UI automation):
  `testExternalAppLinkOpensRegisteredAppImmersive` and
  `testExternalAppLinkFailsClosedForUnregisteredApp` both pass on the
  Build 88 code — registered app opens immersive, unregistered fails
  closed with the explanatory dialog.
- [x] On the physical iPhone 13 (2026-10-13, dev-signed install via
  `xcodebuild test -destination platform=iOS`): both deep-link tests pass
  on hardware (`...OpensRegisteredAppImmersive` 21.3s,
  `...FailsClosedForUnregisteredApp` 17.6s) and `FavoriteFlowTests` passes
  end-to-end (45.3s) — the favorites SIGTRAP-class crash regression stays
  fixed on device. The deep-link handler is the same entry for Safari and
  notification-link sources.
- [ ] If any APNs result fails, collect server send log and device
  system-log evidence before changing code; do not retry visible alerts
  automatically.

## 5. App Store Connect material

- [x] Re-read the live 1.0 record; the new 1.4.0 version record exists.
- [x] Attach the deterministic v4 screenshot set to both iPhone display
  targets. On 2026-10-13, zh-Hans and en-US each received 4 completed
  screenshots for Dynamic Island medium (1179×2556) and Face ID large
  (1242×2688); stale 6.5-inch variants were removed. Compose/update with
  `docs/release/media/drel-app-store-v4/tools/compose.py` and upload with
  `tools/asc-upload-screenshots.py`.
- [x] Update review notes for 1.4.0 (88): physical-device recording,
  `drel://app`, strong offline, and icon avatar are all covered in the
  version-level review notes (4000-character ASC limit respected).
- [ ] Re-check the privacy questionnaire against the deployed service
  (Device ID collection unchanged? Kingfisher avatar cache is on-device
  disk cache, not tracking).
- [x] Export compliance for Build 88: auto-declared in the binary
  (`usesNonExemptEncryption=false`); no manual portal step needed.
- [x] Attach only exact processed Build 88 to version 1.4.0 and re-read it
  (done via API on 2026-10-13; attachment verified).

## 6. Submission

- [ ] Confirm whether App Review requires a private demo attachment for
  the 1.4 flows; the current 1.4 review-detail attachment list is empty.
- [ ] Final release review: all prior checks green; no concurrent upload
  or unresolved App Store Connect validation.
- [x] Owner confirmed "Drel 1.4.0 (88)" on 2026-10-14.
- [x] **Submitted for Review** on 2026-10-14 12:23 CST via ASC API
  (review submission `90bb4573-3d74-4296-b3ae-778e2a50f217`, state
  WAITING_FOR_REVIEW).

## Build history notes

- 1.0 (44–52, 60): first submission round, Guideline 2.1 rejection on 51,
  review-response Build 60. Never reuse or re-upload these.
- 1.0.1 (61–65): TestFlight patch round, UI review fixes (2026-09-11).
- 1.4.0 (68–87): Drel14Release generation; (80) was the RC and is
  superseded; (85–87) icon-avatar round lacking the communication
  entitlement.
- 1.4.0 (88): first build with the entitlement; the submission candidate.
