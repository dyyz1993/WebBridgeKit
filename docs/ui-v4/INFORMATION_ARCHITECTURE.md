# UI v4 Information Architecture

## Product model

WebBridgeKit SuperApp is a capability console for a hybrid iOS framework. The UI should expose the framework capabilities directly instead of hiding them inside generic consumer-app tabs.

The app should answer five questions quickly:

1. Can I open and cache a web page?
2. Can I prove the page works offline?
3. Can I call native APIs from JavaScript and inspect the result?
4. Can I test token, command, push, and deep-link routing?
5. Can I diagnose failures without reading Xcode logs first?

## Proposed navigation

Use a stable 5-tab app shell.

| Tab | Label | Icon intent | Primary user |
|---|---|---|---|
| 1 | Web | Browser/cache icon | Developer testing web cache and offline behavior |
| 2 | Bridge | Terminal/plug icon | Developer testing JSBridge handlers |
| 3 | Token/Push | Key/bell icon | Developer testing credentials, passphrases, and push |
| 4 | Debug | Activity/log icon | Developer diagnosing runtime state |
| 5 | Links | Link/route icon | Developer testing scheme URLs and command routing |

Do not use the old generic information architecture as the long-term shell:

- Home
- Inbox
- Discover
- Settings

Those labels hide the actual product and make test paths ambiguous.

## Module ownership

### Web

Owns:

- URL input
- Online open
- Cache policy selection
- Offline cache status
- Full offline package status
- Manifest status
- Cache cleanup
- Cache stats
- Recent page history
- Pinned URLs

Existing code:

- `SuperApp/Sources/Views/CacheDashboardView.swift`
- `SuperApp/Sources/ViewModels/CacheDashboardViewModel.swift`
- `SuperApp/Sources/Controllers/Cache/`
- `Sources/Cache/`
- `Sources/Handlers/CacheDebug/`
- `Sources/Handlers/ManifestLoader/`
- `Sources/Controllers/WebViewController+CacheDebug.swift`

### Bridge

Owns:

- Handler catalog
- JS command composer
- Parameter editor
- Execute button
- Native callback result
- Error result
- Timeout result
- Permission-dependent handler status
- Bridge console

Existing code:

- `Sources/Core/WebJavaScriptBridge.swift`
- `Resources/WebBridge.js`
- `Sources/Handlers/`
- `Sources/Bridge/Error/BridgeError.swift`
- `SuperApp/Sources/Controllers/Showcase/BridgeShowcaseViewController.swift`
- `test_resources/js_bridge_test.html`

### Token/Push

Owns:

- Access token list
- Passphrase list
- API key management
- Device token visibility
- Push payload preview
- Local push simulation
- Push route result
- Redacted copy/export

Existing code:

- `SuperApp/Sources/Managers/TokenManager.swift`
- `SuperApp/Sources/Managers/PassphraseManager.swift`
- `SuperApp/Sources/Managers/APIKeyManager.swift`
- `SuperApp/Sources/Managers/AccessTokenManager.swift`
- `SuperApp/Sources/Push/`
- `SuperApp/Sources/Controllers/Settings/TokenManageViewController.swift`
- `SuperApp/Sources/Controllers/Settings/TokenGenerateViewController.swift`
- `SuperApp/Sources/Controllers/Debug/NotificationDebugViewController.swift`
- `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift`

### Debug

Owns:

- Structured logs
- Command history
- Network status
- Cache status
- Crash log status
- Environment
- Permissions
- Diagnostic export

Existing code:

- `SuperApp/Sources/Controllers/Debug/DebugPanelViewController.swift`
- `SuperApp/Sources/Controllers/Debug/NetworkDebugViewController.swift`
- `SuperApp/Sources/Controllers/Debug/ManifestCacheTestViewController.swift`
- `Sources/Infrastructure/Debug/`
- `scripts/scan-crash-logs.sh`

### Links

Owns:

