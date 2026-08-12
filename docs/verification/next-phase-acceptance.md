# Next Phase Integration Acceptance

Date: 2026-08-12

Integration commit: `89acd7c9eb3478c709246c9640320dd387bc8cb6`

Base commit: `60f52dfc9870958b2f10879e3f8aed2584028eb1`

Simulator: iPhone 16 Pro UI Test, iOS 18.3, UDID `79EA5C9F-C501-47FD-8D1B-2DE497F5CDD0`

Xcode: 26.6 (`17F113`)

Implementation commits verified: official `828bdc9` (source `59cb212`), gateway `2a5541b` (source `d14e810`), strong offline `89acd7c` (source `4ac095a`). Handoff evidence came from the coordinator summary in this task session; no separate handoff files were supplied.

## Result

Release recommendation: **GO-WITH-MANUAL-GATE** for simulator/open-source integration; physical APNs release remains gated on a Push-capable paid Apple Developer Program profile and real-device observation.

| Module | Scenario | Command | Result | Evidence | Limitation |
|---|---|---|---|---|---|
| Official | Configuration-free home and seven examples | `NextPhaseAcceptanceTests`, official handoff | PASS with one automation visibility debt | XcodeBuildMCP result bundle; official handoff 4/4 identity tests | Real APNs is manual; nested SwiftUI address text identifier was not exposed consistently |
| Self-hosted | Parse, validate, report, secret rejection, transaction | Models tests and `verify-open-gateway.sh` | PASS | 23/23 implementation tests; public gateway 5/5; report visible in integration UI | Bottom activation button was outside the XCUITest viewport; protocol and explicit-activation model are green |
| Strong offline | Hash chain, path/origin limits, atomic rollback | `verify-strong-offline-package.sh` and implementation tests | PASS | fixture 4/4; installer 9/9; model/launch 22/22 | Full cache regression is a separate full-mode gate |
| Messages | Plain, Markdown, OTP, QR, image, chat, approval | `verify-message-types-v1.sh` | PASS | 15/15 | Simulator routing is not APNs delivery |
| Approval | Pending state and explicit user consent | `verify-approval-v1.sh`; integration Inbox journey | PASS | 11/11; Markdown + pending approval UI journey passed | Callback availability outside fixtures remains external |
| Server | Registration persistence and routes | `cd Server && swift test` | PASS | 36 tests in 7 suites | Local route semantics only |
| AppTemplate | Product boundary and release surface | `run-template-gate.sh` | PASS | 5/5 | Independent from SuperApp UI |
| Quality | Lint, design, crash | `swiftlint`, `ci-lint`, crash scan | PASS | CI 17/17; crash `total: 0` | Five documented pre-existing design warnings |

The first `verify-next-phase-acceptance.sh` core run completed services, boundaries, message, approval, offline, gateway, Server and AppTemplate checks, then the local SwiftLint subprocess failed to load `sourcekitdInProc.framework` and hung. The process was terminated; the independent SwiftLint run earlier in the same QA session had exited 0, and `ci-lint.sh` passed 17/17. This is retained as an execution-environment limitation rather than silently reported as a clean one-command run.

## Integration Audit

- All three implementation commits descend from the same base and reproduce at the integration commit.
- Model 1 stayed out of gateway/offline/AppTemplate paths; model 2 stayed out of official/offline/AppTemplate/Server paths; model 3 stayed out of official/gateway UI/AppTemplate/Server paths.
- Shared localization merged only the expected `official.push.*` and `gateway.*` additions.
- `AppTemplate/**` has no integration diff.
- No duplicate gateway/offline identity type or second product state source was found in the integration diff.

## QA Infrastructure Fixes

The integration UI target did not compile because several existing tests called unavailable `XCUIElementQuery.isEmpty`. QA replaced those checks with `count` and updated one obsolete multi-alert gateway test to the current one-page identifiers. No production source was changed.

## UI Journey Evidence

The focused acceptance suite compiled and ran after the QA fixes. Four of six focused tests passed directly: seven message examples, secret rejection, Markdown plus pending approval consent boundary, and accessibility-size gateway controls. The other two reached their expected business states but failed on offscreen/nested SwiftUI element visibility:

- Gateway: `gateway.report`, host, health endpoint, manifest endpoint and key ID all appeared; the bottom activation button was outside the queryable viewport.
- Official home: ready action and copy control appeared; the nested address text identifier was not independently exposed by XCUITest.

These are recorded as non-blocking automation debt, not inferred product PASS for physical devices.

## Strong Offline Evidence Boundary

The deterministic fixture and installer/model tests prove the signed parent manifest to resource-manifest digest to per-file digest chain, Application Support activation, unsafe path/origin rejection and rollback preservation. The current product UI does not expose a dedicated stable end-to-end installer journey identifier, so offline UI status remains a follow-up automation surface. WebKit-cache clearing and reliable network blocking are intentionally kept out of XCUITest.

## Manual Real-Device Gate

- Use a paid Apple Developer Program team/profile with Push Notifications and confirm signed `aps-environment`.
- Observe permission prompt only after the explicit enable action.
- Observe APNs token registration and receipt of plain, Markdown and OTP notifications.
- Verify tap routing, background delivery and lock-screen behavior.
- Verify notification Settings handoff on a physical iPhone.

Public shanbox and gateway checks prove route/process/fixture reachability only; they do not satisfy these manual rows.
