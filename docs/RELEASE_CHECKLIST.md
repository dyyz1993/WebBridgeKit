# WebBridgeKit Release Checklist

## Drel 1.0 Store submission gate

- [x] Product identity is Drel; open-source runtime attribution remains
  WebBridgeKit.
- [x] Support and privacy URLs are live at `drel.app`.
- [x] Official push endpoint is `https://api.drel.app`.
- [x] Release is compile-time `container-only`: no web-to-native Bridge script,
  message handlers, or Bridge permission UI.
- [x] Release route context is delivered through the opened URL, including
  `appId`, route, and parameters; strong-offline pages resolve locally.
- [x] Release binary removes unused Bridge-only privacy prompts and arbitrary
  HTTP loading. It retains the Contacts, Microphone, and Speech declarations
  required by the linked WebBridgeKit SDK; runtime container-only policy still
  prevents remote pages from invoking those capabilities. Camera remains solely
  for optional gateway QR scanning.
- [x] Static policy gate passes (`bash tools/verify-drel-container-only.sh`).
- [x] Release simulator build was inspected for bundle identity and final
  permission declarations.
- [x] Build 33 was uploaded on 2026-08-25, but App Store Connect processing
  rejected it with 90683 because its build script removed required Contacts,
  Microphone, and Speech usage descriptions. Build 33 is unusable and must not
  be re-uploaded; the corrected candidate is `1.0 (34)`.
- [x] Locally exported Drel 1.0 build 34 on 2026-08-25. Final IPA inspection
  confirms Apple Distribution signing, production APNs, `get-task-allow=false`,
  required Contacts/Microphone/Speech declarations, and valid deep signing.
- [x] Build 34 was uploaded to App Store Connect; it processed successfully but
  is superseded by build 36.
- [x] Build 36 replaces the remaining Store-visible legacy gateway label with
  `api.drel.app` and compiles out test seed data that carried old source-host
  strings. Final IPA scan confirms no `shanbox` source-host marker, Apple
  Distribution signing, production APNs, and valid deep signing.
- [x] Build 36 was uploaded, processed, and received its TestFlight export
  compliance declaration on 2026-08-25. It is superseded by build 38, which
  migrates a separately persisted legacy official gateway to `api.drel.app`.
- [x] Build 38 was uploaded to App Store Connect on 2026-08-26; it is
  superseded by build 39.
- [x] Build 39 was archived with the App Store distribution profiles for both
  the main app and notification extension. It passed
  `tools/verify-drel-store-archive.sh` with `1.0 (39)`, production APNs, and
  `get-task-allow=false`, then uploaded successfully to App Store Connect on
  2026-08-26.
- [x] Apple processed build 39 on 2026-08-26. It is in the existing internal
  TestFlight group (one tester) and is ready for the exact-build device test.
- [x] Build 40 adds the Release minimal-settings policy: only the six
  first-release settings surfaces are reachable; legacy identity/key, favorite,
  history, encryption, and cache-dashboard entry points are compile-time
  excluded while their source remains recoverable. It passed the full release
  gate (12 passed, 0 failed), distribution signing and archive checks, then
  uploaded successfully to App Store Connect on 2026-08-26. Await Apple
  processing before assigning it to TestFlight.
- [x] Server `2026.08.26-2` removes automatic same-endpoint APNs retries that
  could create a delayed duplicate alert. It tries the alternate APNs
  environment only after an explicit primary-host `400 BadDeviceToken`.
- [x] Drel 1.0 does not have Apple's Critical Alerts entitlement. Build 41
  compiles the unsupported critical-alert example out of the Store catalog;
  the public server safely degrades legacy `level=critical` requests to
  time-sensitive delivery instead of claiming mute/Focus bypass.
- [x] Build 41 passed the full release gate (14 passed, 0 failed), archive
  surface checks, and App Store distribution signing checks, then uploaded
  successfully to App Store Connect on 2026-08-26. Await Apple processing
  before assigning this exact build to the internal TestFlight group.
- [x] Build 42 adds the user-selected Default Startup App: only a trusted PWA
  app identity is stored, cold launch opens its root page, and a push still
  takes precedence. It passed the full release gate (14 passed, 0 failed),
  Apple Distribution archive checks (production APNs and `get-task-allow=false`
  for host and notification extension), and uploaded successfully to App Store
  Connect on 2026-08-26 (Delivery UUID
  `3d76fe2d-988b-4d30-ba7a-e316c6f7d642`). Await Apple processing before
  assigning this exact build to the internal TestFlight group.
- [x] Full automatic release acceptance passed on 2026-08-26: 15 gates passed,
  0 failed (`build/reports/next-phase-acceptance.md`).
