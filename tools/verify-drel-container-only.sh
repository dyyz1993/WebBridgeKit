#!/usr/bin/env bash
# Guards the first Drel Store release boundary: a trusted web container, no JS bridge.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0

check() {
    local name="$1"
    local command="$2"
    if bash -lc "$command"; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $name" >&2
        exit 1
    fi
}

check "Release defines the fixed Store policy" \
    "test \"$(rg -c 'SWIFT_ACTIVE_COMPILATION_CONDITIONS: DREL_CONTAINER_ONLY' project.yml)\" -ge 2"
check "Policy is compile-time fixed" \
    "rg -q '#if DREL_CONTAINER_ONLY' Sources/Runtime/DrelContainerBuildPolicy.swift"
check "Default browser path gates bridge injection" \
    "rg -q 'if DrelContainerBuildPolicy\\.nativeBridgeEnabled' Sources/ViewModels/WebBrowserViewModel.swift"
check "Legacy browser path gates bridge injection" \
    "rg -q 'guard DrelContainerBuildPolicy\\.nativeBridgeEnabled else' Sources/Controllers/WebViewController\\+Delegates.swift"
check "Pooled browser is unavailable in Store builds" \
    "rg -q 'if DrelContainerBuildPolicy\\.nativeBridgeEnabled' Sources/Controllers/WebViewController.swift"
check "Store build excludes the Cache debug control" \
    "rg -U -q '#if !DREL_CONTAINER_ONLY[[:space:][:print:]]*setupCacheDebugButton\\(\\)[[:space:][:print:]]*#endif' Sources/Controllers/WebViewController.swift"
check "Managed launch injection is unavailable in Store builds" \
    "rg -q 'guard DrelContainerBuildPolicy\\.nativeBridgeEnabled else' Sources/Controllers/WebBrowserViewController.swift"
check "Immersive menu hides app settings in Store builds and favorites share the capsule entry URL" \
    "rg -q 'managedHTMLAppID != nil, DrelContainerBuildPolicy\\.nativeBridgeEnabled' Sources/Controllers/WebBrowserViewController\\+Menu.swift && rg -q 'toggleImmersiveFavorite' Sources/Controllers/WebBrowserViewController\\+Menu.swift && ! rg -q 'favoriteService\\.addFavorite' Sources/Controllers/WebBrowserViewController\\+Menu.swift"
check "Push route uses URL context in Store builds" \
    "rg -q 'target\\.containerOnlyURL' SuperApp/Sources/Push/PushRouter.swift"
check "Push URLs use the shared message presentation policy and bypass the HTML-app manifest loader" \
    "rg -q 'DrelMessageOpenPolicy\\.browserParams' SuperApp/Sources/Push/PushRouter.swift && rg -U -q 'DrelMessageOpenPolicy\\.browserParams\\([[:space:][:print:]]*for: url,[[:space:][:print:]]*mode: mode,[[:space:][:print:]]*useManifestLoader: false' SuperApp/Sources/Push/PushRouter.swift"
check "Inbox and detail links preserve the same message presentation policy" \
    "test \"\$(rg -c 'DrelMessageOpenPolicy\\.browserParams' SuperApp/Sources/Controllers/Message/MessageInboxViewController.swift)\" -ge 3 && test \"\$(( \$(rg -c 'DrelMessageOpenPolicy\\.browserParams' SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift || echo 0) + \$(rg -c 'DrelMessageOpenPolicy\\.browserParams' SuperApp/Sources/Controllers/Message/MessageDetailViewController+WebViewNavigation.swift || echo 0) ))\" -ge 4 && rg -q 'MessageTargetPresentation\\.resolve' SuperApp/Sources/Push/PushPayload.swift && rg -q 'MessageTargetPresentation\\.canonicalMode' Sources/Message/NotificationPayloadMapper.swift"
check "Recent plain-web session restore bypasses the manifest loader" \
    "rg -U -q 'restorableLastURL\\(\\)[[:space:][:print:]]*WebBrowserParams\\(useManifestLoader: false\\)' SuperApp/Sources/AppDelegate.swift"
check "Drel receives URL pushes without auto-navigation" \
    "rg -U -q '#if !DREL_CONTAINER_ONLY[[:space:][:print:]]*await engine.setOnRoute' SuperApp/Sources/Managers/EngineBootstrap.swift && rg -q 'await engine.setOnRoute\\(nil\\)' SuperApp/Sources/Managers/EngineBootstrap.swift"
check "Notification cold launches suppress stale session restore" \
    "rg -U -q 'DrelStartupNavigationPolicy\\.shouldRestoreRecentSession[\\s\\S]*launchedFromRemoteNotification: launchOptions\\?\\[\\.remoteNotification\\] != nil' SuperApp/Sources/AppDelegate.swift"
check "Default startup apps suppress delayed normal-mode session restore" \
    "rg -U -q 'DrelStartupNavigationPolicy\\.shouldRestoreRecentSession[\\s\\S]*hasDefaultStartupApp: !defaultStartupAppID\\.isEmpty' SuperApp/Sources/AppDelegate.swift && rg -U -q '&& !hasDefaultStartupApp' Sources/Runtime/DrelContainerBuildPolicy.swift"
