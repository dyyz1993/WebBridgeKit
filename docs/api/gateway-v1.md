# WebBridgeKit Gateway Import Contract v1

## Purpose

Gateway v1 is a portable, public configuration document for connecting a
WebBridgeKit host to a compatible self-hosted gateway. It carries endpoint and
Ed25519 verification metadata only. Importing it never grants application
capabilities and never authorizes a push or approval action.

## Canonical JSON

```json
{
  "schemaVersion": "1",
  "id": "example-gateway",
  "displayName": "Example Team Gateway",
  "baseURL": "https://gateway.example.com",
  "healthEndpoint": "/health",
  "manifestEndpoint": "/api/v1/html-apps",
  "publicKeyId": "prod-ed25519-1",
  "publicKey": "BASE64URL_32_BYTE_ED25519_PUBLIC_KEY"
}
```

| Field | Required | Contract |
|---|---:|---|
| `schemaVersion` | yes | Must be exactly `1`. |
| `id` | no | Stable local identifier. A random identifier is generated when omitted. |
| `displayName` | yes | Non-empty, user-visible gateway name. |
| `baseURL` | yes | Exact HTTPS origin: no path, query, fragment, or credentials. |
| `healthEndpoint` | yes | Absolute path on the exact `baseURL` origin. |
| `manifestEndpoint` | yes | Absolute path on the exact `baseURL` origin. |
| `publicKeyId` | yes in production | Identifier that every signed app manifest must match. |
| `publicKey` | yes in production | Base64/Base64URL encoded 32-byte Ed25519 public key. |

Development builds may accept unsigned `http://localhost`, `127.0.0.1`, or
`::1` candidates. Release validation never accepts HTTP.

## URL Form

The equivalent QR payload may use shallow query items:

```text
webbridgekit://gateway?schemaVersion=1&id=example-gateway&displayName=Example%20Team%20Gateway&baseURL=https%3A%2F%2Fgateway.example.com&healthEndpoint=%2Fhealth&manifestEndpoint=%2Fapi%2Fv1%2Fhtml-apps&publicKeyId=prod-ed25519-1&publicKey=BASE64URL_PUBLIC_KEY
```

Duplicate query items are rejected. JSON and URL inputs enter the same origin,
endpoint, trust-anchor, and secret-field validation pipeline.

## Forbidden Values

Never include APNs device tokens, API or client secrets, passwords, management
tokens, user credentials, or private keys. Payloads containing fields such as
`privateKey`, `apiSecret`, `clientSecret`, `token`, `adminToken`, or `password`
are rejected before decoding, even if the field would otherwise be unknown.

Invalid examples:

```json
{"schemaVersion":"1","displayName":"Unsafe","baseURL":"http://public.example.com","privateKey":"..."}
```

```text
webbridgekit://gateway?displayName=Unsafe&baseURL=https%3A%2F%2Fgateway.example.com&token=secret
```

## Validation and Activation Lifecycle

1. Parse and structurally validate the candidate without persistence.
2. Fetch `healthEndpoint`; require HTTP 2xx and JSON containing `status: "ok"`.
3. Reject any final response URL outside the configured exact origin.
4. Fetch the complete manifest collection.
5. Validate every app identity, route, allowed origin, key ID, and Ed25519 signature.
6. Show a native report with the host, endpoints, public-key ID, and app count.
7. Persist the gateway, manifests, and permission boundary only after explicit user confirmation.

Activation is transactional. A persistence failure retains the previously
active gateway, trusted manifests, and permission grants. A change of origin or
trust anchor clears old grants instead of transferring them to the new identity.

## Error Semantics

| Category | Meaning | Client behavior |
|---|---|---|
| parse/schema | Unsupported payload, missing/invalid/secret field | Stay on input; show the exact field. |
| transport | DNS, TLS, timeout, or unreachable endpoint | Stay on input; permit retry/edit. |
| HTTP | Health or manifest endpoint returned non-2xx | Show endpoint and status code. |
| origin | Endpoint or redirect escaped the exact origin | Reject; do not activate. |
| trust | Key missing, manifest invalid, or signature failed | Reject the entire manifest set. |
| persistence | Atomic activation failed | Restore the previous active bundle. |

## Deployment QR Example

Generate a QR locally without embedding any credentials:

```bash
payload='{"schemaVersion":"1","id":"example-gateway","displayName":"Example Team Gateway","baseURL":"https://gateway.example.com","healthEndpoint":"/health","manifestEndpoint":"/api/v1/html-apps","publicKeyId":"prod-ed25519-1","publicKey":"BASE64URL_PUBLIC_KEY"}'
qrencode -o webbridgekit-gateway.png "$payload"
```

The public key is safe to distribute. The corresponding private key must remain
only in the gateway signing environment.
