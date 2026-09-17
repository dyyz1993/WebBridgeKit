# Drel Self-hosted Encrypted Push Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver an optional Docker-deployed Drel push server that pairs with
the official client, encrypts per-device payloads, and sends them directly to APNs.

**Architecture:** Extend the existing Swift `Server/` modular monolith rather
than introduce a second Go server. Add a versioned pairing/envelope contract in
the reusable SDK, then connect the SuperApp and Notification Service Extension
to that contract. Existing official push remains untouched.

**Tech Stack:** Swift 6, Hummingbird, swift-crypto/CryptoKit, XCTest/Swift
Testing, UIKit, Docker.

---

### Task 1: Define protocol models and crypto contract

**Files:**
- Create: `Sources/Message/EncryptedPushEnvelope.swift`
- Create: `Tests/MessageTests/EncryptedPushEnvelopeTests.swift`
- Modify: `Sources/Message/PushCipher.swift`

**Steps:**
1. Write tests for envelope encode/decode, X25519 interoperability, tamper
   rejection, expiry rejection, and stable message IDs.
2. Run the focused MessageTests and confirm the missing types fail.
3. Implement versioned envelope structs, base64url helpers, X25519 + HKDF +
   AES-GCM seal/open primitives, and strict payload-size validation.
4. Run the focused tests and the existing PushCipher contract tests.

### Task 2: Add secure per-install self-host identity storage

**Files:**
- Create: `SuperApp/Sources/Services/SelfHostedPushIdentityStore.swift`
- Create: `Tests/MessageTests/SelfHostedPushIdentityStoreTests.swift`
- Modify: `SuperApp/SuperApp.entitlements`
- Modify: `NotificationServiceExtension/NotificationServiceExtension.entitlements`
- Modify: `NotificationServiceExtension/PushCrypto.swift`

**Steps:**
1. Write tests for first creation, stable reload, rotation, and public-key
   export without private-key disclosure.
2. Add the shared Keychain access group and a Keychain-backed X25519 store.
3. Teach the NSE to open `drel.push-envelope.v1` with the shared private key.
4. Verify release-simulator compilation and focused crypto tests.

### Task 3: Add self-hosted pairing and registration endpoints

**Files:**
- Create: `Server/Sources/WebBridgeServer/Routes/SelfHostedPushRoutes.swift`
- Create: `Server/Sources/WebBridgeServer/Models/SelfHostedPushModels.swift`
- Modify: `Server/Sources/WebBridgeServer/Services/TokenStore.swift`
- Modify: `Server/Sources/WebBridgeServer/Configuration.swift`
- Modify: `Server/Sources/WebBridgeServer/entrypoint.swift`
- Modify: `Server/Tests/WebBridgeServerTests/PushRoutesTests.swift`
- Modify: `Server/Tests/WebBridgeServerTests/TokenStoreTests.swift`

**Steps:**
1. Add failing route/store tests for `/ping`, `/.well-known/drel-push.json`,
   one-time pairing, registration with a public key, and exact revocation.
2. Implement versioned descriptor, token store migration, pairing-token issue/
   consume logic, HTTPS-production validation, and controlled error responses.
3. Run `swift test` in `Server/`.

### Task 4: Encrypt and deliver self-hosted requests

**Files:**
- Modify: `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift`
- Modify: `Server/Sources/WebBridgeServer/Services/APNsService.swift`
- Create: `Server/Sources/WebBridgeServer/Services/SelfHostedEnvelopeService.swift`
- Modify: `Server/Tests/WebBridgeServerTests/PushRoutesTests.swift`

**Steps:**
1. Add failing tests for server-side envelope creation, pre-encrypted
   passthrough, duplicate message rejection, expiry, and plaintext-free APNs
   payloads.
2. Implement envelope generation using registered public keys and attach only
   the generic mutable-content shell to APNs.
3. Preserve existing official/Bark routes and at-most-once APNs behavior.
4. Run all server tests.

### Task 5: Build SuperApp pairing journey

**Files:**
- Create: `SuperApp/Sources/Services/SelfHostedPushService.swift`
- Create: `SuperApp/Sources/Controllers/Settings/SelfHostedPushConfigurationViewController.swift`
- Modify: `SuperApp/Sources/Controllers/Settings/GatewayConfigurationViewController.swift`
- Modify: `SuperApp/Sources/Push/PushNotificationManager.swift`
- Modify: `SuperApp/Sources/Managers/ServerConfigManager.swift`
- Modify: `SuperApp/Sources/Models/ServerConfig.swift`
- Modify: `SuperApp/Resources/*/Localizable.strings`
- Modify: `SuperAppUITests/GatewayOnboardingTests.swift`

**Steps:**
1. Write UI/service tests for QR-or-address import, HTTPS validation, server
   health report, registration, readable push URL, and revoke/reset.
2. Implement a dedicated “Self-hosted Push Server” screen, not the old HTML
   app gateway screen.
3. Keep official Drel default untouched and hide this new surface from the
   already-submitted Store build using the existing build policy.
4. Run targeted UI tests on Simulator.

### Task 6: Package and verify deployment

**Files:**
- Modify: `Server/Dockerfile`
- Modify: `Server/docker-compose.yml`
- Modify: `Server/.env.example`
- Create: `Server/docs/self-hosted-drel-push.md`
- Create: `tools/verify-self-hosted-drel-push.sh`

**Steps:**
1. Add an isolated Docker-compose verification fixture with a temporary data
   directory and no real APNs credential.
2. Document Docker, HTTPS proxy, QR setup, credential injection, backup,
   rotation, and revoke procedures.
3. Verify `/ping`, descriptor, pairing, registration, encrypted push contract,
   and no-secret image scan locally.
4. Run release and deliverable-boundary gates that cover modified areas.

### Task 7: Physical-device acceptance

**Files:**
- Modify: `docs/verification/module-availability-verification.md`

**Steps:**
1. After all local and Simulator gates pass, deploy an isolated self-hosted
   instance with a valid Drel-only APNs credential.
2. Verify TestFlight foreground, background, lock-screen, notification tap,
   and no duplicate delivery.
3. Record only results and redacted identifiers; never commit credentials or
   device tokens.

