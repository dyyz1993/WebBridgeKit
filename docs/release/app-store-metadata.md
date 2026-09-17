# Drel 1.0 App Store Metadata Handoff

This is the reviewed source text for App Store Connect. It is a handoff file,
not proof that any field has already been saved remotely.

Builds `1.0 (44)` through `1.0 (47)` are superseded before review. Build 45 has
a cold-launch notification-permission defect; Build 46 is superseded by a
VoiceOver semantics correction; Build 47 still listed unshipped V1 capabilities
on its SwiftUI About screen. Build 48 fixed that screen locally but was not
uploaded because its first 31-symbol short-address encoder could crash. The
Build 49 was not uploaded because a fresh installation could fail to show its
copyable address before notification consent. Build 50 then failed Apple
processing with error 90683 because its final Info.plist lacked
`NSCameraUsageDescription`. Build `1.0 (51)` passed local distribution signing
and archive verification, and was uploaded exactly once on 2026-08-28; Apple
has acknowledged it as processing. Do not attach any earlier build, upload
Build 50 again, or re-upload Build 51 while processing.

## Confirmed URLs

| Field | Value |
| --- | --- |
| Support URL | `https://drel.app/support/` |
| Privacy Policy URL | `https://drel.app/privacy/` |
| Terms of Use | `https://drel.app/terms/` |
| Product site | `https://drel.app/` |
| Official API | `https://api.drel.app` |

## English (primary)

| App Store field | Approved value |
| --- | --- |
| Name | `Drel` |
| Subtitle | `Developer Push Notifications` |
| Promotional Text | `Push, right where you need it.` |
| Primary category | Developer Tools |
| Secondary category | Productivity |
| Keywords | `developer,push,notifications,webhook,API,automation` |
| Copyright | `© 2026 Drel` |

### Description

```text
Drel is a developer notification utility for iPhone.

Send a notification from your script, browser, automation, or service. When a
notification includes an HTTPS destination, Drel can open that exact page after
you tap it.

• Copy a personal push address and send a first notification in minutes
• Open an HTTPS destination from a notification you tap
• Keep an inbox of the notifications you choose to open
• Use the official Drel push service immediately after enabling notifications

Drel is built for developers using their own services. It is not a public app
marketplace or a general-purpose browser.

For the first Store release, remote web pages run in a secure container and do
not receive a JavaScript-to-native Bridge. Notifications may open a route, but
cannot authorize or perform sensitive actions by themselves.

Built with WebBridgeKit.
```

## Chinese localization (optional at first upload, ready to paste)

| App Store field | Approved value |
| --- | --- |
| 名称 | `Drel` |
| 副标题 | `开发者推送通知` |
| 宣传文本 | `把推送送到真正该出现的地方。` |
| 关键词 | `开发者,推送,通知,Webhook,API,自动化` |

### 描述

```text
Drel 是面向 iPhone 开发者的推送通知工具。

从脚本、浏览器、自动化或自己的服务发出一条通知；当通知包含 HTTPS 目标地址时，点击通知即可由 Drel 打开该页面。

• 复制个人推送地址，几分钟内发出第一条通知
• 点击通知后打开指定的 HTTPS 页面
• 在收件箱中查看你选择打开的通知
• 开启通知后即可使用官方 Drel 推送服务

Drel 适合开发者配合自己的服务使用，不是公开应用市场，也不是通用浏览器。

首个 Store 版本以安全网页容器运行：远程页面不会获得 JavaScript 到原生的 Bridge。推送可以打开指定路由，但不能自行授权或执行敏感操作。

Built with WebBridgeKit.
```

## Store media plan

Current files under `docs/screenshots/` are development and visual-regression
baselines. They are **not** an approved App Store set: several show legacy
debug/Bridge screens and must not be uploaded.

Apple requires Store screenshots (one to ten per display target); the following
six-frame set is Drel's recommended narrative, not an Apple minimum. Capture
them from the final TestFlight build with no test data, tokens, private
addresses, debug labels, or simulated unread count. App Preview video is
optional; if we create one later, keep it to the official 15–30 second limit
and show only the shipped product.

1. **Home** — personal push address and one clear “copy / first push” action.
2. **Inbox** — one realistic incoming notification, showing the route outcome.
3. **Web tool** — a developer-owned page opened from that notification.
4. **Notification settings** — the permission state and recovery guidance.
5. **Route result** — the same developer-owned page opened from a notification.
6. **Settings / privacy** — storage, Support, and Privacy links.

Use the currently required App Store Connect device-size set shown for this app
record at upload time; Apple changes accepted device classes over time. Export
opaque PNG or JPEG only (no alpha), then re-open the uploaded media to confirm
the order and crop.

## App Store Connect fields that need an authorized human decision

- App record ownership, availability territories, price, and tax/banking.
- Age-rating questionnaire answers.
- App Privacy answers, after a documented review of gateway-side collection and
  retention. The privacy policy alone is not an answer to this questionnaire.
- Review contact name, email, and phone number.
- Export compliance answer for the exact signed archive.
- The highest existing App Store Connect build. Set
  `CURRENT_PROJECT_VERSION` to that value plus one **only after checking it**;
  do not upload the repository's current build number blindly.

## TestFlight handoff order

1. Confirm the App ID `com.webbridgekit.superapp` and Push Notifications
   capability in the paid Apple Developer team.
2. In Xcode Settings → Accounts, sign in with an account authorized for that
   paid team and let Xcode download/create the **App Store distribution**
   profiles for both `com.webbridgekit.superapp` and
   `com.webbridgekit.superapp.nse`. A development profile is not enough. The
   final export must be signed by Apple Distribution, have
   `aps-environment=production`, and have `get-task-allow=false`.
3. Build `1.0 (51)` must pass the final release gate, Apple Distribution
   signing, production APNs, and `get-task-allow=false` checks for both the host
   app and notification extension before it is uploaded once. Do not attach or
   submit Builds 44–48.
4. After Apple processes Build 51, attach that exact build to TestFlight and install it on a
   clean physical iPhone.
5. Run the manual APNs matrix: foreground, background, and locked-screen plain
   push; then route push. Confirm that a tap opens the expected URL/route and
   that no remote page gets a native Bridge.
6. Only then capture the final screenshots and submit the version with
   `docs/app-store-review-notes.md`.
