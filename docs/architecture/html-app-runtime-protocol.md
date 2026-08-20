# HTML App Runtime Protocol

Status: Accepted

## Purpose

WebBridgeKit is a native iOS runtime for managed HTML applications. It provides a
single, framework-level contract for native capabilities, permission mediation,
notifications, routing, and offline resources.

The runtime must not model a specific product domain. Terms such as `agent`,
`session`, `project`, and `approval` belong to an HTML application's own data
model, not to WebBridgeKit. An AI product can be the first adopter without
becoming a framework dependency.

## Requirements

### Functional

- A managed HTML application declares an identifier, approved origins, routes,
  cache policy, and requested native capabilities in a manifest.
- HTML can make structured bridge calls only after the runtime identifies the
  application and validates the calling origin.
- The runtime mediates every protected native capability and returns a typed
  result to HTML.
- Push payloads route to `appId + route + parameters`, not an app-specific
  business object.
- Cached resources are scoped to an application and can load before a network
  refresh completes.
- Users can inspect and revoke capability grants in the host application.

### Non-functional

- No remote HTML page obtains native access merely by being opened in a web
  view.
- A denied capability must fail deterministically and must not block unrelated
  HTML features.
- Capability decisions must survive restart and be auditable locally.
- Secrets, source code, and other confidential data must not be put in a push
  notification preview.
- The protocol must coexist with the existing `WebBridge.js` and handler
  registry during migration.

## Trust Levels

| Level | Description | Native bridge access |
| --- | --- | --- |
| Unmanaged page | Any URL opened by the browser. | None beyond normal WebKit behavior. |
| Managed HTML app | A validated manifest matches the current origin and app ID. | Only declared and user-approved capabilities. |
| Development app | A managed app explicitly enabled by a DEBUG-only local policy. | Same policy checks, with local origins allowed. |

The application identity is never inferred only from a hostname in production.
The runtime validates `appId`, the active document origin, and the manifest
policy before routing a bridge request.

## High-level Architecture

```text
Managed HTML app
    |
    | manifest + bridge request
    v
App Identity and Origin Validator
    |
    v
Capability Gateway -----> Permission Ledger -----> iOS authorization API
    |                         |                         |
    |                         v                         v
    |                    Permission Center          System Settings
    v
Existing Handler Registry
    |
    v
Native result -> WebBridge.js -> HTML

Push service -> Push Envelope Validator -> Route Resolver -> Cached HTML app
```

## Protocol Objects

### HTML App Manifest v1

This is a new application-policy manifest. It is separate from the existing
resource `Manifest` model during migration. The existing model remains the
source of truth for resource download and offline cache metadata.

```json
{
  "schemaVersion": "1",
  "appId": "com.example.inventory",
  "name": "Inventory",
  "startURL": "https://inventory.example.com/index.html",
  "allowedOrigins": ["https://inventory.example.com"],
  "capabilities": ["camera", "bluetooth", "notification"],
  "routes": ["/", "/items/:id"],
  "cache": {
    "strategy": "manifest",
    "version": "2026.08.09",
    "persistent": true
  },
  "signature": {
    "algorithm": "ed25519",
    "keyId": "inventory-prod-1",
    "value": "base64url-signature"
  }
}
```

Rules:

- `appId` is stable and uses the existing safe app identifier character set.
- `allowedOrigins` is an exact allowlist. No wildcard origin is accepted in a
  production manifest.
- `capabilities` is a declaration, not a grant.
- `routes` is a navigation allowlist used by deep links and push notifications.
- Signed manifests are required for production distribution. Local development
  can use an explicit DEBUG policy instead of a production signature.

### Gateway Onboarding v1

A gateway is user-controlled connection metadata, not an HTML application and
not a source of implicit native permissions. The host accepts either JSON or a
`webbridgekit://gateway` URL:

```json
{
  "id": "inventory-gateway",
  "name": "Inventory Gateway",
  "baseURL": "https://gateway.example.com",
  "healthPath": "/health",
  "manifestPath": "/api/v1/html-apps",
  "publicKeyID": "gateway-prod-1",
  "publicKey": "base64url-ed25519-public-key"
}
```

