# UI v4 Screen Specifications

## Shared layout contract

All primary screens must follow this contract.

| Rule | Requirement |
|---|---|
| Root | SwiftUI view under `SuperApp/Sources/Views/` unless wrapping an existing UIKit/WKWebView controller |
| Horizontal padding | Use `ThemeTokens.Spacing.screenHorizontal` |
| Vertical section gap | Use `ThemeTokens.Spacing.section` or component-specific token |
| Card radius | Use `ThemeTokens.Radius.card` |
| Row height | 52-64 pt for list rows |
| Button height | Minimum 44 pt |
| Tap target | Minimum 44 x 44 pt |
| Text | No negative tracking, no viewport-scaled fonts |
| Colors | `ThemeTokens.Color.*` only |
| Icons | Lucide only |
| Bottom content | Must not be hidden behind tab bar or home indicator |
| Accessibility | Every primary action and field must have an identifier |

## Shared components

These components should exist before page implementation begins.

| Component | Suggested path | Purpose |
|---|---|---|
| `AppShellView` | `SuperApp/Sources/Views/AppShell/AppShellView.swift` | 5-tab shell |
| `ModuleHeaderView` | `SuperApp/Sources/Views/AppShell/ModuleHeaderView.swift` | Title, subtitle, status badge, primary action |
| `ServiceStatusStrip` | `SuperApp/Sources/Views/AppShell/ServiceStatusStrip.swift` | Backend/Test HTTP/Prototype/crash status |
| `StatusBadge` | `SuperApp/Sources/Views/Components/StatusBadge.swift` | Success/warning/error/offline/info badges |
| `MetricTile` | `SuperApp/Sources/Views/Components/MetricTile.swift` | Small numeric metric |
| `ActionRow` | `SuperApp/Sources/Views/Components/ActionRow.swift` | Icon, title, subtitle, trailing control |
| `CodeBlockView` | `SuperApp/Sources/Views/Components/CodeBlockView.swift` | JSON/log/token display |
| `ResultPanel` | `SuperApp/Sources/Views/Components/ResultPanel.swift` | Result, duration, copy/export |
| `EmptyStatePanel` | `SuperApp/Sources/Views/Components/EmptyStatePanel.swift` | Empty/offline/error state |
| `ConfirmDangerSheet` | `SuperApp/Sources/Views/Components/ConfirmDangerSheet.swift` | Cache clear/destructive actions |

Do not create a new component if an existing `WBK*` component already satisfies the contract. Prefer moving shared SwiftUI components into `SuperApp/Sources/Views/Components/`.

## App Shell

Suggested path:

- `SuperApp/Sources/Views/AppShell/AppShellView.swift`
- `SuperApp/Sources/Views/AppShell/AppTab.swift`
- `SuperApp/Sources/Views/AppShell/AppShellViewModel.swift`

Tabs:

| Tab | Accessibility ID | Root view |
|---|---|---|
| Web | `tab.web` | `WebCacheHomeView` |
| Bridge | `tab.bridge` | `BridgeLabHomeView` |
| Token/Push | `tab.tokenPush` | `TokenPushHomeView` |
| Debug | `tab.debug` | `DebugCenterHomeView` |
| Links | `tab.links` | `DeepLinkHomeView` |

States:

- Services healthy
- One service unavailable
- No crash logs
- Crash logs found
- Simulator
- Real device

Acceptance:

- Tab content never overlaps tab bar.
- Selected tab has icon and label color from token.
- All tabs are reachable by XCUITest ID.
- Changing Light/Dark mode does not recreate navigation stack unexpectedly.

## Web Cache Home

Suggested path:

- `SuperApp/Sources/Views/WebCache/WebCacheHomeView.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheHomeViewModel.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheModePicker.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheStatusPanel.swift`
- `SuperApp/Sources/Views/WebCache/WebCacheCleanupSheet.swift`

Existing adapters:

- `SuperApp/Sources/ViewModels/CacheDashboardViewModel.swift`
- `Sources/Cache/`
- `Sources/Handlers/CacheDebug/`
- `Sources/Handlers/ManifestLoader/`
- `Sources/Controllers/WebViewController+CacheDebug.swift`

Primary UI:

- URL input
- Cache mode segmented control:
  - Online
  - Cache First
  - Full Offline
- Open button
- Cache health panel
- Resource count
- Manifest version/status
- Recent pages
- Pinned pages
- Cleanup actions

Accessibility IDs:

