# Push routing and release testing

## Route an application

Use structured JSON when routing a Drel app:

```json
{
  "device_key": "<recipient capability>",
  "title": "Build complete",
  "body": "Open the offline report",
  "appId": "com.example.console",
  "route": "/app/report.html",
  "display": "full",
  "params": { "build": "42" }
}
```

`appId + route` must match a locally trusted, signed parent manifest. The same
push opens the online page before the user downloads the package and the local
entrypoint only after a matching package is installed.

## Bridge compatibility matrix

| Capability | Drel 1.4 Store app | Notes |
| --- | --- | --- |
| Standard HTML/CSS/JS, `fetch`, Web Storage, History, Web Manifest | Supported | Use normal web feature detection. |
| Local verified HTML/CSS/JS/images declared in an offline package | Supported | Only after user installation and hash/signature verification. |
| `DrelRuntime` environment metadata | Supported when present | Informational only; treat missing fields as a browser fallback. |
| Native JS Bridge / `window.WebBridgeKit` / `window.BarkBridge` | Not supported | Bridge protocol version is `0`. |
| Camera, scanner, clipboard, photos, files, contacts, native permission UI | Not supported | Do not add an API shim or prompt workaround. |
| Push-driven approval, install, update or permission grant | Not supported | Navigation is not authorization. |

## Physical-device release checks

Verify an exact TestFlight build, not merely a simulator:

1. Receive and tap a routed push in foreground, background and lock screen.
2. Download an offline package only after an explicit user tap; record its
   version and storage size.
3. Force quit, enable airplane mode, relaunch Drel and open the app from the
   app list and Inbox. The static shell must launch locally.
4. Trigger local interaction offline and an asynchronous network refresh. The
   latter must fail gracefully or show clearly-labelled cached content.
5. Restore network and confirm dynamic data refreshes.
6. Interrupt an update, reject an invalid hash, delete the package, and verify
   the old version or network fallback behaves exactly as described.
7. Upgrade from the earlier Drel release and confirm addresses, message history
   and configured push channels remain available.

Never include a device push address, API key, token, or private test page in
public examples, issue reports or App Store screenshots.
