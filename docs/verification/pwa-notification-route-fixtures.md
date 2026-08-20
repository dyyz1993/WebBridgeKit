# PWA Notification Route Fixtures

This document defines repeatable local evidence for native notification routing
into standards-compatible PWAs. These fixtures use only the generic HTML app
contract: `appId`, an allowlisted route, and string parameters.

## Local Prerequisites

```bash
bash scripts/services.sh start
bash scripts/services.sh verify
```

The simulator fixture origin is `http://localhost:8081`. It is development-only
and is accepted only by the DEBUG fixture registration path.

## Acceptance Cases

| Case | Launch command | Expected result |
| --- | --- | --- |
| Chat notification | `xcrun simctl launch booted com.webbridgekit.superapp --register-pwa-notification-fixture --open-pwa-notification-fixture` | Opens `com.webbridgekit.fixture.chat` at the chat PWA route with `conversationId=user-42` and `messageId=message-7`. |
| Task complete | `SIMCTL_CHILD_WBK_PWA_FIXTURE_CASE=task xcrun simctl launch booted com.webbridgekit.superapp --register-pwa-notification-fixture --open-pwa-notification-fixture` | Opens `com.webbridgekit.fixture.agent-console` at its task route with `taskId=run-20260810` and `status=completed`. |
| Approval required | `SIMCTL_CHILD_WBK_PWA_FIXTURE_CASE=approval xcrun simctl launch booted com.webbridgekit.superapp --register-pwa-notification-fixture --open-pwa-notification-fixture` | Opens the approval route with `requestId=approval-42`; it must show a pending state and no approval is performed from push data. |

## Automated Evidence

```bash
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme WebBridgeKitTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro UI Test' \
  -only-testing:WebBridgeKitTests/HTMLAppLaunchRuntimeTests
```

The tests cover exact chat routing, independent task-PWA routing, and the
approval route's navigation-only payload boundary.

## tx Deployment Gate

Do not deploy a local HTTP fixture. After all local checks are green, publish
the two static PWA directories and their unsigned source manifests to `tx`.
The public gateway signs the manifests dynamically, while the same HTTPS origin
serves the PWA files at `https://cloak.xbrowser.dev:5801/fixtures/...`.
Each `startURL`, allowlisted origin, and route must use that exact public
origin. Verify gateway onboarding before physical-phone testing. APNs delivery
remains a separate release gate that requires a Push-capable Apple Developer
Program team and a registered device token.
