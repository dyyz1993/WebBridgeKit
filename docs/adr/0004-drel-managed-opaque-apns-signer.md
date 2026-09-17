# ADR-0004: Isolate the stock-App opaque APNs signer

## Status

Accepted — 2026-09-04; implementation disabled by default pending physical APNs validation.

## Context

The published Drel App ID can only be signed for APNs by a provider credential
authorized by Drel's Apple team. Distributing that credential to every
self-hosted relay would let any holder forge Drel alerts to known tokens.
However, a sender can encrypt a message to an installation-owned X25519 public
key before it enters a delivery service.

## Decision

Provide a separate, opt-in managed service schema
`drel.managed-encrypted-push.v1`. It uses its own registration and pairing
stores, exposes only an installation public key, accepts exactly one opaque
`drelEnvelope` field for delivery, and delegates to an APNs signer owned by the
Drel operator. It is off unless `DREL_MANAGED_PUSH_ENABLED=1`.

The managed signer receives APNs token, device capability, opaque envelope and
delivery metadata. It does not receive message plaintext or an installation
private key. A per-device limiter bounds APNs work for a leaked capability;
address reset/unregister revokes the exact token/key pair.

## Consequences

- Stock Drel can offer confidential message content without publishing a
  reusable provider key.
- This must be described as managed delivery, not wholly independent
  self-hosting, because metadata reaches the signer.
- The direct relay remains a distinct advanced deployment for a separately
  authorized App ID/topic; no registration file or route may be shared.
- Real TestFlight device proof is required before activation: foreground,
  background, lock-screen, tap route, exact-once behavior, revocation and
  content opacity in logs.

## References

- `Server/Sources/WebBridgeServer/Routes/ManagedEncryptedPushRoutes.swift`
- `docs/api/drel-managed-encrypted-push.md`
- `docs/security/drel-managed-encrypted-push-threat-model.md`
