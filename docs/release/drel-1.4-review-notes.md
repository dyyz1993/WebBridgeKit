# Drel 1.4.0 — Review Notes and Demonstration Script

This document updates the Build 60 review package for the 1.4.0 submission.
Attach it to the version in App Store Connect together with the
physical-device recording described below.

## 1. Summary of what is new in 1.4.0

1.4.0 keeps every 1.0 capability (personal push address, inbox, named
sounds, tap-to-open an explicit HTTPS destination) and adds:

- **Private HTML apps**: the user imports a gateway configuration (or
  receives a signed activation via push) for HTML apps that THEY trust.
  Apps are pinned by Ed25519-signed manifests served from
  https://api.drel.app. Every app declares its own routes, icons and
  optional strong-offline package.
- **drel://app links**: other apps, Shortcuts, QR codes or push messages
  can deep-link INTO a registered HTML app at a specific route with
  parameters. The link can never open an arbitrary URL — see section 6.
- **Strong-offline packages**: per-app resources are downloaded once,
  verified against SHA-256 digests pinned in the signed manifest, stored
  locally, and can be launched with no network.
- **Notification icon avatar**: a push may carry an `icon` URL; the
  Notification Service Extension downloads it and donates it through an
  INSendMessageIntent so the sender avatar replaces the app icon slot,
  mirroring the well-known Bark developer-service pattern.
- **Favorites and gestures**: pinned favorites, full-swipe pin, fullscreen
  reopen, consistent with the inbox.

## 2. Physical-device recording (attached privately)

Recorded on a physical iPhone 13 (iPhone14,5) running iOS 18.7.3 with
TestFlight Build 88 (same code and entitlements as the submitted binary):

1. First launch → notification permission → personal push address shown.
2. A test push arrives; the notification shows a custom sender avatar in
   the app-icon slot (icon-avatar feature).
3. Tapping the notification opens the Inbox; a message with a markdown
   link is opened.
4. From Safari, the reviewer-visible link
   `drel://app?app_id=dev.drel.data-template&route=/test/template/v1/index.html&param_title=%E5%A4%96%E9%83%A8%E6%8B%89%E8%B5%B7`
   opens the registered "Drel Data Template" app immersive (no navigation
   bar) and the page renders the carried parameter 外部拉起.
5. An UNREGISTERED link (`app_id=dev.drel.not-registered`) shows an
   explanatory "应用未注册" dialog and opens nothing — fail-closed.
6. Airplane mode is enabled; the registered app still opens from its
   verified offline package (strong-offline demonstration).
7. Favorites: full-swipe pin, fullscreen reopen from the favorites list.

## 3. Functions, target audience, problem, and value

Drel is a developer push-notification utility and a secure container for
the user's own trusted HTML apps. Developers copy a personal push address,
send notifications from their own scripts, browsers or services, keep an
Inbox, and optionally route taps into pages they control. 1.4.0 extends
this with private HTML apps the user explicitly imports, deep links into
those apps, verified offline packages, and richer notifications.

## 4. Setup and access instructions

No registration, login, demo credentials, purchase, subscription, or
sample file is required.

1) Launch Drel.
2) Tap 启用通知 and allow the optional iOS notification prompt.
3) Use the Home test control (发送测试通知 / 用 Safari 发送测试) to send a
   harmless test notification.
4) The two official demo apps (Drel Data Template, Drel 离线网络演示) are
   available out of the box from the official gateway; open either from
   the Home 我的应用 grid, or download its offline package from
   我的应用 → 管理及其详情页 (下载离线包).
5) To exercise drel://app, paste the link from section 2 step 4 into
   Safari.

The generated push address belongs only to the current app installation
and can be rotated by reinstalling.

## 5. External services, tools, and platforms

Core services are Apple Push Notification service (APNs) and Drel's
official endpoint at https://api.drel.app (push ingress, gateway manifest
list, demo app hosting on https://drel.app). There is no advertising,
analytics, payment, authentication, AI, or third-party data-provider
service. Self-hosted users may point the app at their own compatible
server; the official service remains the default and the reviewer path.

## 6. drel://app deep links — scope and safety (Guideline 2.1)

- The scheme accepts only `app_id` + `route` + `param_*` values. There is
  deliberately NO `url=` passthrough.
- `app_id` must exist in the on-device trust registry, whose entries come
  only from Ed25519-signed gateway manifests (or push activation of the
  same). Unknown IDs produce an explanatory dialog and open nothing.
- Routes must match the routes declared by the signed manifest; parameters
  are delivered to the page as `drel_param_*` query values and must be
  rendered with textContent by the template contract. Remote pages still
  never receive WebBridge.js or native bridge capabilities.
- The official demo apps are the only registered apps on a fresh install;
  both are simple static template pages hosted by Drel itself.

## 7. Notification icon avatar — scope and safety

- The `icon` value is a URL supplied by the SENDER of the push (the
  developer using their own push address), fetched by the Notification
  Service Extension over HTTPS only (≤5 MB), and presented via
  INSendMessageIntent donation — the same mechanism Bark-style developer
  services use. There is no user-tracking, no profile building, and no
  access to private user data; the image is used once as the
  notification's sender avatar and cached locally.

## 8. Tested devices and operating systems

- Physical device: iPhone 13 (iPhone14,5), iOS 18.7.3, TestFlight
  Build 88 — notification delivery, icon avatar, tap routing, drel://app
  (registered + unregistered), strong-offline open in airplane mode,
  favorites gestures.
- Simulator regression: recent Xcode iPhone simulators, Release
  configuration, for UI and offline-package update coverage
  (v2 → v3 atomic update exercised).

## 9. Regional differences

None. 1.4.0 provides the same functionality in all storefronts.

## 10. Regulated industry and protected material

Drel is not in a regulated industry and contains no protected third-party
content. It has no public app catalogue, marketplace, UGC, content
reporting, or account system. Remote HTTPS pages do not receive
WebBridge.js, JavaScript-to-native handlers, or native capabilities. Push
parameters can navigate only; they cannot approve or perform sensitive
actions.

Official service: https://api.drel.app
Support: https://drel.app/support/
Privacy Policy: https://drel.app/privacy/
Terms of Use: https://drel.app/terms/
