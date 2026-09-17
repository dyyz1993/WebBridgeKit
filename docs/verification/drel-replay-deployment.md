# Drel `push.drel.app` deployment handoff

This is the live deployment record for the optional self-hosted direct and
encrypted push relay. It is separate from the App Store review service and
must never reuse its host or registration data.

## Current completed state

| Item | Evidence | State |
| --- | --- | --- |
| Public hostname | `push.drel.app` CNAME → named Cloudflare Tunnel `drel-selfhosted-push` (`887a9c74-9c94-4d67-a04b-24ecd6c5b04f`) | Complete |
| Tunnel origin | `cloudflared-drel.service` is active with three edge connections and maps only to `http://127.0.0.1:8080` | Complete |
| Native relay | Static Go binary `/usr/local/bin/drel-selfhosted`, `drel-selfhosted.service` active, unprivileged `drel` account | Complete |
| Delivery contract | Public descriptor advertises `direct` and `encrypted` modes plus exact `/unregister` | Complete |
| External TCP 443 | Not required: Cloudflare Tunnel is outbound-only; do not open a security-group rule | Not applicable |
| Docker base images | Not required for this host: native relay has no container or Swift runtime dependency | Not applicable |
| APNs provider key | Drel-specific production `.p8` not installed | Pending |

The live public endpoint returns a valid descriptor and `{ "status": "ok",
"apnsReady": false }`. Pairing and push deliberately return HTTP 503 until a
valid Drel APNs provider key is installed, so no iPhone can accidentally
enrol to a server that cannot deliver APNs.

## 2026-09-05 channel-label rollout

The current native relay binary SHA-256 is
`c54a60a5fcc8145335a40cc3b79f57c159f8b2e3389fcc10e70a56a155ecc478`.
It stamps every direct and opaque-envelope APNs payload with a source label
derived from its own configured public URL, for example
`drel.selfhosted.https://push.drel.app`. Drel uses this label only to filter
its local history when a user changes between official and self-hosted
channels; a sender cannot provide or override it. Existing registrations made
before this version derive the same label at delivery time, so they remain
compatible without a fresh pairing.

The previous binary is retained on the host as
`/usr/local/bin/drel-selfhosted.previous-4bf36fa0`. After replacement,
`drel-selfhosted` and `cloudflared-drel` were active, the public health and
descriptor endpoints returned normally, and an attempted direct push returned
the expected `503` because no APNs provider key was installed or altered.

## Required advanced-deployment action

1. Do **not** publish Drel's APNs signing key. Direct APNs requires a private
   production topic-specific signer for the same Apple team and bundle topic
   as the installed app. A third party cannot meet that condition with the
   stock `com.webbridgekit.superapp` App; it needs an independently signed
   bundle/topic. The p8 must never appear in source control, Docker images,
   installer bundles, or chat transcripts.

## Activate after prerequisites are met

For this controlled Drel-owned verification host, a Drel operator would place
the private file at `/etc/drel-selfhosted/secrets/AuthKey_<KEY_ID>.p8` (mode
`640`, owner `root:drel`) and write these values to
`/etc/drel-selfhosted/drel-selfhosted.env`:

```dotenv
APNS_KEY_ID=<Drel key ID>
APNS_TEAM_ID=<Apple team ID>
APNS_KEY_PATH=/etc/drel-selfhosted/secrets/AuthKey_<Drel key ID>.p8
APNS_TOPIC=com.webbridgekit.superapp
APNS_ENVIRONMENT=production
DREL_SELF_HOSTED_NAME=Drel Self-hosted Push
DREL_SELF_HOSTED_PUBLIC_BASE_URL=https://push.drel.app
```

Then run on the host:

```bash
systemctl restart drel-selfhosted
curl --fail --silent https://push.drel.app/health
curl --fail --silent https://push.drel.app/.well-known/drel-push.json
```

The health response must contain both `"status":"ok"` and
`"apnsReady":true`. Only then generate a pairing QR code and install the
unshipped Drel TestFlight build that includes the self-hosted settings screen.
Continue with [`drel-self-hosted-physical-device.md`](drel-self-hosted-physical-device.md)
for the required foreground, background, lock-screen, URL-routing,
at-most-once, and revocation validation.