| Element | ID |
|---|---|
| URL input | `webCache.urlInput` |
| Cache mode segmented control | `webCache.modePicker` |
| Online mode | `webCache.mode.online` |
| Cache-first mode | `webCache.mode.cacheFirst` |
| Full-offline mode | `webCache.mode.fullOffline` |
| Open button | `webCache.openButton` |
| Cache status panel | `webCache.statusPanel` |
| Clear selected cache | `webCache.clearSelectedButton` |
| Clear all cache | `webCache.clearAllButton` |
| Confirm clear cache | `webCache.confirmClearButton` |
| Recent list | `webCache.recentList` |
| Pinned list | `webCache.pinnedList` |

Required states:

| State | UI expectation |
|---|---|
| Empty | Explain no URL has been opened; show URL input and presets |
| Loading | Show progress and current stage: manifest, resources, open page |
| Online success | Show network source and response time |
| Cache success | Show cache source and version |
| Full offline success | Show offline package source and resource count |
| Offline missing cache | Explain no cached package exists; offer retry online |
| Manifest invalid | Show manifest URL and parse/download error |
| Cleanup success | Show deleted count and remaining size |
| Cleanup failed | Show reason and retry action |

## Web Browser Detail

Suggested path:

- Keep existing UIKit/WKWebView controller wrappers:
  - `Sources/Controllers/WebViewController*.swift`
  - `Sources/Controllers/WebBrowserViewController*.swift`
- Add SwiftUI hosting wrapper only if needed:
  - `SuperApp/Sources/Views/WebCache/WebBrowserContainerView.swift`

Primary UI:

- Web content
- Compact debug overlay toggle
- Cache source badge
- Reload
- Share/copy URL
- Back/forward if applicable

Accessibility IDs:

| Element | ID |
|---|---|
| Web view | `webBrowser.webView` |
| Source badge | `webBrowser.cacheSourceBadge` |
| Reload | `webBrowser.reloadButton` |
| Debug overlay toggle | `webBrowser.debugOverlayButton` |

Required states:

- Loading web page
- Loaded from network
- Loaded from cache
- Loaded from full offline package
- SSL/trust failure
- Network unavailable
- JSBridge injection failure

## Bridge Lab Home

Suggested path:

- `SuperApp/Sources/Views/BridgeLab/BridgeLabHomeView.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeLabViewModel.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeCommandCatalogView.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeCommandFormView.swift`
- `SuperApp/Sources/Views/BridgeLab/BridgeResultPanel.swift`

Existing adapters:

- `Sources/Core/WebJavaScriptBridge.swift`
- `Resources/WebBridge.js`
- `Sources/Handlers/`
- `Sources/Bridge/Error/BridgeError.swift`
- `test_resources/js_bridge_test.html`

Primary UI:

- Handler group list
- Command list
- Parameter editor
- Execute button
- Result JSON
- Duration
- Copy result
- Related logs

Handler groups:

- App
- Cache
- Device
- Interaction
- Media
- Navigation
- Network
- Permission
- System

Accessibility IDs:

| Element | ID |
|---|---|
| Handler group list | `bridge.groupList` |
| Command list | `bridge.commandList` |
| Parameter editor | `bridge.parameterEditor` |
| Execute button | `bridge.executeButton` |
| Result panel | `bridge.resultPanel` |
| Copy result | `bridge.copyResultButton` |
| Open logs | `bridge.openLogsButton` |

Required states:

| State | UI expectation |
|---|---|
| Empty | Ask user to select a handler group |
| Ready | Show command form |
| Running | Disable execute and show elapsed time |
| Success | Show JSON result and duration |
| Bridge error | Show code, message, and recovery |
| Timeout | Show timeout threshold and logs shortcut |
| Permission denied | Show permission name and settings action |
| Invalid params | Mark invalid fields before execution |

## Token/Push Home

Suggested path:

- `SuperApp/Sources/Views/TokenPush/TokenPushHomeView.swift`
- `SuperApp/Sources/Views/TokenPush/TokenPushViewModel.swift`
- `SuperApp/Sources/Views/TokenPush/TokenListView.swift`
- `SuperApp/Sources/Views/TokenPush/PassphraseListView.swift`
- `SuperApp/Sources/Views/TokenPush/PushPayloadComposerView.swift`

Existing adapters:

- `SuperApp/Sources/Managers/TokenManager.swift`
- `SuperApp/Sources/Managers/PassphraseManager.swift`
- `SuperApp/Sources/Managers/APIKeyManager.swift`
- `SuperApp/Sources/Managers/AccessTokenManager.swift`
- `SuperApp/Sources/Push/`
- `SuperApp/Sources/Controllers/Debug/NotificationDebugViewController.swift`

Primary UI:

- Token status summary
- Passphrase summary
- Device token status
- Redacted token list
- Generate token
- Copy token
- Push payload composer
- Send local test push
- Send server push when backend is available

Accessibility IDs:

| Element | ID |
|---|---|
| Token list | `tokenPush.tokenList` |
| Generate token | `tokenPush.generateTokenButton` |
| Passphrase list | `tokenPush.passphraseList` |
| Device token value | `tokenPush.deviceTokenValue` |
| Reveal token toggle | `tokenPush.revealTokenToggle` |
| Payload editor | `tokenPush.payloadEditor` |
| Send local push | `tokenPush.sendLocalPushButton` |
| Send server push | `tokenPush.sendServerPushButton` |
| Result panel | `tokenPush.resultPanel` |

Required states:

- No token
- Token exists and redacted
- Token revealed after explicit action
- Device token unavailable
- Notification permission denied
- Local push success
- Server unavailable
- Server push success
- Payload invalid

## Debug Center Home

Suggested path:

- `SuperApp/Sources/Views/DebugCenter/DebugCenterHomeView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugCenterViewModel.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugLogListView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugNetworkView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugCrashView.swift`
- `SuperApp/Sources/Views/DebugCenter/DebugExportView.swift`

Existing adapters:

- `SuperApp/Sources/Controllers/Debug/DebugPanelViewController.swift`
- `SuperApp/Sources/Controllers/Debug/NetworkDebugViewController.swift`
- `Sources/Infrastructure/Debug/`
- `scripts/scan-crash-logs.sh`

Primary UI:

- Segmented views:
  - Logs
  - Network
  - Cache
  - Crash
  - Environment
  - Export
- Filters
- Search
- Copy selected
- Export JSON
- Redaction status

Accessibility IDs:

| Element | ID |
|---|---|
| Segment control | `debug.segmentControl` |
| Logs tab | `debug.segment.logs` |
| Network tab | `debug.segment.network` |
| Cache tab | `debug.segment.cache` |
| Crash tab | `debug.segment.crash` |
| Environment tab | `debug.segment.environment` |
| Export tab | `debug.segment.export` |
| Log filter | `debug.logFilter` |
| Log list | `debug.logList` |
| Copy logs | `debug.copyLogsButton` |
| Export diagnostics | `debug.exportDiagnosticsButton` |

Required states:

- Logs empty
- Logs available
- Filter returns no results
- Network healthy
- Network unavailable
- Crash count zero
- Crash count non-zero
- Export success
- Export failed

## Deep Link Home

Suggested path:

- `SuperApp/Sources/Views/DeepLink/DeepLinkHomeView.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkViewModel.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkTemplateListView.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkParameterEditor.swift`
- `SuperApp/Sources/Views/DeepLink/DeepLinkHistoryView.swift`

Existing adapters:

- `SuperApp/Sources/AppDelegate.swift`
- `SuperApp/Sources/Managers/CommandHandler.swift`
- `Sources/CommandParser/`
- `Server/Sources/WebBridgeServer/Routes/CommandRoutes.swift`

Primary UI:

- Template list
- Parameter editor
- Generated URL preview
- Execute button
- Copy URL
- History
- Target verification

Templates:

- Open URL
- Open URL with cache mode
- Open page with app ID
- Execute command
- Open debug panel
- Open cache dashboard
- Open bridge lab command

Accessibility IDs:

| Element | ID |
|---|---|
| Template list | `deepLink.templateList` |
| Parameter editor | `deepLink.parameterEditor` |
| URL preview | `deepLink.urlPreview` |
| Execute button | `deepLink.executeButton` |
| Copy URL | `deepLink.copyURLButton` |
| History list | `deepLink.historyList` |
| Result panel | `deepLink.resultPanel` |

Required states:

- No template selected
- Valid URL generated
- Invalid scheme
- Missing required parameter
- Unsupported command
- Open success
- Open failed with reason

## Component quality requirements

### Text

- Titles: one line unless explicitly stated.
- Body: max 3 lines.
- Metadata: one line with truncation.
- JSON/log content: scroll inside `CodeBlockView`, never overflow parent.

### Buttons

- Primary button: one per section.
- Destructive button: never adjacent to primary without confirmation.
- Icon-only button: tooltip/accessibility label required.
- Disabled state: visible and explained if action is blocked.

### Lists

- Rows must not change height when status badge changes.
- Swipe actions are optional; visible actions are preferred for testability.
- Empty state must replace blank lists.

### Forms

- Every input has label, placeholder, validation message, and accessibility ID.
- Validation should happen before executing network/native actions when possible.

### Errors

Errors must show:

- Short human-readable message
- Technical detail in expandable/copyable area
- Recovery action when known

## Screen acceptance checklist

Each screen is complete only when:

- It has all accessibility IDs listed above.
- It has tests for empty/loading/success/error states.
- It has Light/Dark screenshots.
- It works on iPhone SE without clipped text or hidden controls.
- `tools/ci-lint.sh` does not report new design violations.
- It does not introduce new hardcoded colors, SF Symbols, emoji UI, or fixed heights below the tap target minimum.
