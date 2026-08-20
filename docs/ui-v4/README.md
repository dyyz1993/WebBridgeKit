# WebBridgeKit UI v4 Refactor Plan

This folder is the source of truth for the next UI refactor round.

The goal is not to make the current tabs prettier. The goal is to rebuild the app around the real product capabilities:

- Web cache: online, offline cache, full offline package, cache cleanup, cache diagnostics
- JSBridge: command execution, callback inspection, handler coverage, error visibility
- Token and passphrase: token generation, passphrase management, copy/export, redaction
- Push: local payload testing, APNs/device token visibility, push routing
- Debug center: logs, network, cache stats, crash logs, environment, diagnostics export
- Deep link: scheme routing, URL parameters, command URLs, target page opening

## Documents

| Document | Purpose |
|---|---|
| [INFORMATION_ARCHITECTURE.md](INFORMATION_ARCHITECTURE.md) | Product navigation, module ownership, user journeys |
| [SCREEN_SPECS.md](SCREEN_SPECS.md) | Page-by-page UI specification with states and accessibility IDs |
| [AUTOMATION_MATRIX.md](AUTOMATION_MATRIX.md) | Automated, semi-automated, and manual test cases |
| [AGENT_TASKS.md](AGENT_TASKS.md) | Executable task list for agents with paths and acceptance criteria |

## Non-negotiable rules

1. Keep `docs/design-tokens.json` as the design-token source of truth.
2. Use `ThemeTokens.Color.*` for all feature UI colors.
3. Use Lucide icons only.
4. Keep WKWebView, cache, bridge, push, token, and command core code stable unless a screen requires a thin adapter.
5. Prefer SwiftUI for new app-level screens. Keep UIKit where it wraps WKWebView or existing complex controllers.
6. Every new interactive element must have an accessibility identifier.
7. Every page must define empty, loading, success, error, offline, and permission-denied states where applicable.
8. Every page must pass iPhone SE, iPhone 16 Pro, Light Mode, and Dark Mode layout checks.
9. No page can ship without UI tests or a documented manual-only reason.
10. Any new flow must be runnable from a single script or CI job.

## Recommended implementation shape

```text
SuperApp/Sources/Views/AppShell/
SuperApp/Sources/Views/WebCache/
SuperApp/Sources/Views/BridgeLab/
SuperApp/Sources/Views/TokenPush/
SuperApp/Sources/Views/DebugCenter/
SuperApp/Sources/Views/DeepLink/
SuperAppUITests/
tools/
docs/ui-v4/
```

## Existing code to preserve

| Capability | Existing paths |
|---|---|
| Cache core | `Sources/Cache/`, `Sources/Handlers/CacheDebug/`, `Sources/Handlers/ManifestLoader/` |
| JSBridge core | `Sources/Core/WebJavaScriptBridge.swift`, `Resources/WebBridge.js`, `Sources/Handlers/` |
| WebView shell | `Sources/Controllers/WebViewController*`, `Sources/Controllers/WebBrowserViewController*` |
| Token/passphrase | `SuperApp/Sources/Managers/TokenManager.swift`, `SuperApp/Sources/Managers/PassphraseManager.swift` |
| Push | `SuperApp/Sources/Push/`, `Server/Sources/WebBridgeServer/Routes/PushRoutes.swift` |
| Debug | `SuperApp/Sources/Controllers/Debug/`, `Sources/Infrastructure/Debug/` |
| Deep link/command | `SuperApp/Sources/AppDelegate.swift`, `SuperApp/Sources/Managers/CommandHandler.swift`, `Sources/CommandParser/` |
| Tokens/icons | `docs/design-tokens.json`, `Sources/Theme/ThemeTokens.swift`, `Sources/Theme/Lucide*.swift` |

## Definition of done

The UI v4 refactor is done only when:

- `bash scripts/services.sh verify` passes.
- `bash tools/ci-lint.sh` passes.
- `bash tools/run-ui-v4-regression.sh` passes.
- Cache, JSBridge, Token/Push, Debug, and Deep Link flows have UI tests.
- Light/Dark screenshots exist for all primary pages.
- iPhone SE screenshots show no truncation, overlap, clipped buttons, or hidden bottom content.
- `bash scripts/scan-crash-logs.sh --json` returns `total: 0`.
- Release build contains no test HTML and no debug-only UI unless behind a debug flag.
