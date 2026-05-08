# WebBridgeKit Project

## Services

Three services must be running for testing/verification:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Backend (Swift) | 8080 | http://localhost:8080 | WebBridgeServer - Hummingbird, routes: /health /push /manifest /command |
| Test HTTP | 8081 | http://localhost:8081 | Static file server for cache testing (project root + test_resources/) |
| Prototype | 8083 | http://localhost:8083 | HTML prototype (index.html, v2-current-implementation.html) |

### Management

```bash
bash scripts/services.sh start     # Start all 3 services
bash scripts/services.sh stop      # Stop all services
bash scripts/services.sh restart   # Restart all services
bash scripts/services.sh status    # Show running status
bash scripts/services.sh verify    # Health-check with curl
bash scripts/services.sh logs      # Show recent logs
```

Run `bash scripts/services.sh` without args for full usage.

**IMPORTANT**: Always run `bash scripts/services.sh start` before testing the app in simulator. The backend is required for push notification, command handling, and manifest features to work correctly.

## Build & Run

```bash
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd
```

Install to booted simulator:
```bash
APP=$(find /tmp/wbk-dd -name "SuperApp.app" -maxdepth 5 | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.webbridgekit.superapp
```

## Project Structure

- `Server/` - Swift Hummingbird backend (SPM)
- `Sources/` - WebBridgeKit framework core
- `SuperApp/` - iOS app target
- `docs/prototype/` - HTML design prototypes
- `scripts/` - Utility scripts (services.sh, test_server.py)
- `docs/design-tokens.json` - Single source of truth for design tokens

## i18n

- `SuperApp/Resources/zh-Hans.lproj/Localizable.strings` - Chinese (primary)
- `SuperApp/Resources/en.lproj/Localizable.strings` - English
- `Sources/Utils/L10n.swift` - Localization helper with multi-bundle fallback

## CI

- `.github/workflows/ci.yml` - 14 jobs, Smoke Tests may need retry
- Check: `gh run list --limit 5`
