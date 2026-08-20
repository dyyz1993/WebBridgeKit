# SDK, Template, and Product App Roadmap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Continue the complete WebBridgeKit App as the product development mainline while extracting reusable behavior into the SDK continuously and keeping AppTemplate as a safe, minimal integration starter.

**Architecture:** `SuperApp` owns end-user journeys and information architecture, `Sources` owns reusable native-enhanced PWA runtime contracts, and `AppTemplate` consumes only stable public SDK APIs. Development proceeds by vertical product slices: prove the reusable contract first, complete the product flow second, then update the minimal template only after the API is stable. Official hosting and self-hosting share the same complete app; AppTemplate is never the self-hosted client.

**Tech Stack:** Swift 5, SwiftUI + UIKit, WKWebView, WebBridgeKit framework targets, Hummingbird server, XcodeGen, CocoaPods, XCTest/XCUITest, Bash verification scripts.

---

## Shared-workspace safety

The current worktree already contains user-owned changes. Every commit checkpoint below is optional and requires explicit user approval. Never stage an entire directory in this worktree; stage only the exact files changed by the active task after reviewing `git diff -- <path>`. Implementation and verification may proceed without committing.

## Non-negotiable placement rules

Before implementing any task, classify it with this decision table:

| Question | Destination |
|---|---|
| Would two unrelated host apps need the same behavior without sharing product UI? | `Sources/` SDK |
| Is this only the minimum wiring needed to initialize and demonstrate a stable SDK API? | `AppTemplate/` |
| Is this a user journey, navigation hierarchy, copy decision, or WebBridgeKit product screen? | `SuperApp/` |
| Is this the official/self-hosted push, approval, or gateway service contract? | `Server/` + `docs/api/` |
| Is this diagnostic or showcase UI? | Debug Center or template DEBUG-only tooling, never the product main tabs |

Do not copy a `SuperApp` controller into `AppTemplate`. Do not move a product view into `Sources` merely to reuse visual code. Extract protocols, models, services, and generic runtime behavior; keep composition and product copy in the App.

## Delivery cadence

For every product slice:

1. Write the SDK/server contract test when reusable behavior is involved.
2. Implement the smallest reusable contract in `Sources/` or `Server/`.
3. Build the complete user journey in `SuperApp/`.
4. Run simulator UI and contract regressions.
5. Update `AppTemplate` only when a developer needs a minimal example of the now-stable API.
6. Run the AppTemplate build and template guard.

The template therefore follows each stable milestone; it does not lead product design and is not postponed until the entire App is finished.

---

### Task 1: Add an automated layer-boundary guard

**Files:**
- Create: `tools/verify-deliverable-boundaries.sh`
- Modify: `tools/ci-lint.sh`
- Modify: `.github/workflows/ci.yml`
- Test: `tools/verify-deliverable-boundaries.sh`

**Step 1: Write a failing boundary script**

Make the script fail when:

- `AppTemplate/` contains literal credentials such as `test_key`, APNs tokens, API secrets, or private keys.
- `AppTemplate` is missing from the generated Xcode schemes.
- `SuperApp` imports source files from `AppTemplate`.
- `Sources/` imports the `SuperApp` module or references `SuperApp/Sources`.
- README no longer identifies SDK, AppTemplate, and the complete App separately.

The script must print a per-check PASS/FAIL summary and exit non-zero on failure.

**Step 2: Run the guard and verify it fails**

Run:

```bash
bash tools/verify-deliverable-boundaries.sh
```

Expected: FAIL because `AppTemplate/Sources/AppDelegate.swift` and `DebugPanelBridge.swift` contain `test_key`.

**Step 3: Wire the guard into quality tooling**

Call the new script from `tools/ci-lint.sh` and add a CI step before the main product build. Extend SwiftLint inputs from `Sources/ SuperApp/Sources/` to include `AppTemplate/Sources/`.