check "Store URL context is regression-tested" \
    "rg -q 'containerOnlyURL' Tests/ModelsTests/HTMLAppLaunchRuntimeTests.swift"
check "Store-visible push host uses the Drel API domain" \
    "rg -q 'https://api.drel.app' SuperApp/Sources/Views/TokenPush/TokenPushHomeViewModel.swift && rg -q 'urlLabel.text = \"api.drel.app\"' SuperApp/Sources/Controllers/ComponentCatalog/TokenCardSection.swift"
check "Store push examples use official public hosts" \
    "rg -q 'value: \"https://drel.app/\"' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && test \"$(rg -c 'https://drel.app/assets/drel-message-avatar.png' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift)\" -ge 3 && ! rg -q 'shanbox\\.19930810\\.xyz' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift"
check "Store custom icon is an in-app avatar, not a system icon override" \
    "rg -q '系统通知保持 Drel 图标' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -q 'case let \\.customIcon' SuperApp/Sources/Views/PWAHome/NotificationMockBanner.swift && rg -F -q 'clipShape(Circle())' SuperApp/Sources/Views/PWAHome/NotificationMockBanner.swift && rg -F -q 'iconContainer.layer.cornerRadius = iconContainer.bounds.height / 2' SuperApp/Sources/Controllers/Tab/InboxViewController+Cells.swift && rg -q 'message.payload.iconURL' SuperApp/Sources/Controllers/Tab/InboxViewController+Cells.swift && ! rg -q '替换通知左侧图标' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift"
check "Image attachments support explicit add-only saving" \
    "rg -q 'authorizationStatus\\(for: \\.addOnly\\)' SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift && rg -q 'requestAuthorization\\(for: \\.addOnly\\)' SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift && rg -q 'UIApplication.openSettingsURLString' SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift && rg -q 'onSaveMenuRequested' SuperApp/Sources/Controllers/Message/MessageMediaCardView.swift && rg -q 'INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription' project.yml"
check "URL example supports opt-in immersive fullscreen routing" \
    "rg -q 'pushExamples.url.fullscreen' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -F -q 'URLQueryItem(name: \"mode\", value: \"immersive\")' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -q 'case \.immersive' SuperApp/Sources/Push/PushPayload.swift"
check "Store catalog uses Safari send and copy icons with an explicit parameter line" \
    "rg -q 'openPushExampleInSafari' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift && rg -q 'copyPushExampleURL' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift && rg -F -q 'icon: .send' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -F -q 'icon: .copy' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -F -q '.send' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -F -q '.copy' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -F -q '无额外 URL 参数' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && ! rg -F -q '应用内测试' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift"
check "Store push catalog retains core V1 examples only" \
    "rg -U -q '\"bodyOnly\", \"plain\", \"markdown\", \"otp\", \"qr\", \"image\",[[:space:]]*\"sound\", \"icon\", \"group\", \"timeSensitive\", \"badge\", \"badgeClear\", \"subtitle\",[[:space:]]*\"url\", \"copyManual\", \"copy\", \"archive\", \"replace\", \"recall\"' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift"
check "Store catalog excludes deferred chat, approval, critical and call examples" \
    "rg -q 'managed HTML-app chat/approval routes' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && rg -q '#if DREL_CONTAINER_ONLY' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift && ! rg -U -q 'releaseExampleIDs:[[:space:]]*Set<String>[[:space:]]*=[[:space:]]*\\[[^]]*\"(chat|approval|critical|call)\"' SuperApp/Sources/Views/PWAHome/PushExampleCatalogView.swift"
check "Push-address rotation revokes the exact server registration first" \
    "rg -q 'router\.post\(\"/unregister\"' Server/Sources/WebBridgeServer/Routes/PushRoutes.swift && rg -q 'func unregister\(token: String, key: String\)' Server/Sources/WebBridgeServer/Services/TokenStore.swift && rg -U -q 'revokeOfficialPush\([[:space:][:print:]]*case \.success:[[:space:][:print:]]*replaceLocalIdentity\(\)' SuperApp/Sources/Controllers/Settings/PWAAppCenterViewController.swift"
check "Server and app agree on the native notification copy category" \
    "rg -q 'aps\[\"category\"\] = \"DREL_COPY\"' Server/Sources/WebBridgeServer/Services/APNsService.swift && rg -q 'copyNotificationCategoryIdentifier = \"DREL_COPY\"' SuperApp/Sources/AppDelegate.swift"
check "Simulator fixture detects every forbidden global" \
    "rg -q 'messageHandlers\\.barkBridge' test_resources/drel-container-only-check.html"
check "Store build excludes seeded demo messages" \
    "rg -q '#if !DREL_CONTAINER_ONLY' SuperApp/Sources/Managers/TestDataSeeder.swift && rg -q '#if !DREL_CONTAINER_ONLY' SuperApp/Sources/Managers/TestDataSeeder+Entities.swift && rg -B 2 -A 2 'TestDataSeeder.populateIfNeeded' SuperApp/Sources/AppDelegate.swift | rg -q '#if !DREL_CONTAINER_ONLY'"
