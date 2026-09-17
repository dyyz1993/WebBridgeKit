# Drel V1 submission checklist

> Current App Store state (live re-read 2026-08-31): exact Build 60 is processed,
> verified, export-compliance complete (`App 使用非豁免类加密: 否`), and present
> in the existing internal TestFlight group. The rejected Store version still
> binds Build 51, has 3/10 iPhone screenshots and 0/3 App Previews, and awaits a
> Guideline 2.1 response. Before selecting **更新审核**, bind Build 60, save the
> seven requested review-note items, attach the private physical-device
> recording, read everything back, and obtain the owner's immediate final
> confirmation.

> Build 51 is the verified baseline that entered review; the current replacement
> candidate is exact `1.0 (52)`. Builds 45 and 46 are
> superseded by the cold-launch and VoiceOver corrections in Build 47. Build 47
> is also ineligible: its SwiftUI About screen still listed V1-excluded
> capabilities. Build 48 corrected that screen locally but was not uploaded,
> because the first short-address encoder could crash for one of its 32 values.
> Build 49 was not uploaded because a fresh install could hide the copyable
> address when Keychain access was unavailable. Build 50 fixed that flow but
> Apple rejected it during processing with error 90683 because its final
> Info.plist lacked `NSCameraUsageDescription`. Build 51 keeps the compatible
> full Crockford Base32 encoder and preserves the required purpose string for
> the linked SDK's camera references. Build 52 adds the corrected V1 push
> catalog/routes and confirmed Inbox clear-all behavior. No earlier build may
> replace Build 52 after it is processed.

## Build 52 replacement delta (2026-08-29)

- [x] SuperApp and NotificationServiceExtension both report `1.0 (52)`.
- [x] Full release gate passes, including the 18-check Drel container policy.
- [x] Exact signed archive `/tmp/drel-build52-final/Drel.xcarchive` passes the
  archive surface, strict codesign, production APNs, app-group, and
  `get-task-allow=false` checks.
- [x] Build 52 uploaded exactly once; `/tmp/drel52-upload.log` records package
  processing, upload success, and export success.
- [ ] Wait for Apple processing, complete exact Build 52 export compliance, and
  install/accept it in the existing internal TestFlight group.
- [ ] Replace Build 51 with exact processed Build 52 on the existing App Store
  version/submission, then read the relationship and review state back.

## 1. Scope and public claims

- [x] V1 promise is limited to developer push, inbox, named sound, and opening
  an explicit HTTPS destination from a notification.
- [x] Store-visible app centre, gateway import, offline package, default
  web-tool startup, Bridge, command, and debug paths are excluded from V1.
- [x] App Store metadata, review notes, Support, Privacy, site copy, and
  V1-specific API documentation use the same scope.
- [x] Final archive scan confirms excluded UI markers do not appear and retains
  the camera purpose string required by Apple's static SDK scan.

## 2. Code and binary verification

- [x] `DREL_CONTAINER_ONLY` and `DREL_RELEASE_MINIMAL_SETTINGS` are fixed in
  the Release build configuration.
- [x] Server APNs implementation makes at most one visible-alert attempt per
  endpoint; alternate environment is allowed only after `BadDeviceToken`.
- [x] `bash tools/run-release-gate.sh` passes for Build 51 (14 passed, 0
  failed; 2026-08-28).
- [x] `bash tools/verify-drel-store-archive.sh <Build51.archive>` verifies:
  bundle identity, Drel display name, production APNs, no arbitrary HTTP,
  expected privacy surface, no Bridge permission UI, and no legacy source host.
- [x] Distribution signing inspection for Build 51: host and notification
  extension are signed for distribution; host has `aps-environment=production`
  and `get-task-allow=false`; both use the shared App Group and the extension
  has `get-task-allow=false` (2026-08-28).
- [x] Fresh-data signed Release simulator smoke for Build 46 (2026-08-28): Home
  reached its ready state and showed a copy-enabled `api.drel.app` address
  **without** a notification permission prompt. The permission sheet appeared
  only after the user tapped “启用通知”.