**Step 4: Verify CI shell syntax**

Run:

```bash
bash -n tools/verify-deliverable-boundaries.sh
bash -n tools/ci-lint.sh
```

Expected: both commands exit 0.

**Step 5: Commit checkpoint**

```bash
git add tools/verify-deliverable-boundaries.sh tools/ci-lint.sh .github/workflows/ci.yml
git commit -m "test(architecture): guard SDK template and app boundaries"
```

---

### Task 2: Make AppTemplate safe and minimal

**Files:**
- Create: `AppTemplate/Sources/AppTemplateConfiguration.swift`
- Modify: `AppTemplate/Sources/AppDelegate.swift`
- Modify: `AppTemplate/Sources/TabBarController.swift`
- Modify: `AppTemplate/Sources/Debug/DebugPanelBridge.swift`
- Modify: `AppTemplate/Sources/RootViewController.swift`
- Modify: `README.md`
- Test: `tools/verify-deliverable-boundaries.sh`

**Step 1: Add a configuration object with disabled defaults**

Define explicit optional configuration for:

- initial PWA URL,
- optional Bark/device key,
- optional local diagnostic server,
- signed command validation.

Defaults must not start MessageEngine channels, a webhook server, AIHTTPServer, or an unsigned CommandParser. No credential may be embedded in source.

**Step 2: Replace unconditional engine startup**

Keep `WebBridgeKit.shared.initialize()` as the minimal SDK bootstrap. Start optional services only when configuration explicitly enables them. Signature verification must not default to `false` for a production-capable path.

**Step 3: Reduce primary navigation**

Release builds keep one minimal host page. DEBUG may expose a single `开发工具` entry or shake gesture; it must not create six primary tabs for cache, messages, command, theme, and diagnostics.

**Step 4: Remove hard-coded debug claims**

Replace `Bark Key: test_key`, `Webhook: port 8765`, and `Status: Running` with configuration-derived state. When unconfigured, show `未配置`/`Disabled` without implying a service is active.

**Step 5: Document template scope**

In README, add a short “Choose your starting point” section:

- install/use the complete App,
- integrate the SDK,
- start a custom host from AppTemplate.

**Step 6: Run the boundary guard**

Run:

```bash
bash tools/verify-deliverable-boundaries.sh
```

Expected: all checks pass and no literal credential remains.

**Step 7: Build AppTemplate**

Regenerate first because `project.yml` is the source of truth:

```bash
xcodegen generate
pod install
xcodebuild build \
  -workspace WebBridgeKit.xcworkspace \
  -scheme AppTemplate \
  -sdk iphonesimulator \
  -arch arm64 \
  -derivedDataPath /tmp/wbk-template-dd \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED`.

**Step 8: Commit checkpoint**

```bash
git add AppTemplate README.md project.yml
git commit -m "refactor(template): make SDK starter safe and minimal"
```

---

### Task 3: Establish independent release gates for all deliverables