check "Store Inbox exposes confirmed clear-all" \
    "rg -q 'inboxActionsButton.menu = UIMenu' SuperApp/Sources/Controllers/Tab/InboxViewController.swift && rg -q 'clearAllMessagesRelay.accept' SuperApp/Sources/Controllers/Tab/InboxViewController.swift && rg -q 'MessageEngine.shared.clearAllMessages' SuperApp/Sources/ViewModels/InboxViewModel.swift && rg -q 'removeAllDeliveredNotifications' SuperApp/Sources/ViewModels/InboxViewModel.swift && rg -F -q 'DefaultBadgeManager().setBadge(0)' SuperApp/Sources/ViewModels/InboxViewModel.swift"
check "Store build excludes Bridge permission UI" \
    "rg -q '#if !DREL_CONTAINER_ONLY' SuperApp/Sources/Controllers/Settings/PWAPermissionCenterViewController.swift && rg -q '#if !DREL_CONTAINER_ONLY' SuperApp/Sources/Views/Settings/WebOriginGrantsView.swift"
check "Store build excludes legacy command and arbitrary URL entry points" \
    "rg -q '#if !DREL_CONTAINER_ONLY' SuperApp/Sources/AppDelegate.swift && rg -q 'Drel 1.0 intentionally has no other external command/deep-link surface' SuperApp/Sources/AppDelegate.swift && rg -q 'Fail closed: only apps already trusted' SuperApp/Sources/Utilities/DrelExternalAppLinkOpener.swift && ! rg -q 'webbridgekit://open?url' Sources/Runtime/DrelExternalAppLink.swift"
check "Component catalog is unavailable in Store builds" \
    "rg -B 2 -A 1 'show-component-catalog' SuperApp/Sources/AppDelegate.swift | rg -q '#if !DREL_CONTAINER_ONLY'"
check "Store build retains required SDK privacy prompts" \
    "rg -q 'Retain Required SDK Privacy Prompts for Store Build' project.yml && rg -q 'NSContactsUsageDescription' SuperApp/Sources/Info.plist"
check "Self-hosted launch refresh never falls back to the official push service" \
    "rg -U -q 'if let selfHosted = SelfHostedPushConfiguration\.load\(\)[[:space:][:print:]]*PushNotificationManager\.shared\.activateSelfHostedPush' SuperApp/Sources/AppDelegate.swift && rg -q 'return' SuperApp/Sources/AppDelegate.swift"
check "Self-hosted descriptor endpoints remain relative to their selected HTTPS origin" \
    "rg -q 'static func validatedEndpointPath' SuperApp/Sources/Services/SelfHostedPushConfiguration.swift && rg -q 'components.host == nil' SuperApp/Sources/Services/SelfHostedPushConfiguration.swift && rg -q 'static func endpointURL' SuperApp/Sources/Services/SelfHostedPushConfiguration.swift && rg -q 'endpointURL' SuperApp/Sources/Push/PushNotificationManager.swift"
check "Removing a self-hosted server discards its local decryption identity" \
    "rg -q 'func discardIdentity' Sources/Message/SelfHostedPushCrypto.swift && rg -q 'SelfHostedPushCrypto\.discardIdentity\(\)' SuperApp/Sources/Controllers/Settings/SelfHostedPushConfigurationViewController.swift"
check "Legacy registration cannot enroll a self-hosted decrypting recipient" \
    "rg -q 'Self-hosted encrypted registrations must use /self-hosted/register' Server/Sources/WebBridgeServer/Routes/PushRoutes.swift"
check "Self-hosted pairing tickets are bounded and test pushes never log plaintext" \
    "rg -q 'maxTickets' Server/Sources/WebBridgeServer/Services/SelfHostedPairingStore.swift && ! rg -q 'TEST ENDPOINT - Received push payload' Server/Sources/WebBridgeServer/Routes/PushRoutes.swift"
check "Self-hosted sender-side envelopes never expose plaintext to the relay or APNs" \
    "rg -q 'self-hosted/recipients/:deviceKey' Server/Sources/WebBridgeServer/Routes/SelfHostedPushRoutes.swift && rg -q 'validatePassthroughEnvelope' Server/Sources/WebBridgeServer/Services/APNsService.swift && rg -q 'pre-encrypted sender envelope strips every plaintext wrapper before APNs' Server/Tests/WebBridgeServerTests/SelfHostedPushRoutesTests.swift && test -x Server/examples/drel-encrypt-and-push.mjs"
check "Self-hosted pairing proves health and APNs readiness before creating or rotating a device identity" \
    "rg -q 'validateSelfHostedHealth' SuperApp/Sources/Push/PushNotificationManager.swift && rg -q 'health\.apnsReady != false' SuperApp/Sources/Push/PushNotificationManager.swift && rg -q 'requiresSelfHostedAPNs' Server/Sources/WebBridgeServer/entrypoint.swift && rg -q 'var isReady: Bool' Server/Sources/WebBridgeServer/Services/APNsService.swift"

echo "Summary: $PASS passed, 0 failed"