The URL form uses `name`, `url`, `healthPath`, `manifestPath`, `keyId`, and
`publicKey` query items. QR codes and pasted payloads must never contain a
private key, APNs token, API secret, or user credential.

Onboarding is an explicit state machine:

```text
parse -> validate exact origin and endpoint paths -> GET health endpoint
      -> GET and decode manifests -> validate origin and signature policy
      -> show host, endpoints, app count, and key ID for confirmation
      -> save active gateway and register trusted manifests
```

No gateway or manifest is persisted before the user confirms a successful
validation report. Production builds accept only exact HTTPS origins and
require `publicKeyID` plus a base64url Ed25519 public key. DEBUG builds may use
unsigned `http://localhost` fixtures; this exception must not be enabled in a
release build. Endpoint paths are same-origin absolute paths without query,
fragment, user information, traversal segments, or authority overrides.

The manifest endpoint may return one manifest, an array of manifests, or an
object with a `manifests` array. For a production manifest, `signature.value`
is the base64url Ed25519 signature of the UTF-8 JSON encoding of that manifest
with `signature` omitted and object keys sorted. `signature.algorithm` must be
`ed25519`, and `signature.keyId` must equal the gateway `publicKeyID`.

Switching to a different gateway revokes grants belonging to the previously
registered HTML apps. Manifests absent from the newly confirmed response are
unregistered so stale application identities cannot retain bridge access.

### Capability Request

```json
{
  "id": "c9b02b04-4a49-47e4-b3f8-4e51a94ca9d3",
  "method": "capability.request",
  "params": {
    "capability": "bluetooth",
    "reason": "Connect to the selected device",
    "scope": "once"
  }
}
```

The runtime derives `appId` and `origin` from the loaded document. HTML does
not get to supply or override those values in the request.

### Capability Result

```json
{
  "id": "c9b02b04-4a49-47e4-b3f8-4e51a94ca9d3",
  "ok": true,
  "result": {
    "capability": "bluetooth",
    "status": "granted",
    "scope": "once"
  }
}
```

Status values are `granted`, `denied`, `notDetermined`, `restricted`,
`requiresSettings`, and `unavailable`.

### Push Envelope

```json
{
  "version": "1",
  "appId": "com.example.inventory",
  "route": "/items/123",
  "params": {"source": "notification"},
  "notification": {
    "title": "Inventory update",
    "body": "An item needs your attention"
  },
  "expiresAt": "2026-08-09T12:00:00Z",
  "nonce": "server-generated-nonce"
}
```

The envelope contains only the data needed to select an application and route.
Sensitive details are fetched after the user opens the application.

## Permission Model

Two permission layers are required.

Permission results include `authorizationLayer`. `nativeSystem` means the host
must first request or open iOS Settings for system authorization; `htmlApp`
means iOS has granted the capability and the user must now approve it for this
specific HTML application.

1. System authorization belongs to the iOS host application. It covers
   Bluetooth, camera, microphone, location, notifications, and other protected
   resources.
2. Runtime grants belong to one `appId + origin + capability` tuple. They
   decide whether a managed HTML application may ask the host to use a
   capability that the host already has.

The normal request flow is:

1. HTML calls the bridge with a structured capability request.
2. The runtime validates the manifest, origin, requested capability, and
   request shape.
3. The Permission Center asks for a runtime grant when no suitable grant exists.
4. If iOS authorization is not determined, the native host explains the reason
   and requests the system permission.
5. The runtime invokes the existing handler only after both layers allow it.
6. The result is returned to HTML and recorded in the local audit trail.

A user may revoke a runtime grant in the Permission Center. A user may revoke
system authorization in iOS Settings. The runtime must re-check system status
before every protected operation and return `requiresSettings` when applicable.

High-risk operations such as camera capture, microphone recording, file export,
and external data transfer should default to a one-time grant. Low-risk status
queries can use a persistent grant only after explicit user choice.

