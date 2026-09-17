# Drel self-hosted push

This optional direct APNs relay does not call `api.drel.app`: a paired iPhone
registers only with its selected server, and that server sends APNs payloads
directly to Apple. The ordinary Bark-compatible URL is the default direct
mode. It is simple and the relay can read its title, body, and URL.
Sender-side encryption is an optional strict-privacy mode: only it prevents
the relay and APNs from reading business content.

Never publish Drel's APNs `.p8`. A topic-specific key narrows scope but remains
a private signing key that can forge alerts to known Drel tokens. The stock
`com.webbridgekit.superapp` App cannot use a key from a different Apple team,
so an entirely independent direct deployment requires the operator's own
signed Drel bundle/topic and their private topic-specific signer. For the
stock App, the viable privacy route is a future managed APNs signer that
forwards only a sender-encrypted envelope; it cannot read content, but it does
receive delivery metadata. Until either path is intentionally provisioned, a
server without a valid signer must remain fail-closed and refuse pairing.

## Deploy

### Native binary behind Cloudflare Tunnel (managed Drel default)

Use this mode when the target server cannot accept inbound 443 or cannot pull
Docker images. Build a static Linux binary on a development Mac, then install
it as the `drel` system user on the target host:

```bash
bash tools/build-drel-selfhosted-native.sh
scp Server/native/dist/drel-selfhosted root@server:/usr/local/bin/
scp Server/native/drel-selfhosted.service root@server:/etc/systemd/system/
```

Create `/etc/drel-selfhosted/drel-selfhosted.env` with a loopback listener and
the final public hostname:

```dotenv
DREL_LISTEN_ADDR=127.0.0.1:8080
DREL_SELF_HOSTED_PUBLIC_BASE_URL=https://push.example.com
DREL_DATA_DIR=/var/lib/drel-selfhosted
APNS_ENVIRONMENT=production
APNS_TOPIC=com.webbridgekit.superapp
APNS_KEY_ID=your-key-id
APNS_TEAM_ID=your-team-id
APNS_KEY_PATH=/etc/drel-selfhosted/secrets/AuthKey_your-key-id.p8
```

The deployment operator puts their private topic-specific `.p8` in the service
directory and makes it readable only by the `drel` service account. Do not
commit it, publish it, or paste it into chat. Run `systemctl daemon-reload &&
systemctl enable --now drel-selfhosted`. The native process
only accepts loopback traffic; publish it with a named Cloudflare Tunnel whose
public hostname is `push.example.com` and whose origin service is
`http://127.0.0.1:8080`. Do not expose port 8080 or open inbound 443 for this
mode. The Tunnel encrypts the edge-to-origin connection and avoids any inbound
firewall rule; Cloudflare can still observe connection metadata, while strict
`drelEnvelope` message content remains opaque to Cloudflare, the relay, and
APNs.

Before accepting an iPhone pairing, `/health` must report `apnsReady: true`.
Without a valid `.p8`, the service deliberately returns 503 for pairing and
push requests rather than claiming that delivery is ready.

### Native Docker image without Docker Hub

The same portable Go relay can also run in Docker without pulling a Swift or
Ubuntu base image. This is useful for a host whose Docker daemon cannot reach
Docker Hub. It is the same relay contract as the native systemd mode, not a
reduced fallback.

Build the static Linux binary first, then start the dedicated Compose file:

```bash
bash tools/build-drel-selfhosted-native.sh
cd Server
cp .env.example .env
# Fill the final HTTPS URL, APNs key/team values, and the three DREL_*_HOST_PATH/GID values.
docker compose -f docker-compose.self-hosted-native.yml up -d --build
```

`DREL_APNS_KEY_HOST_PATH` is the **host** pathname of the private `.p8` and
`DREL_APNS_KEY_GID` is the numeric group that already has read permission on
that file. The Compose file maps the key read-only and retains its `0640`
protection; do not make it world-readable just to satisfy the container.
`DREL_CA_CERTIFICATES_HOST_PATH` is the host CA bundle that validates Apple
TLS (commonly `/etc/ssl/certs/ca-certificates.crt` or
`/etc/pki/tls/certs/ca-bundle.crt`). The scratch image intentionally contains
no CA bundle of its own.

