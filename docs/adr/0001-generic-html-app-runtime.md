# ADR-0001: Use a generic managed HTML application runtime

## Status

Accepted

## Context

WebBridgeKit already contains a WebView bridge, permission handlers, resource
caching, push routing, and message delivery. These capabilities are currently
independent and may be interpreted as app-specific integrations.

The product direction is a reusable native container for HTML applications. A
future integration, such as an AI coding product, must not add its domain
objects to the framework core. At the same time, arbitrary web pages must not
gain access to native capabilities simply because they are opened in a WebView.

## Decision

WebBridgeKit will use a generic managed HTML application model:

- A policy manifest identifies an HTML application, its trusted origins, routes,
  requested capabilities, and cache policy.
- Native capability calls are mediated by a framework permission gateway.
- System authorization remains an iOS host-app concern; runtime grants are
  scoped to application identity, origin, and capability.
- Push payloads navigate with `appId + route + parameters`.
- Existing resource manifests and bridge APIs remain compatible while the new
  policy layer is introduced incrementally.
- Domain integrations are implemented as protocol clients or sample HTML apps,
  not framework modules.

## Consequences

### Positive

- Any conforming HTML application can reuse native capabilities, offline cache,
  push, and routing without a custom host integration.
- The framework has a concrete trust boundary for native capability access.
- Permissions can be inspected and revoked per HTML application.
- Product-specific integrations remain isolated from framework APIs.

### Negative

- A new policy manifest, signature strategy, permission ledger, and migration
  adapters must be implemented.
- Developers must register trusted origins and declare capabilities explicitly.
- Some existing permissive bridge paths must gain validation before production
  use.

### Neutral

- The existing `Manifest` remains a resource manifest during migration; the
  policy manifest is a separate type to avoid silently changing cache behavior.

## Alternatives Considered

### Build an AI-specific mobile client

Rejected. It solves one product integration but makes the framework less useful
for non-AI HTML applications and pollutes the core with domain-specific types.

### Allow every loaded URL to call WebBridge.js

Rejected. There is no reliable application identity, permission scope, or
revocation boundary for native capability access.

### Replace all existing bridge and cache APIs at once

Rejected. The project has broad existing test coverage and working cache/bridge
behavior. Incremental adapters reduce regression risk.

## References

- `docs/architecture/html-app-runtime-protocol.md`
- `Sources/Models/ManifestModels.swift`
- `Sources/Core/WebJavaScriptBridge.swift`
- `Sources/Handlers/Permission/WebPermissionManager.swift`
