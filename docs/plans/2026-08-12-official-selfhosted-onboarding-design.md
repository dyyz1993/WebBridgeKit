# Official and Self-hosted Onboarding Design

## Product decision

WebBridgeKit has two explicit product paths. They share the same Inbox, PWA
runtime, message protocol, and security boundaries, but they must not expose
the same setup burden.

1. **Official hosted app (default):** install and use. The official gateway is
   already active, so a person can copy the documented `curl`, receive a
   notification, open its PWA route, and use native approval without entering
   a server address, public key, or gateway screen.
2. **Open-source self-hosted app:** connect a compatible gateway once after
   deployment. The deployment operator provides a QR code or portable gateway
   document; pasting a URL/configuration is the equivalent fallback. The host
   validates it, displays what will be trusted, then activates only after the
   user confirms.

This preserves normal PWA compatibility: a gateway identifies and serves
trusted applications; it does not turn arbitrary inline HTML into a privileged
native application.

## Candidate approaches

### A. One universal mandatory setup screen

Every installation starts by adding a gateway. This makes the implementation
look uniform, but wrongly makes official users complete infrastructure setup
before they can use a product that already has an official service.

### B. Official-first with an explicit self-hosted connection entry (recommended)

The first-run experience is ready to use with the official gateway. The Apps
center contains a secondary `连接自有服务` action and Settings keeps gateway
management for later editing, switching, or removal. This removes ordinary
user friction while keeping self-hosting discoverable and reversible.

### C. Build-flavour-only configuration

The official binary is locked to the official service and the open-source
binary always asks for a gateway. This creates two divergent products and
prevents a user from moving to a compatible self-hosted service without a new
build, so it conflicts with the portable gateway contract.

## Recommended screens and flow

### 1. Official first run and Apps center

The default Apps tab shows installed or available official PWA applications,
their offline/update state, and a normal empty state when none are installed.
It does **not** show a blocking gateway form. A low-emphasis action, `连接自有
服务`, opens self-hosted import only when deliberately chosen. Documentation
uses the same distinction: the official quick start begins with a device key
and a send example, while self-hosted instructions begin with deployment and
gateway import.

### 2. Self-hosted gateway import

The import page offers two equal actions: `扫描二维码` and `粘贴配置`. It accepts
a portable JSON document or `webbridgekit://gateway` URL, not a device token,
API secret, or private key. A bare URL may be accepted only when it can be
expanded into the required gateway document. Production imports require an
exact HTTPS origin; local HTTP is visibly development-only.

### 3. Validation and confirmation

Before persistence, the app fetches the health endpoint and each returned HTML
app manifest, verifies the declared production public-key identity, and shows
the display name, host, health endpoint, manifest endpoint, and application
count. The only affirmative action is `确认并启用`; failure preserves no partial
trust. Switching gateways does not carry over PWA permission grants or trusted
manifests from the previous gateway.

## Acceptance criteria

- A fresh official install reaches Apps and Inbox without a gateway form.
- A self-hosted user can import the same gateway with QR or pasted portable
  configuration and receives the same validation report.
- Invalid origins, failed health checks, invalid manifests, and invalid
  production signing information cannot be activated.
- The confirmation screen makes the remote host and endpoints visible before
  activation; imported data contains no APNs token, private key, or API secret.
- After activation, a message containing `appId + route + params` opens the
  intended trusted PWA route. It may locate an approval but cannot approve it
  automatically; the target state is revalidated and the user still consents.
- Gateway switching/removal isolates old per-app manifests and capability
  grants. A new gateway requires its own validation and confirmation.

## Implementation order

1. Audit the current Apps center and gateway screens against this flow; create
   simulator screenshots for official default, QR import, paste import,
   validation failure, and successful confirmation.
2. Close any missing import/validation/permission-isolation behavior and add
   focused model and UI tests.
3. Add two concise documentation paths and deployment-produced QR examples.
4. Only then run the cross-product route test and start the offline-package
   installation/update work.