The image listens only on `127.0.0.1:${DREL_NATIVE_HOST_PORT:-8080}`. Put it
behind the existing Cloudflare Tunnel or HTTPS reverse proxy. Do not run it on
the same port as an already-active `drel-selfhosted.service`; stop one only
after the replacement has passed its health and physical-device acceptance
checks.

Run `bash tools/verify-drel-selfhosted-native-docker.sh` on a Docker host to
prove the registry-free image builds, safely mounts a disposable test key,
serves `/health` and its descriptor, and completes pairing, registration,
recipient discovery and one-time-ticket replay rejection. It generates and
deletes a non-provider P-256 key itself; it never reads a deployer key, touches
a real device, or sends APNs. Production delivery still needs the
physical-device checklist.

### Docker (alternative)

1. Point a public DNS name (for example `push.example.com`) at the Docker host
   and allow inbound TCP 80 and 443. From the checked-out `Server/` directory,
   copy `.env.example` to `.env`; set the
   matching `DREL_SELF_HOSTED_DOMAIN`,
   `DREL_SELF_HOSTED_PUBLIC_BASE_URL=https://push.example.com`,
   `DREL_SELF_HOSTED_ACME_EMAIL`, and a new `ADMIN_API_KEY`.
2. Create a local `secrets/` directory (already excluded from source control),
   place a production topic-specific `.p8` for `com.webbridgekit.superapp`
   inside it, and set `APNS_KEY_ID`,
   `APNS_TEAM_ID`, `APNS_KEY_PATH=/run/secrets/drel/<your-key>.p8`, and
   `APNS_TOPIC=com.webbridgekit.superapp`. The `.p8` belongs only on your
   server, must be readable by the container, and must never be committed.
   Apple also permits older team-scoped keys, but a production topic-specific
   key gives this deployment the narrowest available scope.
3. For TestFlight/App Store devices use `APNS_ENVIRONMENT=production`.
4. From that same `Server/` directory, start the production stack with
   `docker compose -f docker-compose.self-hosted.yml up -d --build`. It starts
   Caddy in front of the Swift server and automatically obtains HTTPS; mount
   both `/app/data` and the directory containing the `.p8` file. Use the
   simpler `docker-compose.yml` only when another reverse proxy already owns
   TLS.
5. Confirm `https://push.example.com/ping` returns `pong` and
   `https://push.example.com/.well-known/drel-push.json` returns the Drel
   descriptor. `/health` additionally reports `apnsReady: true`. A public
   HTTPS self-hosted process refuses to start when its APNs signer cannot be
   initialized, so it cannot accept pairings while silently dropping pushes.

The Compose stack waits for the server healthcheck before exposing Caddy. The
proxy receives only the domain and ACME email; it does not receive APNs,
administrator, or gateway secrets.

### Existing Nginx host

If another service already owns ports 80/443, do not run the Caddy stack.
Use `docker-compose.self-hosted-nginx.yml` instead; it binds the Swift service
only to `127.0.0.1:8080`. Install a rendered copy of
`nginx/drel-self-hosted.conf.template` in the host's Nginx configuration after
the host's normal ACME flow has issued the certificate. Replace both
`__DREL_SELF_HOSTED_DOMAIN__` placeholders, test with `nginx -t`, then reload
Nginx. This keeps existing sites on the host isolated while Nginx is the only
public TLS boundary for Drel.

For the managed Drel deployment at `push.drel.app`, the checked-in
`nginx/push.drel.app.acme.conf` is an HTTP-only certificate-issuance host.
Install it and reload Nginx before `certbot certonly --webroot`; after the
certificate exists, replace it with `nginx/push.drel.app.conf`, test with
`nginx -t`, and reload. Do not install the TLS file before its certificate
exists because it intentionally references the live certificate paths.
On a host without a Certbot systemd timer, install
`cron/drel-certbot-renew` as `/etc/cron.d/drel-certbot-renew`; it renews only
the Drel certificate and reloads Nginx only when renewal actually occurs.

