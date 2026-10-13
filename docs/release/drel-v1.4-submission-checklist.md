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

## 0. Signing prerequisite (before archiving Build 88)

- [x] The **Communication Notifications** capability is enabled on the
  Drel App ID: the Xcode-managed team profile pulled on 2026-10-09
  11:01 embeds `com.apple.developer.usernotifications.communication`.
- [ ] Regenerate and re-download the `WebBridgeKit App Store`
  distribution profile. The locally cached copy
  (`~/Library/MobileDevice/Provisioning Profiles/
  webbridgekit-appstore-main.mobileprovision`, created 2026-08-19)
  predates the capability and lacks the entitlement, so archiving
  Build 88 with it fails codesign or strips the entitlement. The NSE
  distribution profile is unaffected (the extension does not declare
  the communication entitlement).
- [ ] After archiving, inspect the signed binary: the host app must show
  `com.apple.developer.usernotifications.communication` in its entitlements
  alongside `aps-environment=production` and `get-task-allow=false`.

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

- [ ] `bash tools/run-release-gate.sh` passes for Build 88.
- [ ] `bash tools/verify-drel-container-only.sh` passes (39/39 baseline
  from the 1.0.1 round).
- [ ] `bash tools/verify-drel-store-archive.sh <Build88.archive>` passes:
  bundle identity, Drel display name, production APNs, shared App Group,
  NSE embedded (`tools/fix-nse-embed.sh` if needed), no arbitrary HTTP.
- [ ] `bash tools/verify-strong-offline-package.sh` passes for the bundled
  offline demo package.
- [ ] Fresh-data signed Release simulator smoke for Build 88: Home reaches
  ready state; favorites list renders (time-desc + pinned floats); no
  notification/camera/photo prompt at first launch.
- [ ] Favorites regression: tap a favorite (device SIGTRAP class bug fixed
  in `93e73295`), delete and pin take effect on first attempt
  (`37b57d4b`), swipe gestures match the inbox.

## 3. UI review

- [ ] Capture the actual Build 88 simulator flow: Home, Inbox (80pt rows,
  right-swipe pin), message detail (markdown links), favorites (pin/full
  swipe/fullscreen reopen), immersive web view first frame, Settings,
  offline app open.
- [ ] Light and Dark Mode both pass; layer borders re-resolve on trait
  changes (`a6e5d139`).
- [ ] No text truncation or overlap on the new favorites and inbox cells.

## 4. TestFlight and APNs (physical phone only)

- [ ] Upload exact signed Build 88 exactly once; record the upload log.
- [ ] **Icon avatar verification**: send a push with a custom icon/avatar
  payload and confirm the sender avatar renders in the app-icon slot on
  the lock screen. This is the regression the entitlement fix exists for;
  test on at least one iOS 18 device.
- [ ] Repeat one result each for foreground, background, locked-screen,
  named sound, and notification tap to an explicit HTTPS destination; no
  delayed duplicate delivery.
- [ ] Verify a `drel://app` link opens a registered HTML app from both
  Safari and a notification on device.
- [ ] If any APNs result fails, collect server send log and device
  system-log evidence before changing code; do not retry visible alerts
  automatically.

## 5. App Store Connect material

- [ ] Re-read the live 1.0 record; create the new 1.4.0 version record.
- [ ] Attach fresh iPhone screenshots from Build 88 — use
  `docs/release/media/drel-app-store-v3/final/` only if it was re-captured
  after builds 81–87 (favorites UI changed); otherwise re-capture. No
  debug copy, test data, address/token, or private content.
- [ ] Update the review notes from the Build 60 template: keep the
  physical-device recording approach, add sections for `drel://app`
  launch and the icon avatar (both are new visible behaviors that App
  Review has not seen; the 1.0 rejection was Guideline 2.1).
- [ ] Re-check the privacy questionnaire against the deployed service
  (Device ID collection unchanged? Kingfisher avatar cache is on-device
  disk cache, not tracking).
- [ ] Complete export compliance for the processed Build 88.
- [ ] Attach only exact processed Build 88 to version 1.4.0 and re-read it.

## 6. Submission

- [ ] Final release review: all prior checks green; no concurrent upload
  or unresolved App Store Connect validation.
- [ ] Obtain the owner's confirmation naming exact "Drel 1.4.0 (88)".
- [ ] Click **Submit for Review**, then re-read the submission state.

## Build history notes

- 1.0 (44–52, 60): first submission round, Guideline 2.1 rejection on 51,
  review-response Build 60. Never reuse or re-upload these.
- 1.0.1 (61–65): TestFlight patch round, UI review fixes (2026-09-11).
- 1.4.0 (68–87): Drel14Release generation; (80) was the RC and is
  superseded; (85–87) icon-avatar round lacking the communication
  entitlement.
- 1.4.0 (88): first build with the entitlement; the submission candidate.
