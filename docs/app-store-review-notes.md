# Drel 1.0 — App Review Notes

Paste the following into **App Review Information → Notes** after confirming
the exact uploaded build and push-service availability. It deliberately describes
the submitted Store build, not the bridge-capable open-source SDK.

```text
Drel is a developer notification utility and trusted web-tool container.

No account or demo credentials are required to review the app.

Suggested review flow:
1. Open Drel. Home shows the public personal push address; no account or
   credentials are required.
2. Allow notifications to test delivery. The permission is optional for browsing.
3. After registration, use Home's test-push control. It opens a prefilled,
   ordinary Bark-compatible `api.drel.app` request in Safari; no private URL,
   secret, or reviewer account is needed.
4. To verify HTTPS routing, open **Push examples**, select **点击跳转**,
   use its explicit send control, then tap the arriving notification. Drel
   opens the declared public HTTPS destination in its secure web container.

The 1.0 Store build is container-only: remote web pages receive no WebBridge.js,
no JavaScript-to-native message handler, and no remote native capabilities.
Push fields may navigate to a page or route only; they cannot approve or execute
sensitive actions. The V1 Store build does not include web-tool installation,
gateway import, or offline package management.

Official service endpoint: https://api.drel.app
Support: https://drel.app/support/
Privacy Policy: https://drel.app/privacy/
Terms of Use: https://drel.app/terms/
```

## Guideline 2.1 information request (2026-08-29)

Apple requested supplementary review information for the submitted new-app
review.  The following English text is ready to paste into **App Review
Information → Notes** after the physical-device recording is attached.  Do not
claim that the recording is attached until it has actually been uploaded.

```text
Drel is a developer push-notification utility for iPhone. It lets a developer
copy a personal push address, send notification messages from their own script,
automation, browser, or service, and open an explicit HTTPS destination only
after the user taps a notification. It solves the need to deliver operational
messages to a developer's iPhone without creating an account or operating an
in-app marketplace.

Physical-device test coverage: iPhone 13 (iPhone14,5), iOS 18.7.3, using the
processed TestFlight build 1.0 (60). The attached recording is captured on that
physical device and shows the normal first-run flow: enable the optional
notification permission, view the generated personal push address, send a test
notification with the “Send Test in Safari” control, view it in the Inbox, then
use the **点击跳转** Push example and open its explicit HTTPS destination by
tapping that notification.

No account registration, login, account deletion, purchase, subscription,
payment, user-generated content, social content, or content-reporting/blocking
flow exists in Drel 1.0. No demo account, credentials, or sample file is
required. To access the main features: launch Drel; select “Enable
Notifications” and allow the optional iOS notification prompt; then use the
Home test control or Push examples. The app generates the review device's
temporary address locally and opens a prefilled public API request in Safari.

Core external services: Apple Push Notification service (APNs) and Drel's
official push endpoint at https://api.drel.app. There are no advertising,
analytics, payment, authentication, AI, or third-party data-provider services.
The app has no intentional regional feature or content differences and offers
the same V1 functionality in all storefronts.

Drel is not in a regulated industry and includes no protected third-party
content or service that requires a licence. It is not a public app marketplace
or a general-purpose browser. The Store build is a secure HTTPS container:
remote pages receive no JavaScript-to-native Bridge and cannot invoke native
capabilities. Push parameters can navigate only; they cannot approve or
perform sensitive actions.

Support: https://drel.app/support/
Privacy: https://drel.app/privacy/
Terms: https://drel.app/terms/
```

### Required physical-device recording

Record on the current TestFlight iPhone (not Simulator), beginning before
launch.  Keep the recording roughly 30–45 seconds and do not show a real
personal push address, API key, other notification content, or unrelated phone
data.  Use a newly generated address and revoke it after review if it is shown.

1. Start iOS Screen Recording, then launch Drel from the Home Screen.
2. Tap **Enable Notifications**, show the iOS notification permission sheet,
   choose Allow, and return to Drel.
3. Show the ready state and the personal-address card without copying it to the
   recording.
4. Enter harmless title/body text, tap **Send Test in Safari**, show the public
   request completing, then show the arriving notification and its Inbox entry.
5. Open **推送示例**, use the explicit send control for **点击跳转**, tap that
   arriving notification, and show the developer-owned HTTPS page it opens.
6. Stop the recording.  Upload that movie as the private App Review attachment,
   not as a public App Preview.

### Build 60 recording candidates (2026-08-31)

- `docs/release/media/drel-app-review/Drel-1.0-Build-60-physical-device-review-curated.mp4`
  is the 1:43 H.264/AAC, 888×1920, 10.9 MB review cut.
- `docs/release/media/drel-app-review/Drel-1.0-Build-60-physical-device-review-full.mp4`
  is the 3:03 H.264/AAC, 888×1920, 16.9 MB full recording.
- Both are derived from the physical iPhone 13 TestFlight Build 60 recording.
  They begin inside Drel at the first-run permission flow rather than showing a
  Home Screen icon tap. They are suitable as supplemental/fallback evidence,
  but a replacement recording beginning on the Home Screen is still the lowest
  risk response to Apple's exact Guideline 2.1 request.

## Submission checks

- Verify that `https://api.drel.app/health` is reachable immediately before
  submission; do not paste operational credentials or private push addresses
  into these notes.
- If Apple needs a reproducible notification, create a temporary review-only
  push address through the normal app flow and revoke it after review. Do not
  share a long-lived personal address.
- Because push delivery and its destination route span the push service and iOS
  notification delivery, attach the private walkthrough described in
  `docs/release/app-review-walkthrough.md` if the temporary review flow is not
  sufficient. It is review-only evidence, not a public App Preview.
- Do not claim that remote WebBridge capabilities are available in Drel 1.0.
  They remain an open-source SDK capability and a possible future product phase.

## App Privacy preparation

### Verified questionnaire baseline (2026-08-26)

Do **not** select “Data Not Collected.” The official gateway persists the APNs
device token and a per-installation push address in its registration store so
it can deliver subsequent notifications. In App Store Connect, select:

| Data type | Collected | Linked | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Identifiers → Device ID | Yes | Yes | No | App Functionality |

This is based on the deployed gateway contract: device registrations are
persisted, while message-history persistence is disabled unless the operator
explicitly enables `MESSAGE_HISTORY_ENABLED=1`. Production was verified with
`MESSAGE_HISTORY_ENABLED=0` on 2026-08-26. The first Store build has no
advertising or analytics SDK, no account system, and no cross-app tracking.

Do not add Other Data Types, User Content, Browsing History, or Diagnostics
merely because the app can display a received notification or open a web page:
Drel does not send that data from the app to the official gateway for later
storage. The device ID is linked because the official gateway associates the
APNs token with that installation's push address; it is not used for tracking.
Re-evaluate these answers before every release if gateway retention changes,
message history is enabled, or any remote diagnostics/analytics is added.

The Store binary exposes notification permission only for the V1 user journey.
It does not expose remote Bridge permissions (location, microphone, contacts,
Bluetooth, photos, speech, motion, or Face ID).
