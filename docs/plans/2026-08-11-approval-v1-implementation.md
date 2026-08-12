# Approval v1 Implementation Plan

> **For Claude:** Implement task-by-task with tests before production code. Do not commit in this dirty workspace.

**Goal:** Add a shallow, machine-verifiable Approval v1 protocol supporting native personal approvals, official status polling, optional signed webhook delivery, and custom web/PWA presentation.

**Architecture:** The Swift server normalizes `/push` requests into Approval v1, persists native approvals under `DATA_DIR`, accepts the first valid device response, exposes an authenticated status endpoint, and records webhook delivery separately. The iOS host receives only safe render/action fields, renders native actions, submits to the configured server, and continues to route web/PWA modes without treating push data as authorization.

**Tech Stack:** Swift 6, Hummingbird 2, Swift Crypto, UIKit, XCTest/Swift Testing, JSON Schema, shell verification.

---

### Task 1: Machine-readable contract

**Files:**
- Create: `docs/api/schemas/message-v1.schema.json`
- Create: `docs/api/schemas/approval-submission-v1.schema.json`
- Create: `docs/api/schemas/approval-response-v1.schema.json`
- Create: `docs/api/schemas/approval-status-v1.schema.json`
- Create: `docs/api/approval-v1.md`
- Modify: `docs/api/push-v2.md`

**Verification:** Parse all schemas as JSON and validate canonical native/web/PWA fixtures with the repository verification script.

### Task 2: Server approval state and routes

**Files:**
- Create: `Server/Sources/WebBridgeServer/Models/ApprovalModels.swift`
- Create: `Server/Sources/WebBridgeServer/Services/ApprovalStore.swift`
- Create: `Server/Sources/WebBridgeServer/Routes/ApprovalRoutes.swift`
- Modify: `Server/Sources/WebBridgeServer/Configuration.swift`
- Modify: `Server/Sources/WebBridgeServer/entrypoint.swift`
- Modify: `Server/Sources/WebBridgeServer/Models/PushPayload.swift`
- Modify: `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift`
- Modify: `Server/Sources/WebBridgeServer/Services/APNsService.swift`
- Test: `Server/Tests/WebBridgeServerTests/ApprovalRoutesTests.swift`

**Verification:** `cd Server && swift test --filter ApprovalRoutesTests` covers creation, polling, first-response-wins, revision conflict, expiration, secret-field stripping, and persistence.

### Task 3: Signed webhook delivery

**Files:**
- Create: `Server/Sources/WebBridgeServer/Services/ApprovalWebhookService.swift`
- Modify: `Server/Sources/WebBridgeServer/Services/ApprovalStore.swift`
- Modify: `Server/Sources/WebBridgeServer/Routes/ApprovalRoutes.swift`
- Test: `Server/Tests/WebBridgeServerTests/ApprovalWebhookTests.swift`

**Verification:** Tests prove HTTPS/private-network validation, deterministic HMAC headers, delivery-state separation, and idempotent retry records.

### Task 4: iOS native approval rendering and response

**Files:**
- Modify: `Sources/Message/Protocols/MessageChannel.swift`
- Modify: `SuperApp/Sources/AppDelegate.swift`
- Modify: `SuperApp/Sources/Managers/PushRelayManager.swift`
- Modify: `SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift`
- Modify: `SuperApp/Sources/Controllers/Message/MessageDetailViewController+Actions.swift`
- Create: `SuperApp/Sources/Services/ApprovalResponseClient.swift`
- Modify: localized strings in `SuperApp/Resources/*/Localizable.strings`
- Test: `Tests/MessageTests/MessagePayloadTests.swift`
- Test: focused UI tests in `SuperAppUITests/ModuleAvailabilityTests.swift`

**Verification:** Model tests prove decoding; simulator UI proves native actions, reason input, submitting, success/conflict/error states, and web/PWA routing.

### Task 5: Conformance and regression gates

**Files:**
- Create: `tools/verify-approval-v1.sh`
- Modify: `docs/verification/module-availability-verification.md`

**Verification:** Run schema checks, `cd Server && swift test`, iOS focused tests/build, `swiftlint --quiet`, `bash tools/ci-lint.sh`, and `bash scripts/scan-crash-logs.sh --json`. The approval verifier must report zero failures.
