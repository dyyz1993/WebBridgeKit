# Drel 1.5.0 pre-project assessment

Date: 2026-10-16

Status: analysis only. No Drel 1.5.0 implementation, ASC version, or feature
branch is authorized by this document.

## 0. Owner decisions

The product owner selected this pre-project direction on 2026-10-16:

| Decision | Result |
| --- | --- |
| Candidate scope | **Option B**: haptic/vibrate, system share, and a scan-only camera action. |
| Scan duration | **Never `always`.** Scan supports only once and while-using scopes. |
| Offline packages | **Not eligible in 1.5.0.** Only network-managed, signed apps may request capabilities; offline packages stay bridge-disabled until a later 1.5.x evaluation. |
| ADR-0006 Phase 1 | **Hard submission gate.** Complete its design and build-policy decoupling before implementation, and finish all Phase 1 work before submission. |

These decisions narrow the target but do not authorize implementation. The
security, privacy, App Review, and fresh regression evidence below remain
prerequisites.

## 1. Executive recommendation

Do not start Drel 1.5.0 implementation yet. Continue with a scoped
pre-project decision round.

The existing codebase already contains a substantial SDK permission
foundation, but the Drel product needs a deliberately smaller public surface,
a purpose-bound manifest contract, local audit records, and fresh security and
App Review evidence. In particular, the current SDK permits a local/page trust
path that should not exist in Drel 1.5.0, and its capability vocabulary is too
coarse for the roadmap's per-purpose authorization requirement.

Recommended direction:

1. Treat 1.5.0 as "controlled app capabilities", not a general JavaScript
   Bridge release.
2. Prefer a minimal first release with action- and purpose-bound declarations.
3. Do not enable a capability merely because a handler exists.
4. Complete ADR-0006 Phase 1, or at least its design and the target-separating
   build-policy portion, before creating a 1.5.0 implementation plan.

## 2. Release posture

| Question | Current answer |
| --- | --- |
| Should the next App Store version be 1.4.1? | Not unless a user-visible client regression appears. |
| Should 1.5.0 start implementation now? | No. Start the decision round only. |
| Is the existing 1.4 runtime safe to leave unchanged? | Yes. Drel Store builds advertise `Bridge=0`, compile the native bridge out, and strip the permission UI. |
| Is there current production pressure? | No. All official app manifests currently declare empty capability arrays. |
| Is current SDK test evidence sufficient? | No. The last recorded JSBridge regression report is from 2026-08-26 and must be rerun before implementation. |

## 3. Existing strengths

The reusable WebBridgeKit SDK already has important building blocks:

- Signed gateway onboarding: the gateway descriptor carries no secret, rejects
  HTTP and redirects off the exact origin, validates the whole signed manifest
  collection, and persists only after explicit confirmation.
- App identity: manifests bind app ID, allowed origins, routes, capabilities,
  optional strong-offline metadata, and an Ed25519 signature.
- Authorization identity: runtime grants are keyed by gateway identity, app ID,
  origin, and capability. Gateway, app, or origin changes do not reuse old
  grants.
- User-facing authorization flow: a Drel panel precedes the iOS system prompt,
  supports once / while-using / always scopes, and supports per-app permission
  review and revocation.
- Runtime revocation: manifest updates can remove stale grants; closing a
  container clears while-using grants; continuous handlers can stop active work
  on notification.
- Drel Store boundary: 1.4 compiles out the bridge and permission UI, and the
  release verifier rejects bridge-only privacy strings and permission UI in the
  archive.

## 4. Material gaps

### 4.1 Local and page trust are unsuitable for Drel 1.5.0

The SDK authorization path currently allows `local.<origin>` and page-declared
`page.<app-id>` identities to request protected capabilities without a signed
manifest. This may be useful for a generic SDK host, but it conflicts with the
Drel 1.5.0 trust boundary.

Drel 1.5.0 must require:

1. An active trusted gateway.
2. A signature-verified manifest for the exact app ID and origin.
3. The action and purpose to be declared by that signed manifest.
4. No fallback to page metadata or origin-only identity.

### 4.2 Capability vocabulary is too coarse

The current `HTMLAppCapability` enum names broad families such as camera,
clipboard, file import, file export, and device control. One capability can
therefore cover materially different operations:

- Camera: still capture, video capture, continuous video stream, and torch.
- Clipboard: read pasteboard and write pasteboard.
- Files: user-selected import and writing/exporting data.
- Device control: multiple unrelated system actions.

The roadmap requires authorization by app, domain, and purpose. A broad family
name alone cannot express that purpose.

### 4.3 Reason strings are not a manifest contract

Today a request can supply a `reason` at call time, and the bridge substitutes
a generic phrase when it is absent. Drel 1.5.0 should instead require the
purpose and user-visible explanation to be signed in the manifest. A runtime
reason may identify the specific object or route, but must not broaden the
authorized action.

### 4.4 Audit records are incomplete

The current ledger answers "what is currently granted?" but does not provide a
complete, user-reviewable permission history. Drel 1.5.0 needs a bounded local
audit log covering at least:

- authorization prompt shown;
- user decision and selected scope;
- system authorization result;
- denied requests and stable failure reason;
- successful execution of a protected action;
- revocation and session expiry;
- manifest update that removes a capability.

The log must avoid storing sensitive payloads. It should retain action,
capability, purpose ID, subject, timestamp, and outcome rather than full input
or captured data.

### 4.5 Store release policy is coupled to the SDK target

ADR-0006 is accepted but its prerequisite decoupling work remains unfinished:

- the official Drel gateway default is still in SDK code;
- `DREL_CONTAINER_ONLY` is still applied to the framework target as well as
  the app;
- push app group and keychain identifiers are host-branded;
- the notification extension still duplicates protocol constants.

Starting broad bridge changes before this separation makes the next SDK change
ride another Drel App Store review cycle and weakens the distinction between
the reusable SDK and the deliberately narrower Drel product.

Owner gate: Phase 1 is now required before submission. The build-policy
separation must also be complete before implementation so Drel product policy
and reusable SDK defaults do not continue to mutate together.

### 4.6 Documentation drift

Generic SDK onboarding material advertises a broad Bridge surface, while the
Drel roadmap explicitly excludes a generic JS Bridge. Before implementation,
the product contract needs a Drel-specific capability catalog and developer
guide that do not imply that all SDK handlers are available.

## 5. Candidate public scopes

### Option A — Minimal non-sensitive capabilities

Include:

- Haptic feedback (`haptic`, `vibrate`).
- System share sheet (`share`), with explicit user-selected outbound content.
- Possibly basic container navigation such as close/back, presented as
  container integration rather than a native capability.

Advantages:

- Lowest privacy and review risk.
- No sensitive iOS permission prompts.
- Useful for validating signed manifests, capability declarations, permission
  review, and revocation without exposing personal data.

Disadvantages:

- Limited user value; may not justify a public minor release on its own.
- Does not test the full iOS system-authorization or hardware-lifecycle path.

### Option B — Minimal capabilities plus controlled scan

Include Option A and a scan-only camera action:

- Opens a Drel-owned scanner UI in the foreground.
- Returns the scanned value to the requesting app.
- Does not expose still capture, video recording, torch, or a continuous media
  stream.
- No `always` scope; allow only once or while-using.
- Camera frames are not persisted or uploaded by Drel.
- Manifest declares action, origin, purpose, and user-visible explanation.

Advantages:

- Exercises the complete signed-manifest, Drel consent, iOS camera permission,
  execution, revocation, and review path.
- Has clearer developer value than haptics/share alone.
- Keeps camera use bounded and explainable for App Review.

Disadvantages:

- Requires a camera usage description scoped carefully to scan behavior.
- Adds privacy questionnaire and review-demo work.
- A malicious site could attempt prompt manipulation; copy and UI boundaries
  need review.

### Option C — Declarative app integration surface

Defer device Bridge actions and expose only product-level integrations such as
structured navigation, app metadata presentation, and foreground handoff. This
is closer to product polish than to the roadmap's 1.5.0 capability gate.

Advantages:

- Very low risk.
- Could improve installed-app feel.

Disadvantages:

- Does not answer the 1.5.0 question of controlled native capability.
- Better treated as a 1.4.x/1.6 container improvement if needed.

### Recommendation

Choose Option B if the owner wants a meaningful 1.5.0 validation release.
Choose Option A if the priority is to prove the release machinery with minimal
privacy exposure. Do not include any capability outside the selected option.