## Cache and Offline Model

The existing `Manifest`, `PersistentManifestLoader`, and `ManifestStore` remain
the resource-cache implementation. The new manifest adds application policy;
it does not replace resource download or atomic cache swap behavior.

Cache keys are scoped by `appId + manifest version`. A cached application may
render its verified last-known HTML and resources immediately, then refresh the
manifest in the background. The runtime must retain the last valid package if a
refresh fails and must never replace it with a partially downloaded package.

## Routing Model

All native entry points use the same resolver:

```text
appId + route + parameters -> manifest validation -> cached package or network refresh -> HTML route
```

This applies to push taps, universal/deep links, message-center rows, and
in-app navigation. Existing `PushRouter` can be migrated by translating its
legacy `appid` and `url` fields into the new resolver.

## Existing Module Mapping

| Existing module | Reuse | New responsibility |
| --- | --- | --- |
| `Sources/Models/ManifestModels.swift` | Resource metadata and app ID validation. | Keep as cache manifest; add a separate policy manifest. |
| `Sources/Core/WebJavaScriptBridge.swift` and `SuperApp/Resources/WebBridge.js` | JavaScript transport and handler dispatch. | Gate dispatch through app identity and capability policy. |
| `Sources/Handlers/Permission/WebPermissionManager.swift` | iOS permission status and system requests. | Add a runtime grant lookup before protected handlers run. |
| `Sources/Cache/ManifestStore.swift` and `PersistentManifestLoader.swift` | Persistent offline package loading. | Scope cache to validated app policy and version. |
| `SuperApp/Sources/Push/PushRouter.swift` | Push tap entry point. | Resolve a generic push envelope to `appId + route`. |
| `SuperApp/Sources/Managers/PushRelayManager.swift` | Foreground relay and local notification delivery. | Preserve generic push-envelope fields. |

## Migration Plan

### Phase 1: Protocol and policy foundation

- Add public Swift models for the policy manifest, capability request/result,
  and generic push envelope.
- Add unit tests for manifest validation, origin matching, and route validation.
- Do not change legacy bridge behavior yet.

### Phase 2: Capability gateway

- Add `AppTrustRegistry`, `PermissionLedger`, and `CapabilityGateway`.
- Route protected bridge calls through the gateway.
- Add a native Permission Center and a system Settings handoff.

### Phase 3: Push and route integration

- Extend `PushRouter` and the message center to resolve the generic envelope.
- Load the cached package before attempting a network refresh.
- Add simulator tests for notification payload parsing and deep-link routing.

### Phase 4: First compatibility sample

- Create one managed HTML fixture that declares a small capability set.
- Use `pi-agent-chat` only as an external compatibility sample once the generic
  fixture works end to end.

## Failure Modes

| Failure | Required behavior |
| --- | --- |
| Manifest signature or origin mismatch | Treat the page as unmanaged and deny native bridge access. |
| Runtime grant denied | Return `denied` without opening an iOS system dialog. |
| iOS system permission denied | Return `requiresSettings` and offer a native Settings handoff. |
| Offline refresh fails | Keep and render the last verified cached package. |
| Push route is invalid or expired | Open the message center safely and do not navigate to the target page. |
| Duplicate request ID | Return the original terminal result and avoid repeating the operation. |

## Validation Plan

1. Unit-test policy manifest parsing, origin allowlists, route allowlists, and
   capability request validation.
2. Test the bridge transport directly with a managed and an unmanaged page.
3. Use simulator UI automation for the Permission Center, denied state, and
   push-to-route behavior.
4. Run cache and bridge regressions after integration changes.
5. Verify physical-device APNs separately once a Push-capable signing profile
   is available. Simulator evidence does not prove APNs delivery.

## Open Decisions

- Define key rotation and revocation metadata beyond the v1 pinned Ed25519 key.
- Decide whether a runtime grant can be persisted per origin or only per app.
- Define which capabilities require one-time confirmation regardless of a
  persistent grant.
- Define manifest revocation and key-rotation behavior.