- [x] Build 42 was installed from TestFlight on a paired iPhone. A foreground
  APNs smoke push arrived once only; the previously observed delayed duplicate
  did not recur. Background, locked-screen, sound, and tap-route checks remain
  outstanding.
- [x] Build 43 introduces grouped 16-character push addresses and a backward-
  compatible migration: legacy 43-character addresses remain registered while
  the app begins using the short successor. Server `2026.08.27-1` was deployed
  first and public route regression passed 28/28. The signed archive passed
  `tools/verify-drel-store-archive.sh` and the full release gate (14/14).
  It was uploaded successfully to App Store Connect on 2026-08-27 (Delivery
  UUID `c28af043-1f34-4975-baf7-e773f999794e`) and is awaiting Apple's build
  processing before it can be assigned to the internal TestFlight group.
- [x] The next Store release candidate intentionally limits the push-example
  catalog to the current V1 promise: plain notification, notification-to-web-
  page routing, and named sound. SDK/debug examples (Markdown, OTP, QR, image,
  chat, approval, auto-copy, replacement, and similar) are not marketed in the
  release product until individually accepted. This change is after Build 43
  and therefore requires a later build to reach TestFlight.
- [x] Build 44 contains the feature-list correction and was uploaded once to
  App Store Connect on 2026-08-27 (Delivery UUID
  `ff475d8f-c306-4c2d-ab3c-253af7639482`). It is superseded by Build 45 because
  its Store-visible app centre, gateway import, offline-package claims, and
  camera prompt did not match the frozen V1 scope.
- [x] Build 47 compiles out the Store-visible app centre, gateway import,
  default web-tool startup, offline-package claims, and camera permission;
  it also must not prompt for notification permission until the user chooses
  “启用通知”. Build 45 was uploaded successfully but is superseded by this
  cold-launch correction. Build 46 then corrected the cold-launch flow but is
  superseded by Build 47's VoiceOver semantics correction. Build 47 passed the
  full release gate and archive inspection, then uploaded successfully once.
  It is nevertheless ineligible because the Store-visible SwiftUI About screen
  still listed unshipped V1 functionality.
- [x] Build 50 was uploaded once but Apple processing failed with 90683 because
  the Release post-build script removed `NSCameraUsageDescription` while the
  linked SDK still referenced camera APIs. It must not be retried or attached.
  Build 51 preserves that required purpose string and is the only next candidate.
  Build 49 was not uploaded because
  a fresh install could hide its copyable endpoint when Keychain access failed.
  Build 50 had passed the complete 14/14 release gate, Apple Distribution archive
  inspection (production APNs and `get-task-allow=false` for host and extension),
  and a fresh-data Release simulator smoke before its single permitted upload.
  It was uploaded once on 2026-08-28; Xcode reported “Upload succeeded”, but
  App Store Connect later reported the 90683 processing failure.
  It fixes the About screen and replaces the crash-prone 31-symbol short-address
  encoder with a 32-symbol Crockford Base32 encoder while still accepting legacy
  short and long addresses.
- [ ] Test the exact processed TestFlight build 51 on a clean physical iPhone: notification
  consent, push delivery, background/locked route opening, and a named sound.
- [ ] Complete App Store Connect privacy, age rating, availability, review
  contact, and pricing fields.
- [ ] Capture and upload the required Store screenshot set from the final
  TestFlight build (minimum one; Drel's recommended six-frame narrative is in
  `docs/release/app-store-metadata.md`). App Preview video is optional.
- [ ] After physical TestFlight push verification, prepare the private reviewer
  walkthrough in `docs/release/app-review-walkthrough.md` if the review notes
  and temporary review flow are not independently reproducible.
- [ ] Paste the current review notes and attach the exact processed build.

See `docs/release/app-store-metadata.md` for the approved copy and the order of
the remaining human-controlled steps.

## Next Phase Integration

- [x] Official, gateway and strong-offline commits share the recorded base and reproduce at the integration SHA.
- [x] Official home has no required gateway form and notification enablement remains explicit.
- [x] Gateway validation precedes activation; secret fields are rejected; cross-identity grants are cleared by model tests.
- [x] Strong-offline fixtures and installer tests cover digest validation and rollback.
- [x] Seven message types and approval consent contracts pass.
- [x] AppTemplate boundary gate passes independently.
- [x] SwiftLint, design lint and crash scan pass.
- [x] `bash tools/verify-next-phase-acceptance.sh --full` passed 15 automatic gates on 2026-08-26.
- [ ] Complete paid-team physical APNs, background and lock-screen observations.

Simulator/open-source recommendation is GO-WITH-MANUAL-GATE. Do not label real APNs available until both unchecked items are complete.