Before public deployment, run `bash tools/verify-drel-selfhosted-docker.sh`
from the repository root on a machine with Docker. It builds an isolated image
and proves liveness, descriptor discovery, one-time pairing, and registration;
it intentionally does not send to APNs because that requires a real Drel
provider credential and a physical TestFlight device.

If the deployment host cannot reach Docker Hub but has an approved private
mirror, pass it only to this build rather than changing the daemon-wide Docker
registry configuration, for example:

```bash
docker compose -f docker-compose.self-hosted-nginx.yml build \
  --build-arg SWIFT_IMAGE=mirror.example/library/swift:6.0-noble \
  --build-arg RUNTIME_IMAGE=mirror.example/library/ubuntu:noble
```

Use an HTTPS mirror controlled or explicitly approved by the deployer, and
verify its image provenance before treating a mirror build as production.

The exact physical-device acceptance steps and redacted result table live in
[`docs/verification/drel-self-hosted-physical-device.md`](../docs/verification/drel-self-hosted-physical-device.md).
The managed `push.drel.app` host-specific handoff is
[`docs/verification/drel-replay-deployment.md`](../docs/verification/drel-replay-deployment.md).

## Pair an iPhone

In Drel open **Settings → 自托管推送**, then scan a deployment-generated
`drel://self-hosted-push?server=...&token=...` code or paste the HTTPS server
address. The app validates the descriptor, creates an installation-specific
public key, registers it once, and stores the resulting private key locally.

Create a deployment-generated configuration code with:

```bash
DREL_PAIRING_QR_OUTPUT=pairing.png \
  bash tools/create-drel-selfhost-pairing.sh https://push.example.com
```

The command prints the short-lived configuration URL and writes a QR image
when `qrencode` is installed. Treat either form as sensitive onboarding
material: it does not include APNs credentials or a device private key, but it
can enrol one device before expiring.

## Send

After pairing, the app shows a Bark-compatible push URL in its self-hosted
screen. That URL directly produces an ordinary APNs notification and exposes
its request content to the server that receives it:

```bash
curl -G 'https://push.example.com/<deviceKey>/Build%20finished/Inspect%20the%20result' \
  --data-urlencode 'url=https://drel.app/' \
  --data-urlencode 'mode=immersive'
```

This direct path is transport-encrypted, bypasses `api.drel.app`, and is not
zero-knowledge at the relay. Its URL query parameters and `POST /push` JSON
fields match the official Drel push contract, including `mode=immersive` for
full-screen URL launch, `display`, routing, grouping, images, badge, sound,
copy, and presentation metadata. The relay assigns `drelSourceChannel`
itself; senders cannot supply that field.

For end-to-end encryption against the self-hosted relay, first fetch only the
paired device's public key:

```text
GET /self-hosted/recipients/<deviceKey>
```

The response deliberately contains no APNs token or private key. Encrypt a
`PushPayload` JSON object with the returned X25519 key using the
`drel.push-envelope.v1` contract, then post only the opaque envelope:

```json
POST /push
{
  "deviceKey": "…",
  "title": "",
  "body": "",
  "drelEnvelope": "base64url(JSON envelope)"
}
```

The included Node.js 20+ sender is a runnable reference implementation:

```bash
node Server/examples/drel-encrypt-and-push.mjs \
  https://push.example.com <deviceKey> 'Build finished' 'Code 482901' \
  https://drel.app/
```

It performs recipient discovery, X25519 + HKDF-SHA256 + AES-256-GCM locally,
and posts no message plaintext to the relay. The server rejects malformed or
expired envelopes and strips any accidental outer title/body before APNs.
The complete wire contract is in
[`docs/api/drel-selfhosted-push.md`](../docs/api/drel-selfhosted-push.md).

The server stores registrations and short-lived pairing-ticket hashes under
`DATA_DIR`. Back up registrations carefully: they contain APNs device tokens
and public keys, not message plaintext or device private keys.