### Owner selection

The owner selected Option B with these boundaries:

- `haptic` and `vibrate` only for tactile feedback.
- `share` only through the system share sheet with user-selected outbound
  content.
- `scan` only through Drel's foreground scanner; no camera capture, video,
  torch, or continuous media stream.
- Only network-managed apps with signed action-level declarations.
- Offline-installed packages remain `Bridge=0`.
- Scan grants may be `once` or `appSession`, never `always`.

Scan is task-scoped rather than a durable app privilege. Restricting its scope
keeps camera-adjacent use tied to the visible task, avoids a second persistent
layer above iOS's own camera permission, and gives App Review a narrower
privacy story while still validating declaration, consent, execution, audit,
and revocation.

## 6. Explicit exclusions for first release

The following must not enter the first Drel 1.5.0:

- Location.
- Contacts.
- Full photo-library access.
- Microphone or speech recognition.
- Bluetooth.
- Motion sensors.
- Face ID / biometrics.
- General clipboard read.
- File import/export.
- General camera or continuous video stream.
- Local notifications or badge mutation.
- Screen, torch, or broad device control.
- Navigation history or launch payload exposure.
- Arbitrary `openPage`.
- Cache debug or page-cache management.
- Text-to-speech.
- Remote or dynamically supplied native actions.
- Push-initiated authorization or execution.

## 7. Required manifest evolution

The current manifest `capabilities: [HTMLAppCapability]` array should remain
backward compatible for existing 1.4 entries, but Drel 1.5.0 should require a
new structured declaration such as:

```json
"capabilities_v2": [
  {
    "action": "share",
    "origins": ["https://inventory.example.com"],
    "purposeId": "share-report",
    "purpose": "Share the selected report with an app you choose",
    "scope": "once"
  }
]
```

Design constraints:

- `action` is a concrete, allowlisted operation, not only a broad family.
- `origins` is a subset of the parent manifest's allowed origins.
- `purposeId` is stable for audit and revocation.
- `purpose` is user-visible and length-bounded.
- `scope` is constrained by Drel's action policy, not chosen freely by the app.
- The declaration is signed with the parent manifest.
- An empty v2 declaration grants no new capability.

For scan, the manifest should distinguish `scan` from generic `camera` and
must not allow a scan declaration to satisfy camera, torch, or video actions.

## 8. Drel runtime policy

Drel 1.5.0 should enforce these product rules:

1. Bridge bootstrap only for a managed, signature-verified installed app.
2. `Bridge/<version>` remains `0` for ordinary web pages and all 1.4 manifests
   without 1.5 declarations.
3. No `local.*` or `page.*` authorization identity in the Drel product.
4. Protected action must match a signed action-level declaration.
5. Prompt copy includes app name, origin, capability/action, and signed purpose.
6. Sensitive action must be initiated by a foreground user gesture.
7. Push and deep link may navigate, but never authorize or execute a protected
   action.
8. Revoking a capability cancels pending prompts and active bounded work.
9. Uninstalling or deactivating the app removes its grants and local audit
   association.
10. A manifest update removing an action removes dependent grants.

### Offline package policy

Offline packages are technically capable of carrying signed app identity, but
they are excluded from 1.5.0 capability requests. This avoids combining the
two major release concerns—strong offline and controlled native
capabilities—in the first trial.

The first release must enforce:

1. offline package entrypoints advertise `Bridge=0`;
2. no bridge script or message handler is installed for offline packages;
3. installing or updating an offline package does not enable bridge behavior;
4. deleting or updating an offline package does not alter network-managed app
   grants.

A later 1.5.x rollout may be proposed only when declarations bind to the exact
manifest version and package digest; updates, deletion, and rollback clean or
block grants correctly; audit records identify package version and digest; and
offline prompts, revocation, server-side capability removal, and App Review
behavior are all verified.

## 9. Threat model outline

The full model must be completed before implementation, but the assessment
scope should include:

| Threat | Required mitigation |
| --- | --- |
| Ordinary webpage impersonates an installed app | Drel enables bridge only in its managed app context with exact origin/app binding. |
| App key or gateway signing key compromise | Key rotation/versioning, old grant invalidation, revocation response, and compromise notification plan. |
| Overbroad signed manifest | Product policy rejects undeclared actions; action catalog is minimal and allowlisted. |
| Prompt manipulation | Stable Drel-owned sheet, signed purpose, origin always visible, no remote UI. |
| Prompt replay or concurrent requests | Request IDs, pending-request cancellation, one prompt per subject/action. |
| Authorization survives identity change | Subject includes gateway/app/origin/action; gateway or manifest change clears stale grants. |
| Continuous hardware use after revoke | Capability-specific stop handlers and foreground/session lifecycle tests. |
| Audit log leaks sensitive values | Store only metadata and bounded outcome, never scanned content or action payload. |
| Offline package differs from network origin semantics | Define whether offline manifests can ever request capabilities and how app identity remains stable. |
| App Review confusion | Real demo app, recordings, signed manifest, permission flow, deny flow, revoke flow, and privacy disclosure. |

## 10. Privacy and App Review package

Before any ASC version is created:

1. Define the exact action catalog and data flow for the selected option.
2. Update iOS usage strings only for the selected action. A scan-only release
   should not imply general photo or camera capture.
3. Update `PrivacyInfo.xcprivacy` and the ASC privacy questionnaire.
4. Explain that Drel does not collect scan data for its own account.
5. Provide a signed demo app and deterministic test manifest.
6. Record a review video covering:
   - manifest import and activation;
   - first-use prompt with app, origin, action, and purpose;
   - denial and iOS-settings recovery;
   - successful bounded execution;
   - permission review and revoke;
   - ordinary webpage remaining bridge-disabled.
7. State clearly that Drel does not offer a generic JavaScript-to-native
   Bridge or remotely extensible native capability.

## 11. Verification gates

Before creating an implementation plan, the current baseline must be refreshed:

```bash
bash tools/run-jsbridge-regression.sh
bash tools/verify-drel-container-only.sh
bash tools/run-release-gate.sh
```

Implementation gates should add:

- Unit tests for action-level manifest validation.
- Signature tamper tests for every v2 field.
- Drel product policy tests proving local/page trust is unavailable.
- Tests proving manifest capability removal clears dependent grants.
- Prompt queue, cancellation, and exactly-once callback tests.
- Real WebView Promise tests for each enabled action.
- Audit event generation and redaction tests.
- Revocation tests including active bounded work.
- Simulator and physical-device permission tests.
- Archive verifier checks for the 1.5 action catalog and excluded handlers.
- A dedicated regression proving ordinary web pages receive no bridge object.

## 12. Go / no-go questions for the owner

Resolved:

- Scope: Option B.
- Scan duration: once or while-using only.
- Offline eligibility: excluded from 1.5.0.
- ADR-0006 Phase 1: hard submission gate.

Still open:

1. Does Drel need a local audit history visible to users, or is the current
   permission list sufficient for the first release?
2. Should haptic and vibrate also require signed action declarations even
   though they do not expose user data?
3. Who owns security review and sign-off?
4. Who owns App Review narrative and privacy disclosure sign-off?

## 13. Recommended decision

The owner selected Option B as the target scope. Before implementation, turn
these decisions into a dedicated implementation plan and require:

1. signed action-level declarations;
2. Drel-only managed-manifest trust;
3. scan limited to once or while-using, never always;
4. network-managed apps only in the first release;
5. local audit metadata;
6. ADR-0006 design/build-policy decoupling before implementation and full
   Phase 1 before submission;
7. complete threat model and privacy package before implementation.

If scan privacy or App Review evidence cannot be completed, defer 1.5.0 rather
than broad-enabling the existing SDK Bridge surface.

## 14. Source references

- `docs/plans/2026-08-28-drel-phased-release-roadmap.md`
- `docs/adr/0006-split-drel-product-repository.md`
- `docs/api/gateway-v1.md`
- `docs/api/drel-web-app-manifest-profile.md`
- `docs/api/drel-container-only-launch.md`
- `Sources/Core/WebJavaScriptBridge.swift`
- `Sources/Runtime/HTMLAppBridgeCapabilityPolicy.swift`
- `Sources/Runtime/HTMLAppRuntime.swift`
- `Sources/Models/HTMLAppRuntimeModels.swift`
- `tools/verify-drel-store-archive.sh`
