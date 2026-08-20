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
  "capabilities": ["notification", "camera", "fileImport", "clipboard"],
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

Use the public, optional Bridge facade. Do not call the internal `BarkBridge`
object from application code:

```js
await window.WebBridgeKit.navigation.back();
await window.WebBridgeKit.navigation.close();
```

Protected calls are authorized automatically at the native dispatch boundary.
The PWA supplies a human-readable `reason`; it does not decide the grant scope
and it cannot bypass the native confirmation UI:

```js
const result = await window.WebBridgeKit.callNative("clipboard", {
  action: "read",
  reason: "Paste the order number into this form"
});
```

A standards-compatible PWA must remain usable in a normal browser. If the PWA
can also be opened outside WebBridgeKit, install a small browser fallback before
calling native modules. It resolves a structured result instead of throwing
because an injected object is missing:

```js
window.WebBridgeKit = window.WebBridgeKit || {};
window.WebBridgeKit.isAvailable = window.WebBridgeKit.isAvailable || (() =>
  typeof window.BarkBridge?.callNative === "function" &&
  (typeof window.BarkBridge.isAvailable !== "function" || window.BarkBridge.isAvailable())
);
window.WebBridgeKit.callNative = window.WebBridgeKit.callNative || (async (module, params = {}) => {
  if (window.WebBridgeKit.isAvailable()) {
    return window.BarkBridge.callNative(module, params);
  }
  const message = `The current container does not provide the ${module} native module.`;
  return {
    success: false,
    available: false,
    code: "NATIVE_MODULE_UNAVAILABLE",
    module,
    error: message,
    message
  };
});
```

Use `isAvailable()` to adjust labels or hide purely native actions. Keep
ordinary web content available; treat `NATIVE_MODULE_UNAVAILABLE` as a normal
capability result, not as an application failure.

### Bluetooth authorization flow

Declare `"bluetooth"` in the signed manifest, then call the protected module:

```js
const status = await window.WebBridgeKit.callNative("bluetooth", {
  reason: "Discover nearby BLE devices"
});
```

The user sees two separate native-owned layers. WebBridgeKit first shows the
managed-PWA consent sheet with the app name, origin, purpose and `once`,
`appSession`, `always`, or cancel choices. Only after that succeeds may
CoreBluetooth initialize and let iOS show its system Bluetooth prompt. The PWA
must not imitate either permission UI. A WebBridgeKit grant can be revoked in
the PWA app details; an iOS denial must be changed in Settings.
The app details show the current iOS system status next to every declared
capability so a WebBridgeKit grant is not mistaken for system authorization.

The current Bluetooth module exposes status, `startScan`, `stopScan`, state
events and discovered-device events. Connecting, pairing, reading and writing
are not yet part of the stable contract and must not be advertised as available.

The capability must also appear in the signed app manifest. Undeclared
capabilities, unverified pages, mismatched origins, and user cancellation return
`PWA_CAPABILITY_DENIED` without executing the native handler. The host offers
`once`, `appSession`, and `always` scopes. Persistent grants are scoped to
`appId + origin + capability`; changing gateway identity, removing an origin,
or removing a declared capability invalidates the affected grants.
`appSession` lasts only while that exact PWA container and origin remain active.
Closing the container, WebView reuse, or a cross-origin navigation clears the
session grant but does not remove an `always` grant. Cancelling or closing an
authorization sheet also consumes the pending request, so a late UI callback
cannot execute the native handler or resolve the same Bridge call twice.

Current protected mappings include camera/scan/torch, microphone/speech/audio
level, location, Bluetooth, contacts, clipboard, photo library, file
import/export, share, local notification, biometrics, motion sensors, display
status, and host device controls. The host's PWA application screen lists both
the manifest declarations and active grants, and lets the user revoke one grant
or all grants for the app. iOS-level authorization remains controlled in
Settings.

Notification payloads name an `appId`, allowed `route` and serializable
parameters. They are navigation data only. A notification can open an approval
page but must never approve a sensitive action.

For partial offline startup, store UI state in localStorage or IndexedDB. The
host loads cached content first when the manifest asks for it, then lets the PWA
refresh from the network. Strong offline is opt-in: the resource manifest is
verified and atomically installed in host-managed storage, so it remains
available even if normal WebKit caches are evicted.
