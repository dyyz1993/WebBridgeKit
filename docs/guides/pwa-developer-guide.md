# WebBridgeKit PWA Developer Guide

WebBridgeKit hosts standards-compatible PWAs. A normal PWA continues to use its
web manifest, Service Worker, Cache Storage, localStorage and IndexedDB. Native
enhancements are opt-in through a signed WebBridgeKit app manifest served by a
compatible gateway.

## Gateway app manifest

```json
{
  "schemaVersion": "1",
  "appId": "com.example.chat",
  "name": "Example Chat",
  "startURL": "https://example.com/app/index.html",
  "allowedOrigins": ["https://example.com"],
  "routes": ["/app/index.html", "/app/chat/*", "/app/approval/*"],
  "capabilities": ["notification", "camera", "fileImport"],
  "cache": {
    "strategy": "manifest",
    "version": "2026.08.10",
    "persistent": true,
    "resourceManifestURL": "https://example.com/app/resources.json",
    "restoresLastState": true
  },
  "signature": { "algorithm": "ed25519", "keyId": "prod-key-1", "value": "BASE64_SIGNATURE" }
}
```

The signed manifest identifies the app, limits routable pages and declares
requested native capabilities. A production gateway uses HTTPS and an Ed25519
public key delivered in the user-confirmed gateway configuration.

## Native enhancements

Use the optional Bridge only when running inside WebBridgeKit:

```js
await window.WebBridgeKit.navigation.back();
await window.WebBridgeKit.navigation.close();
```

Notification payloads name an `appId`, allowed `route` and serializable
parameters. They are navigation data only. A notification can open an approval
page but must never approve a sensitive action.

For partial offline startup, store UI state in localStorage or IndexedDB. The
host loads cached content first when the manifest asks for it, then lets the PWA
refresh from the network. Strong offline is opt-in: the resource manifest is
verified and atomically installed in host-managed storage, so it remains
available even if normal WebKit caches are evicted.
