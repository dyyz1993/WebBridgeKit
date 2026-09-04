# Drel API edge proxy

`api.drel.app` is the public origin for the Drel push and HTML-app gateway.
This Worker forwards existing paths and methods to the current shanbox
service while disabling edge caching. The shanbox hostname is an
implementation detail and must not appear in Store-facing app UI or docs.

It also contains the **disabled-by-default** `drel.managed-encrypted-push.v1`
service. When deliberately enabled, only `/managed-push/*` and
`/.well-known/drel-managed-push.json` run at the edge; every other route keeps
the existing proxy behavior.

The managed path is open-source, but it is not a way to distribute Drel's APNs
provider credential. It accepts one sender-created opaque
`drel.push-envelope.v1` field, stores the APNs device token plus the iPhone's
X25519 public key in a Durable Object, and signs the opaque APNs request with
the Drel-operated credential. The Worker never accepts `title`, `body`, URL,
or other plaintext fields at that endpoint.

## Secret boundary

Store these **only as Cloudflare Worker secrets**, never in Git, GitHub Actions
variables, build logs, or `.dev.vars`:

- `DREL_MANAGED_PUSH_ENABLED` — exact value `1` is the explicit activation
  switch. Its absence keeps the endpoint disabled.
- `APNS_AUTH_KEY_P8` — the topic-specific Apple provider key, including PEM
  armor.
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC` — signing identity metadata;
  production Drel uses `com.webbridgekit.superapp`.

The GitHub Actions secrets are deliberately limited to `CLOUDFLARE_ACCOUNT_ID` and
an account/zone-scoped `CLOUDFLARE_API_TOKEN` with only the permissions needed
to deploy this Worker. GitHub therefore deploys source but cannot read or
replace the APNs signer.

After the first Worker deploy, an authorized Drel operator sets the runtime
secrets interactively (do not paste the p8 into a shell history):

```bash
cd infra/cloudflare/drel-api-proxy
npx wrangler secret put APNS_AUTH_KEY_P8
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
npx wrangler secret put APNS_TOPIC
npx wrangler secret put DREL_MANAGED_PUSH_ENABLED
```

Set the final switch to `1` only after a physical TestFlight device has
completed pairing, opaque delivery, decryption, foreground/background/lock
screen, tap routing, rate-limit, and revocation verification. A Worker with a
missing or malformed signer refuses all managed pairing and delivery requests.

## GitHub Actions

`.github/workflows/deploy-drel-api-proxy.yml` validates this Worker on pull
requests and deploys it only when `master` is pushed. Add these GitHub Actions
repository secrets:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN` — scoped only to the Drel Cloudflare account and
  `drel.app` zone, with Worker deployment permissions.

Do **not** add the Apple `.p8` or `APNS_*` values to GitHub.

## Deploy

```bash
cd infra/cloudflare/drel-api-proxy
npm run test
npm run check
npx --yes wrangler@latest deploy
```

The `custom_domain` route creates the Cloudflare DNS record and certificate
for `api.drel.app`; do not add a direct CNAME to the `:8443` source server.

## Verification

```bash
curl -sS https://api.drel.app/health
curl -sSI https://api.drel.app/health
```

Before changing Drel's bundled default URL, also verify `/register`, the push
route, `/api/v1/html-apps`, and `/ws/stream` through this hostname. Update the
source server's `GATEWAY_PUBLIC_BASE_URL=https://api.drel.app` after the proxy
is active so the official gateway configuration remains self-consistent.

When the managed service is explicitly activated, verify it separately without
putting a real device key in shell history:

```bash
curl -sS https://api.drel.app/managed-push/health
curl -sS https://api.drel.app/.well-known/drel-managed-push.json
```
