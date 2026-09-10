---
name: drel-app-development
description: Build or review a standards-compatible web app for Drel, including Drel 1.4 strong-offline packages, signed manifests, push routing, and Store-safe capability boundaries. Use when a developer asks to make a Drel web app work offline or from a Drel push; do not use it to expose a native Bridge that the current Store app does not ship.
---

# Drel App Development

## Compatibility contract

| Item | Current public contract |
| --- | --- |
| Skill | `1.0.0` |
| Drel app | `1.4.0` |
| Offline package | `1` |
| Container protocol | `1` |
| Native Bridge | `0` — unavailable in the App Store container |

Build a normal standards-compatible web app first. A Drel app is not a
proprietary HTML format: standard browsers must still be able to load it. Use
Drel-specific metadata only for the opt-in, verified offline-installation
path.

## Choose the smallest applicable path

- **A normal web destination**: use HTTPS and ordinary web APIs. A push may
  open it, but it is not an installed Drel app.
- **A named Drel application**: add a standard Web App Manifest and have an
  operator sign a parent Drel manifest. Read
  [web app manifest](references/web-app-manifest.md).
- **A durable offline app**: additionally publish the verified resource
  manifest and `drel_offline` declaration. Read
  [offline packages](references/offline-packages.md) before generating files.
- **A push into an app route**: send a supported `appId + route + params`
  message. Read [push and testing](references/push-and-testing.md).

## Non-negotiable boundaries

1. Drel 1.4's Store container exposes **no native JavaScript Bridge**. Do not
   call or assume `window.WebBridgeKit`, `window.BarkBridge`, camera, clipboard,
   local files, photo library, native permission prompts, or custom commands.
   Use normal browser APIs such as `fetch`, DOM, history, CSS safe-area
   environment variables and Web Storage, with ordinary browser fallbacks.
2. A push supplies navigation data, not authority. It must never approve an
   action, grant permission, install a package, update a package, or create an
   app without a foreground user action.
3. A Web App Manifest does not make an app offline. Never describe Service
   Worker or WebKit cache as Drel's durable offline mode.
4. Treat query parameters, `DrelRuntime`, and the User-Agent as hints for
   layout/compatibility only. They are not authentication or authorization.
5. Keep access tokens, one-time codes and device push addresses out of
   `start_url`, screenshots, fixtures, logs, and generated documentation.

## Working procedure

1. Define a stable `appId`, an HTTPS origin, a scoped start route, and an
   ordinary Web App Manifest. Remove credentials and temporary query parameters
   from the start route.
2. For offline support, publish immutable versioned assets. Produce the exact
   resource-manifest bytes and hashes before signing the parent manifest; do not
   mutate a file at an already published version URL.
3. Give users explicit actions to download, update, or delete a package. A
   failed update must leave the prior complete version launchable.
4. Send a test push to the exact `appId + route`; test both the online fallback
   before installation and the local package launch after installation.
5. Validate on a physical iPhone: cold start in airplane mode, local interaction,
   recovery after the network returns, interrupted update, invalid hash rejection,
   deletion, and upgrade preservation. The simulator does not prove APNs or
   airplane-mode release behavior.

## Runtime adaptation

When present, `window.DrelRuntime` reports whether the page is a network page
or a verified local package. Write feature detection, not browser sniffing:

```js
const runtime = window.DrelRuntime;
const isInstalledOffline = runtime?.isOfflinePackage === true;
const bridgeAvailable = Number(runtime?.bridgeVersion ?? 0) > 0;
```

`bridgeAvailable` is false for the current Store app. In an offline package,
local HTML/CSS/JS/images can launch without a network; APIs, CDNs, dynamic
images, sign-in and any unlisted resource still need a network and must show a
clear fallback.

## When requirements exceed this skill

Do not invent an API to solve a request for native camera, scanning, clipboard,
file export, contacts, notifications, or background execution. Those are a
future Drel 1.5 security-and-review decision, not a compatibility shortcut.
Explain the missing capability and keep the web app functional without it.
