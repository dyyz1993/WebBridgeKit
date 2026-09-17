# ADR-0003: Do not distribute Drel's APNs signing key

## Status

Revised — 2026-09-04

## Context

Drel must offer a configuration-free official push path and a privacy path for
developers. APNs authenticates the sending provider with a private signing
key. A topic-specific key narrows scope to one bundle ID and environment, but
it remains a private key: its holder can authenticate alerts to known device
tokens. A normal user cannot create a key for `com.webbridgekit.superapp`,
because that App ID belongs to Drel's Apple team.

Bark has published a p8 asset in its server releases. That is an observable
product choice, not proof that publishing a reusable APNs private key is
risk-free or appropriate for Drel.

## Decision

Drel never distributes its APNs `.p8`.

The direct relay can be used only by a Drel-owned isolated verification host,
or by an advanced developer's separately signed Drel distribution using that
developer's own App ID, Apple team, and private topic-specific signer. Its
Bark-compatible URL is readable by that relay; the optional sender-encrypted
envelope protects content from the relay and APNs.

For the stock App Store Drel client, a future privacy-preserving path uses
sender-side encryption plus a Drel-managed APNs signer. It cannot read business
plaintext, but it necessarily sees the device token and delivery metadata. It
is not described as fully independent self-hosting.

## Consequences

### Positive

- No reusable Drel APNs signing key is exposed to arbitrary deployments.
- Content secrecy, delivery metadata, and notification injection capability
  remain distinct, testable claims.
- A leaked device push address remains recoverable through exact unregister and
  address rotation.

### Negative

- The three claims “stock App Store Drel”, “no Drel service at all”, and
  “third-party direct APNs” cannot be offered together.
- The stock-App high-privacy route needs a managed signing service and must
  clearly disclose its metadata boundary.
- Fully independent deployments require an advanced developer distribution,
  not only a Docker or Go server.

## Alternatives Considered

### Publish a Drel topic-specific p8 in a self-hosted bundle

Rejected. Topic restriction does not remove the ability to send forged alerts
to known Drel device tokens, and Apple requires private signing keys to be
protected.

### Hide the key in an open-source Docker image or binary

Rejected. This is only obscurity; anyone can extract and reuse it.

### User supplies their own key to the stock App Store build

Rejected. Their Apple team cannot authorize the Drel-owned
`com.webbridgekit.superapp` topic.

## References

- [Apple: token-based APNs connections](https://developer.apple.com/documentation/UserNotifications/establishing-a-token-based-connection-to-apns?changes=_2)
- [Apple: topic-specific APNs keys](https://developer.apple.com/news/?id=wy4tb0uo)
- `Server/native/`
- `docs/api/drel-selfhosted-push.md`