**Files:**
- Create: `tools/run-template-gate.sh`
- Modify: `tools/run-release-gate.sh`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/verification/module-availability-verification.md`

**Step 1: Add the template gate**

The gate runs:

1. the layer-boundary guard,
2. SwiftLint for `AppTemplate/Sources`,
3. an AppTemplate simulator build,
4. a static scan proving no literal credential or private key exists,
5. a Release build check proving DEBUG showcase tabs are absent.

**Step 2: Keep the product gate independent**

Do not make SuperApp release readiness depend on template UI snapshots. `tools/run-release-gate.sh` continues to verify the product App; it invokes the boundary guard but reports AppTemplate readiness separately.

**Step 3: Add CI builds for both applications**

The build job must compile:

- `SuperApp` as the complete product,
- `AppTemplate` as the starter.

A template failure must identify the AppTemplate scheme rather than appearing as a framework or product-App failure.

**Step 4: Split verification status**

Add separate report rows for SDK semantics, AppTemplate starter readiness, SuperApp simulator readiness, and SuperApp real-device/APNs readiness.

**Step 5: Run both gates**

Run:

```bash
bash tools/run-template-gate.sh
bash tools/run-release-gate.sh
```

Expected: template gate passes. Product release gate may remain blocked only by explicitly recorded signing/device prerequisites, not template state.

**Step 6: Commit checkpoint**

```bash
git add tools .github/workflows/ci.yml docs/verification/module-availability-verification.md
git commit -m "ci: verify template and product app independently"
```

---

### Task 4: Freeze and verify the first complete product slice

**Scope:** Push submission -> Inbox -> native/Markdown detail -> PWA route or Approval response.

**Files:**
- Modify as required: `Sources/Message/`
- Modify as required: `Sources/Runtime/`
- Modify as required: `SuperApp/Sources/Controllers/Message/`
- Modify as required: `SuperApp/Sources/Controllers/Tab/InboxViewController.swift`
- Modify as required: `SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift`
- Modify as required: `Server/Sources/WebBridgeServer/`
- Test: `Tests/MessageTests/`
- Test: `Tests/ModelsTests/`
- Test: `Server/Tests/WebBridgeServerTests/`
- Test: `SuperAppUITests/DeepVerificationTests.swift`

**Step 1: Write a field-to-renderer contract table**

Update `docs/api/message-types-v1.md` so every accepted API field maps to one of:

- Inbox summary,
- native detail renderer,
- trusted PWA route,
- Approval v1 lifecycle,
- collapsed technical metadata,
- rejected field.

No accepted field may silently disappear.

**Step 2: Prove reusable parsing and lifecycle behavior first**

Run focused SDK/server tests before UI tests:

```bash
bash tools/verify-message-types-v1.sh
bash tools/verify-approval-v1.sh
cd Server && swift test
```

Expected: zero failures.

**Step 3: Complete the product journey**

Verify the App handles plain, Markdown, OTP, QR, image, chat, and Approval v1, including pending/resolved approval state and explicit user consent. Keep product navigation and presentation in SuperApp; extract only generic parsing, routing, security, and lifecycle code.

**Step 4: Run the simulator interaction suite**

Run the existing focused notification and home UI tests plus the cross-route fixture. Expected: all supported message types are reachable, Markdown renders offline, approval state updates, and `appId + route + params` opens the trusted PWA without authorizing a sensitive action.

**Step 5: Evaluate template impact**

If no new public SDK initialization is required, do not change AppTemplate. If a stable public API was added, add one minimal example and rerun `tools/run-template-gate.sh`.

**Step 6: Commit checkpoint**

```bash
git add Sources SuperApp Server Tests SuperAppUITests docs/api AppTemplate
git commit -m "feat(app): complete push to action product slice"
```

---

### Task 5: Complete official and self-hosted onboarding states

**Files:**
- Modify: `SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift`
- Modify: `SuperApp/Sources/Controllers/Settings/GatewayConfigurationViewController.swift`
- Modify as required: `Sources/Runtime/`
- Modify: `docs/guides/official-quickstart.md`
- Modify: `docs/guides/self-hosted-gateway-import.md`
- Test: `Tests/ModelsTests/HTMLAppGatewayOnboardingTests.swift`
- Test: `SuperAppUITests/ModuleAvailabilityTests.swift`

**Step 1: Add missing-state tests**

Cover official ready, official unavailable/retry, no installed PWA, QR import, paste import, invalid HTTPS/signature, confirmation, switching, and removal.

**Step 2: Keep gateway validation generic**

Origin validation, signature verification, trust isolation, and permission-ledger reset belong in `Sources/Runtime`. Screen layout, copy, and navigation remain in SuperApp.

**Step 3: Capture product screenshots**

Capture the official default, empty, error, successful import, and confirmation states in light and dark mode. Do not add these product screens to AppTemplate.

**Step 4: Run model and UI regressions**

Expected: official users never see a blocking gateway form; self-hosted users complete one QR/paste import with explicit confirmation; switching gateways does not retain old grants.

**Step 5: Commit checkpoint**

```bash
git add Sources/Runtime SuperApp docs/guides Tests SuperAppUITests
git commit -m "feat(app): complete hosted and self-hosted onboarding"
```

---

### Task 6: Finish release evidence on a real iPhone

**Files:**
- Modify as evidence changes: `docs/verification/module-availability-verification.md`
- Modify as needed: `tools/verify-real-device-push-readiness.sh`
- Modify as needed: `tools/run-real-device-smoke.sh`
- Modify: `docs/RELEASE_CHECKLIST.md`

**Prerequisite:** A paid Apple Developer Program team, Push-enabled App ID, provisioning profile, APNs credentials, and a paired iPhone. Do not attempt to bypass this prerequisite by removing entitlements.

**Step 1: Verify signing and installation**

Run:

```bash
bash tools/run-real-device-smoke.sh
bash tools/verify-real-device-push-readiness.sh
```

Expected production signal: real-device build/install/launch passes; signed app contains `aps-environment`; automatic readiness has zero failures.

**Step 2: Perform manual APNs/Bark observations**

On the physical phone verify:

- notification permission,
- foreground/background/locked receipt,
- Bark-compatible GET and structured POST,
- notification tap to Markdown detail,
- tap to exact trusted PWA route,
- pending approval response and resolved state refresh.

**Step 3: Record exact evidence**

Update the verification report with commands, counts, device/OS, report paths, and screenshots. Do not mark APNs or Bark available from server-route evidence alone.

**Step 4: Run the final release gates**

```bash
bash tools/run-template-gate.sh
bash tools/run-release-gate.sh
bash tools/verify-module-availability-report.sh
```

Expected: zero failed gates; only explicitly accepted manual observations remain.

**Step 5: Commit checkpoint**

```bash
git add tools docs/verification docs/RELEASE_CHECKLIST.md
git commit -m "test(release): record real-device product readiness"
```

---

### Task 7: Decide whether to rename the internal SuperApp target

**Files:**
- Create if accepted: `docs/adr/0003-product-target-naming.md`
- Modify only if accepted: `project.yml`
- Modify only if accepted: `.github/workflows/`
- Modify only if accepted: `tools/`

**Step 1: Evaluate after release gates are green**

Compare:

- keeping `SuperApp` as an internal technical name while shipping the display name WebBridgeKit,
- renaming the target/product/archive artifacts to WebBridgeKitApp.

**Step 2: Prefer no rename unless it improves external distribution**

Do not mix target renaming into product feature work. A rename affects CI, DerivedData paths, archive tooling, crash scanning, UI test host names, and verification reports.

**Step 3: Record the decision in ADR-0003**

Expected: either an explicit accepted migration with a complete path inventory, or a documented decision to retain `SuperApp` internally.

---

## Milestones and exit criteria

### Milestone A: Clean foundation

- Boundary guard passes.
- AppTemplate contains no credentials or automatically running insecure debug services.
- Both AppTemplate and SuperApp compile independently.

### Milestone B: Product beta complete

- Push-to-Inbox-to-detail/PWA/approval vertical slice is green.
- Official and self-hosted onboarding states are complete.
- Simulator UI, message contract, approval lifecycle, dark mode, and compact layout gates pass.

### Milestone C: Release candidate

- Paid-team signing and real-device installation pass.
- APNs/Bark receipt and tap routing are observed on a physical phone.
- SDK, AppTemplate, and complete App have independent release evidence.
- No P0/P1 product, security, crash, or accessibility issue remains.

## Immediate execution batch

Start with Tasks 1-3 only. They establish the guardrails and clean the template without delaying ongoing product development. After those pass, resume the complete App with Task 4 rather than expanding the template further.