- Deep-link template catalog
- `webbridgekit://open`
- `webbridgekit://command/...`
- Query parameter editor
- Last execution result
- Target page verification
- Invalid URL diagnostics

Existing code:

- `SuperApp/Sources/AppDelegate.swift`
- `SuperApp/Sources/Managers/CommandHandler.swift`
- `Sources/CommandParser/`
- `Server/Sources/WebBridgeServer/Routes/CommandRoutes.swift`
- `Server/Sources/WebBridgeServer/Services/CommandService.swift`

## App shell behavior

### Global top area

Each tab gets a compact header:

- Title
- One-line status subtitle
- Environment badge: local, simulator, device, offline, service unavailable
- Primary action on the right when applicable

Do not use oversized marketing headers.

### Global status strip

Use a small persistent status strip on developer builds:

- Backend: healthy/unavailable
- Test HTTP: healthy/unavailable
- Prototype: healthy/unavailable
- Crash logs: 0/non-zero

The strip should be compact and non-blocking. It must not overlap tab content.

### Navigation depth

Use no more than 2 levels for primary flows:

```text
Tab -> Primary screen -> Detail/test result screen
```

Avoid deep chains such as:

```text
Settings -> Debug -> Cache -> Manifest -> Resource -> Log -> Detail
```

## User journeys

### Journey A: prove a page works offline

1. Open Web tab.
2. Enter or select a URL.
3. Choose cache mode: online, cache-first, full offline.
4. Open the page.
5. Confirm manifest/resource count.
6. Turn network offline or simulate offline.
7. Reopen the page.
8. Confirm page loads from cache.
9. Clear cache and confirm offline load fails with a useful error.

Success criteria:

- User can see whether content came from network, cache, or offline package.
- Cache clear action has confirmation and final state.
- Failure state explains the missing resource or manifest reason.

### Journey B: test one JSBridge command

1. Open Bridge tab.
2. Pick handler group.
3. Pick command.
4. Fill parameters.
5. Execute.
6. Inspect result JSON, duration, and logs.
7. Copy result.

Success criteria:

- Invalid params fail before execution when possible.
- Timeout has clear UI and log entry.
- Permission-required commands show permission state before execution.

### Journey C: test push routing

1. Open Token/Push tab.
2. Confirm device token or local mock token state.
3. Compose payload.
4. Send local push simulation or server push.
5. Confirm route target and UI result.

Success criteria:

- APNs-only steps are marked as device/manual.
- Local payload parsing is fully automated.
- Sensitive token values are redacted by default.

### Journey D: diagnose a broken command

1. Open Debug tab.
2. Filter logs by `handler`, `cache`, `network`, or `command`.
3. Open failed log detail.
4. Copy/export diagnostic package.

Success criteria:

- User does not need Xcode for first-line diagnosis.
- Diagnostic export redacts credentials.

### Journey E: open a concrete page via protocol URL

1. Open Links tab.
2. Pick `open page` template.
3. Fill URL and parameters.
4. Execute.
5. Confirm target page and parsed parameters.

Success criteria:

- Invalid scheme/path/query is shown inline.
- Last 10 executions are visible.

## State model

Every primary module should expose one screen state enum:

```swift
enum ModuleScreenState {
    case idle
    case loading
    case ready
    case empty
    case offline
    case permissionDenied
    case failed(message: String, recovery: String?)
}
```

Each screen must render all states. Tests should be able to inject states without relying on live services.

## Visual direction

The product should feel like a calm developer console:

- Dense enough for repeated testing
- Clear enough for non-iOS engineers
- No decorative hero sections
- No nested cards
- No visual noise from arbitrary gradients
- Strong status labels and result panes
- Monospace only for code, JSON, tokens, URLs, and log payloads

## Migration principle

Do not rewrite core framework modules during the UI refactor unless a bug is proven. The UI v4 migration should create thin adapters around existing managers, handlers, and controllers.