- [x] Fresh-data signed Release simulator smoke for Build 51 (2026-08-28,
  iPhone 16 Pro Test 2): Home reached ready state and showed a copy-enabled
  `api.drel.app` address with no notification, camera, or photo-library prompt.
  The earlier photo sheet on a different simulator was attributed to a stale
  unrelated app (“看见”); Build 51's localized bundle name and product screen
  both read Drel. Automated semantic tapping could not invoke the notification
  button, so the authorization sheet itself remains part of the TestFlight
  device matrix.
- [ ] Repeat the Build 51 simulator review of the Inbox empty state, minimal
  Settings surface, and About's three V1 feature claims only. `drel.app`,
  `/support/`, `/privacy/`, and `api.drel.app/health` each returned HTTP 200
  on 2026-08-28.

## 3. V1 UI and accessibility review

- [ ] Capture the actual Build 51 simulator flow: Home, notification/inbox,
  opened HTTPS destination, Settings, and no-network/permission-denied state.
- [x] Simulator review found the V1 copy consistent: Home exposes the public
  address and the explicit notification action; Inbox has a recoverable empty
  state; Settings has no unfinished gateway, Bridge, token, or offline-package
  entry; About lists only the three shipped V1 capabilities.
- [x] Simulator accessibility audit found two decorative home-card icons exposed
  as unlabeled images; Build 47 hides them from VoiceOver and gives both test
  notification inputs explicit labels and hints.
- [x] Repeated the Build 47 accessibility audit: 0 critical findings. The
  two input controls now expose their labels and hints in the UI hierarchy.

## 4. TestFlight and APNs (physical phone only)

- [x] Builds 45 and 46 were each uploaded once on 2026-08-28. Neither may be
  submitted: Build 45 has the cold-launch prompt defect and Build 46 is
  superseded by Build 47's accessibility correction.
- [x] Build 47 was uploaded once on 2026-08-28, but must not be attached or
  submitted because its About screen exposed unshipped V1 functionality.
- [x] Build 50 was uploaded exactly once on 2026-08-28, then Apple marked it
  failed with error 90683 for missing `NSCameraUsageDescription`. It must not be
  uploaded again or attached.
- [x] Uploaded exact signed Build 51 once on 2026-08-28. Xcode returned
  `Uploaded package is processing` and `Upload succeeded`; do not re-upload it.
- [x] Apple processed Build 51, export compliance was completed, and the exact
  Build 51 was attached to version 1.0 and the existing internal TestFlight
  workflow; App Store Connect was re-read before submission.
- [ ] On a TestFlight iPhone, record one result each for foreground,
  background, locked-screen, named sound, notification tap to exact HTTPS URL,
  and no delayed duplicate delivery.
- [ ] If any APNs result fails, collect server send log and device system-log
  evidence before changing code; do not retry visible alerts automatically.

## 5. App Store Connect material

- [x] Re-read the actual 1.0 record: name Drel, availability, price, tax/bank
  status, age rating, review contact, Support URL, Privacy URL, and export
  compliance.
- [x] Confirm privacy questionnaire: Device ID collected, linked, not used for
  tracking, App Functionality; re-check against the exact deployed service.
- [x] Capture and upload 1–6 final iPhone screenshots from Build 51 with no
  debug copy, test data, address/token, private content, or unsupported feature
  claims. Video is optional.
- [x] Paste the operational reviewer notes and, if needed, attach the private
  review walkthrough. Ensure every URL and review route is live without private
  credentials.
- [x] Attach only exact processed Build 51 to version 1.0 and re-read it.

## 6. Submission

- [x] Final release review: all prior checks green; no concurrent upload,
  duplicate submission, or unresolved App Store Connect validation.
- [x] Obtain the owner’s immediate confirmation naming Drel 1.0 Build 51.
- [x] Click **Submit for Review**, then re-read the submission state. Submitted
  2026-08-29; App Store Connect reports `1.0 正在等待审核` for exact Build 51.

## Not part of V1

Gateway import, offline web-tool package installation, multi-tool management,
default web-tool startup, remote Bridge/native API access, a public catalogue,
UGC, and a marketplace belong to later roadmap phases. They must not appear in
Build 51 screenshots, metadata, review notes, or visible Release navigation.
