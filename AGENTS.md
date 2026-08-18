# WebBridgeKit Project

## Deliverable Boundaries

This repository ships three distinct deliverables. Keep their responsibilities
separate in source, documentation, and verification:

- `Sources/` is the reusable WebBridgeKit SDK. It owns generic runtime models,
  protocols, services, security, routing, cache, message, and Bridge behavior.
- `AppTemplate/` is a safe minimal starter for developers building another host
  app. It may demonstrate stable public SDK APIs, but it must not copy SuperApp
  product screens, contain credentials, auto-start local servers, or expose a
  showcase-heavy primary navigation.
- `SuperApp/` is the complete WebBridgeKit product App. It owns end-user
  journeys, product copy, navigation, Inbox, App Center, settings, and the
  official-hosted/self-hosted experience.
- `Server/` and `docs/api/` own shared gateway, push, approval, and callback
  contracts. AppTemplate is not the self-hosted client.

Before adding a reusable feature, prove the contract in `Sources/` or `Server/`,
then complete the product journey in `SuperApp/`. Update AppTemplate only after
the public API is stable and only with the minimum integration example. Run
`bash tools/verify-deliverable-boundaries.sh` after boundary-related changes,
`bash tools/run-template-gate.sh` for AppTemplate, and keep the SuperApp release
gate independent.

## Open Gateway Configuration

WebBridgeKit is an open-source HTML app runtime. Users must be able to add or
switch a compatible gateway without rebuilding the app. The host app must offer
both QR-code import and paste-based import for gateway configuration.

- The portable onboarding payload is a JSON document or `webbridgekit://gateway`
  URL containing the gateway base URL, health endpoint, manifest endpoint,
  display name, and production Ed25519 public-key identifier plus public key.
  Never put APNs device tokens, API secrets, or private keys in a QR payload.
- Validate every imported endpoint before saving it. Production gateways require
  exact HTTPS origins; local HTTP endpoints are development-only and must never
  be silently accepted in a release build.
- Fetch and validate the health endpoint and every returned HTML app manifest,
  then show a native confirmation screen. Persist and activate the gateway only
  after the user confirms the successful validation report.
- Store gateway settings separately from per-HTML-app manifests and permission
  grants. Changing a gateway must not carry over trust or capability grants to a
  different app identity.
- Show the imported host and endpoints for explicit user confirmation. Users can
  edit, switch, or remove a configured gateway at any time.
- Verify the configured gateway locally first. Deploy to shanbox only after the
  server exposes the generic gateway contract and local/simulator regression is
  green.

## Bark Reference Implementation

A local checkout of the open-source Bark app lives at
`/Users/xuyingzhou/Project/temporary/Bark/Bark/`. WebBridgeKit's
Bark-compatible push surface is modeled on it — when push behavior, sound
handling, or example-UX questions come up, consult this source first instead
of guessing.

Key references:

- `Controller/HomeViewModel.swift` — `previews: [PreviewModel]` defines the
  API example cards (title / description / `queryParameter` / preview image /
  `moreInfo` link) that our capability catalog mirrors.
- `Controller/SoundsViewModel.swift` + `SoundFileStorage` — ringtone
  library: default sounds come from `Bundle.main` caf files; user imports
  land in Library/Sounds (Bark uses its app-group container because it
  keeps a real notification extension; we copy into the main container).
- `Sounds/` — 32 alert tones at the app bundle root (AAC-in-CAF in the
  repo; Apple's originals are Int16 PCM and can be re-extracted from the
  local simulator runtime volume
  `/Library/Developer/CoreSimulator/Volumes/iOS_*/…/RuntimeRoot/System/Library/Audio/UISounds{,/New}`).
  Push sound names are sent extensionless (`sound=alarm`).
- `notificationContentExtension/` — a real content-extension target that
  renders rich banners; ours is still dead code
  (`NotificationServiceExtension/` is not in any target).
- `Bark/Intents/` — Siri shortcut intents for sending pushes.
- `kBarkSoundPrefix` ("bark.sounds.30s", `Common/SharedDefines.swift`) —
  Bark synthesizes 30-second looped versions of each sound so `call=1`
  keeps ringing like a phone call.

## APNs Push Delivery Rules (shanbox WebBridgeServer)

Learned the hard way on 2026-08-15: the server answered `{"code":200,"Push sent"}` for weeks
while Apple silently rejected every request. Rules that must not regress:

- **APNs only speaks HTTP/2.** The AsyncHTTPClient version pinned on shanbox has no HTTP/2
  support, so `APNsService` sends via `URLSession` (libcurl-backed, negotiates h2 via ALPN).
  Do not "simplify" this back to `HTTPClient` — HTTP/1.1 requests get `403` with no visible
  route error.
- **Provider JWT (ES256) must be cached and reused.** Sign once, cache ~50 minutes (Apple
  honors ≤1h), re-sign only on expiry. Signing per push triggers `429
  TooManyProviderTokenUpdates`; the penalty survives 10 minutes of cooldown and needs
  ~25 minutes of total silence (no pushes, no direct curl) to clear. Debugging curls that
  mint fresh tokens count against the same key.
- **`Push sent (200)` only means the route accepted the request.** Real delivery failures
  print `APNs error: <code>` / `APNs send error:` to stdout, which is block-buffered under
  supervisord — check `/var/log/supervisor/webbridgeserver.log` and expect flush delay.
- **Isolating faults:** sign the JWT locally (python + cryptography, ES256 raw r||s) and
  `curl --http2 https://api.sandbox.push.apple.com/3/device/<token>` with the real device
  token. A fake token should return `400 BadDeviceToken` (auth OK); `403` means the
  credentials/JWT are wrong; no response line in the server log means the request never
  left correctly.
- **Device registrations persist** to `Server/data/device-registrations.json` (created on
  first register). Restarting the server is safe; losing the file means every phone must
  re-activate push. 2026-08-19: shanbox now runs `APNS_ENVIRONMENT=production`
  (supervisord.conf) because the daily-driver phone installed the TestFlight build, whose
  tokens are production-only — sandbox tokens sent to the production endpoint (and vice
  versa) fail with `400 BadDeviceToken`. All 11 stale sandbox tokens were pruned from the
  registrations file (backup `device-registrations.json.bak-sandbox-cleanup`); note two
  supervisord.conf backups (`.wbk-*-backup-*`) still carry the old sandbox value and would
  regress the endpoint if restored. If a dev-signed build is ever reinstalled on a test
  phone, its sandbox token will 400 against production — flip the env or add a per-token
  strategy before mixing fleets again.
- **Named push sounds require `UIBackgroundModes: remote-notification`** (set via
  `INFOPLIST_KEY_UIBackgroundModes` in project.yml, mirroring Bark). Without it,
  background/killed-app delivery silently falls back to the default alert tone for EVERY
  named sound — no error anywhere, Apple returns 200, and the files are fine
  (verified byte-identical to Bark's). Learned 2026-08-16 after exhausting file formats
  (PCM/AAC/IMA4, mono/stereo), payload minimization, and direct-to-Apple curls; a
  minimal payload still failed until the background mode landed, then everything worked.
  (Later refined 2026-08-17: the background mode was necessary but not sufficient —
  the final root cause of the remaining fallbacks was the missing `.caf` extension
  in the sound name; see the tracing table below.)
  Foreground delivery dodges this via `PushAlertSoundPlayer` (AVAudioPlayer), which is
  why foreground tests can pass while system-path sounds are broken.
- Sound files: ship Bark's original `Sounds/*.caf` byte-identical; do NOT transcode —
  hand-transcoded variants (mono IMA4, PCM) failed on device even though `afinfo`
  showed valid formats.
- **Inbox recording semantics (iOS):** a push is stored only when it arrives while the app
  is foreground (`willPresent`) or the user taps the banner (`didReceive`). Background
  delivery without a tap is lost to the Inbox until the `/ws/stream` SSE relay exists on
  the Swift backend (currently 404). Design UI tests accordingly: return the app to the
  foreground before the push is expected to land.
- **China-region iPhones gate every fresh install** behind a「允许使用无线数据」dialog that
  silently kills all app traffic. Real-device UI tests must auto-tap
  「无线局域网与蜂窝网络」(see `RealDevicePushSmokeTests` alert handling); the test runner
  process has its own copy of the same dialog.

### Push Sound Tracing (三层日志追踪规范)

When a push arrives but plays the wrong/default tone, do NOT guess — trace all three
layers and diff against expectation. The notification sound on background/killed-app
delivery is chosen by **SpringBoard** (the app executes zero code), so only system logs
reveal the decision.

**Layer 1 — server send log** (proves what Apple received):

```bash
ssh shanbox-jump "grep -a '\[APNs\] sending' /var/log/supervisor/webbridgeserver-error.log | tail -5"
# → "[APNs] sending token=…d06e69 title=X sound=alarm level=nil"
```

**Layer 2 — device arrival & presentation verdict** (USB connection required):

```bash
nohup timeout 60 idevicesyslog > /tmp/syslog.txt 2>/dev/null &
# ...send a push, wait ~10s, then:
grep -a "sirens" /tmp/syslog.txt | grep -a webbridgekit
```

**Layer 3 — the exact file the speaker played**:

```bash
grep -a "soundFileURL" /tmp/syslog.txt | grep -aoE "file://[^;]*caf" | sort -u
```

**Signature lines and what they mean:**

| Log line | Meaning |
|---|---|
| `lights and sirens YES … DID play` | System presented with sound |
| `lights and sirens NO` (rapid pushes) | **Coalescing suppression** — stacked notifications are silenced; clear Notification Center before testing |
| `soundFileURL = file://…/<name>.caf` (container path) | Named sound resolved and played — the goal |
| `soundFileURL = …/ToneLibrary/…Rebound.caf` + `toneIdentifier = "texttone:Rebound"` | Named sound IGNORED; system default text tone played |
| `Falling back to default due missing setting in Preferences` + `correspondingToneIdentifier:((null))` | ToneLibrary could not map the payload sound to a tone and no per-app preference exists → default. On iOS 18.7.3 dev-signed/sandbox builds this fires deterministically for every named sound (2026-08-17 verdict, all formats/payloads/installs exhausted); production-signed apps (App Store Bark) are the control — if they play named tones, TestFlight distribution is the fix. **RESOLVED 2026-08-19: confirmed on a TestFlight (production-signed) build, phone locked, direct-to-Apple curl — SpringBoard played the named alarm tone correctly. Two rules are final: (1) production/TestFlight signing fixes the dev-signature ToneLibrary fallback; (2) the payload sound name must carry the `.caf` extension (`sound=alarm.caf`) — an extensionless `sound=alarm` on the same build and channel still falls back to the default tone. Foreground tests are invalid for this question because `PushAlertSoundPlayer` plays the file in-process.** |

Also useful: `grep -a "Play sound for notification"` shows the full tone/vibration
decision; `topic:()` empty hints the notification was not attributed to the app topic
in ToneLibrary's lookup. `NSLog` from the app does NOT reach `idevicesyslog` reliably —
do not rely on app-side print diagnostics for device-side questions.

## Device Selection Policy (Simulator First)

UI-related development and verification must default to the iOS Simulator:

- **Simulator first, always.** Any work that can be verified in the simulator —
  builds, UI tests, screenshots, visual regression, interactive acceptance,
  cache/manifest/JSBridge flows against local services — must be completed and
  signed off on the simulator before anything else is requested.
- **Real device is the last step, not a shortcut.** Only ask for a physical
  iPhone after every functional item that the simulator can cover has passed
  there, and only for what the simulator genuinely cannot prove (APNs/Bark
  end-to-end delivery, lock-screen/background notification behavior,
  China-region network permission dialogs, phone-specific LAN reachability).
  Never jump to a real device for work the simulator already covers.
- **Sole exception: host resources.** If the Mac lacks free memory or disk
  space to run the simulator reliably (see the 2026-08-10 disk-exhaustion
  crash), free resources first — remove only rebuildable `/tmp/wbk-*`
  DerivedData artifacts — then resume the simulator-first flow instead of
  migrating the work to a real device.

## Services

Three local services must be running for simulator development and local regression testing:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Backend (Swift) | 8080 | http://localhost:8080 | WebBridgeServer - Hummingbird, routes: /health /push /manifest /command |
| Test HTTP | 8081 | http://localhost:8081 | Static file server for cache testing (project root + test_resources/) |
| Prototype | 8083 | http://localhost:8083 | HTML prototype (index.html, v2-current-implementation.html) |

### Environment Selection Rule

Do **not** use one URL for every workflow. Pick the endpoint by device and evidence type:

- **Simulator/local regression**: start `scripts/services.sh` and use `localhost` (`:8080`, `:8081`, `:8083`).
- **Physical iPhone / Bark / public backend verification**: use `https://wbk.shanbox.19930810.xyz:8443`.
- **Physical iPhone cache and JSBridge fixture pages**: use `https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/`.
- **HTML prototype comparison**: use local `http://localhost:8083` unless a specific public prototype deployment is being verified.

Quick rule:

- If the app is installed on the user's physical iPhone, prefer the public shanbox URLs because the phone cannot reliably reach agent-local `localhost`.
- If the app is running in Simulator, CI, or local Xcode regression, keep using `scripts/services.sh` and the three local ports because tests depend on deterministic local fixtures and logs.
- If the task says "Bark", "real push", "public server", "phone", or "shanbox", run the shanbox verification scripts instead of only checking local services.

### Public shanbox Backend

Do **not** replace the local services above with the public URL. They serve different verification scopes.

| Environment | URL | Use For | Do Not Use For |
|-------------|-----|---------|----------------|
| Local backend | http://localhost:8080 | Simulator tests, local route debugging, cache/manifest/command regression | Proving public deployment or phone reachability |
| Local test HTTP | http://localhost:8081 | Static fixtures for cache tests and offline/cache HTML validation | Production/Bark route checks |
| Local prototype | http://localhost:8083 | HTML design prototype comparison | Backend/API validation |
| Public shanbox Swift backend | https://wbk.shanbox.19930810.xyz:8443 | Real-phone/server config, Bark-compatible route checks, public `/health`, `/register`, `/push`, `/test`, `/api/v1/commands` verification | Local fixture tests, prototype viewing, APNs delivery proof by itself |
| Public shanbox static fixtures | https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/ | Real-phone cache/offline/JSBridge demo pages and externally reachable WebView fixtures | Backend, Bark, push, command, or admin route checks |
| Public shanbox Node admin console | https://wbk.shanbox.19930810.xyz:8443/admin | Real-phone/browser admin console checks; public `/admin`, `/admin-push`, `/admin/api/*`, `/ws/status`, `/messages`, `/packages` verification | Local source-only admin checks |
| Public tx HTML app gateway | https://cloak.xbrowser.dev:5801 | Production-style HTTPS gateway import, signed HTML app manifests, and physical-phone gateway reachability | APNs delivery, shanbox Bark routes, or static fixture hosting |
| Local Node admin console | http://127.0.0.1:{dynamic-port} | Source-level admin console checks for `/admin`, `/admin-push`, `/admin/api/*`, `/ws/status`, `/messages`, `/packages` | Proving the Node admin console is deployed on public shanbox |

Use the public URL when validating the deployed backend or configuring the app on a physical iPhone:

```bash
bash tools/verify-shanbox-backend.sh
WBK_SHANBOX_URL=https://wbk.shanbox.19930810.xyz:8443 bash tools/verify-shanbox-backend.sh
bash tools/verify-shanbox-supervision.sh
bash tools/verify-node-admin-local.sh
curl -k https://wbk.shanbox.19930810.xyz:8443/health
curl -k https://ae8fcb.shanbox.19930810.xyz:8443/test_resources/bridge-hub.html
```

The public shanbox backend check is route-level evidence only. It does not prove APNs registration, real Bark delivery, lock-screen/background notification behavior, phone LAN behavior, or process supervision. Use `tools/verify-shanbox-supervision.sh` for SSH-level process supervision evidence.

`tools/verify-node-admin-local.sh` starts `Server/node/server.js` on a temporary local port and verifies the Node admin console routes locally. Public deployment is separately proven by `tools/verify-shanbox-backend.sh`, which checks the `wbk.shanbox` admin paths, and `tools/verify-shanbox-supervision.sh`, which checks the supervised `webbridge-node-admin` process.

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

`services.sh start/restart` uses per-user `launchctl` jobs under `.services/*.plist`, so the services keep running across separate agent shell commands. Use `bash scripts/services.sh stop` when the local verification session is finished.

**IMPORTANT**: Always run `bash scripts/services.sh start` before testing the app in simulator. The local backend is required for simulator push-route, command, manifest, cache, and prototype workflows. Use `tools/verify-shanbox-backend.sh` separately for public deployment evidence.

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

## XcodeBuildMCP

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Project Generation

- `WebBridgeKit.xcodeproj/` is generated and ignored. Treat `project.yml` as the source of truth.
- After changing `project.yml`, run `xcodegen generate && pod install` before any build, device install, or verification gate. Skipping `pod install` after regeneration can make CocoaPods modules such as SnapKit, RxCocoa, RealmSwift, or ZIPFoundation fail to resolve.

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

## Design System

- `docs/design-tokens.json` — Single source of truth for design tokens (95 tokens, 9 categories)
- `Sources/Theme/ThemeTokens.swift` — iOS token constants (**use `ThemeTokens.Color.*` for ALL colors**)
- `docs/prototype/design-tokens.css` — Auto-generated CSS variables
- `tools/sync-tokens.sh` — Bidirectional sync (JSON → Swift + CSS)

### Color Usage Rules (MANDATORY)

1. **Always use `ThemeTokens.Color.*`** — it auto-adapts to Light/Dark mode
2. **Never hardcode** `UIColor(red:)`, `.systemBlue`, `.label`, etc.
3. **Never use** `ThemeTokens.Colors.Light/Dark` (static, no dark mode) or `WKColor.*` (deprecated)
4. For shadows/borders only: `UIColor.black.cgColor` is acceptable
5. See `.opencode/rules/ios-design-best-practices.mdc` for full spec

## Icons

- Real Lucide icon library: `Sources/Theme/icons.xcassets` (1703 PDF icons)
- `Sources/Theme/LucideIcon.swift` — 50+ case enum mapping to Lucide IDs
- `Sources/Theme/Lucide.swift` — UIImage extension for loading Lucide icons

### WebBridgeKit Brand Icon Rules

- The official WebBridgeKit brand mark is the full white-background bridge logo
  in `SuperApp/Resources/branding/webbridgekit-mark.svg`: two rounded Web/native
  surfaces, white inner panels, the original interface dots/tiles, and a bold
  blue-violet bridge connector.
- The official app-icon artwork is
  `SuperApp/Resources/branding/webbridgekit-app-icon.svg`; all iPhone/iPad
  PNG sizes live in `SuperApp/Sources/Assets.xcassets/AppIcon.appiconset` and
  must preserve the same full logo artwork.
- `SuperApp/Resources/branding/webbridgekit-approved-source.png` is the approved
  white-background visual reference for raster exports. If the brand artwork is
  revised, update this reference and regenerate the brand image set/AppIcon
  sizes together.
- Native product identity surfaces use the `WebBridgeKitBrand` image asset from
  `SuperApp/Sources/Assets.xcassets/WebBridgeKitBrand.imageset`. Keep this
  centralized instead of loading the old generic `appFill` icon for About,
  Settings, notification previews, or brand fallbacks.
- Product identity surfaces include the AppIcon, About header, Settings header,
  notification app identity, Node admin header, and prototype About/Settings
  hero cards. These must use the full bridge logo and its blue-violet palette
  (`#4F6AF6` to `#8B5CF6`), including the white inner panels and interface
  details. The approved white background is part of the primary identity asset.
- Functional icons must remain semantic Lucide icons: navigation, search,
  settings, cache types, permissions, push actions, and debug tools must not be
  replaced with the brand mark.
- `SuperApp/Resources/images/logo.svg` is a cache/static test fixture and now
  uses the same full bridge logo. Keep its path and loading contract stable; use
  the dedicated branding SVGs as the canonical product sources.
- When changing the brand mark, update both SVG sources, regenerate the
  AppIcon/brand image exports, update the product surfaces above, and verify
  the image-set JSON plus all PNG dimensions before claiming completion.

## Testing

- **Coverage**: ~87% (168 test files / 193 source files)
- **UITesting**: `--ui-testing --show-component-catalog` launch arguments
- **Component Catalog**: Settings → 框架展示 OR launch arg `--show-component-catalog`
- **Visual Regression**: `tools/diff-screenshots.sh` (PIL-based, HTML report)

## Essential Verification Scripts

Use these scripts as the repeatable evidence source before declaring a module "available". Most scripts write reports/logs under `build/reports/`; treat those as verification artifacts, not source files to commit unless the user explicitly asks.

### Basic Gates

| Script | Purpose | Pass Signal | When To Run |
|--------|---------|-------------|-------------|
| `bash scripts/services.sh start` | Starts backend `:8080`, test HTTP `:8081`, prototype `:8083` | All 3 services running | Before simulator app tests, cache tests, manifest tests, push/command route checks |
| `bash scripts/services.sh verify` | Curl health check for the 3 local services | Backend `/health` 200/204, test HTTP 200, prototype 200 | After starting services or when a network/cache/push feature looks broken |
| `bash scripts/scan-crash-logs.sh --json` | Scans app crash logs, diagnostic reports, simulator logs, OOM/jetsam signals | JSON contains `"total": 0` | After launch, UI tests, real-device/simulator smoke, or when user asks about crashes |
| `swiftlint --quiet` | SwiftLint quality gate | No output, exit 0 | Before every commit |
| `bash tools/ci-lint.sh` | Design-system lint wrapper: colors, icons, fonts, `.opencode`, crash logs, token JSON, touch targets, deliverable boundaries | `17 passed, 0 failed`; warnings may remain documented debt | Before UI/design commits and release gates |

### Module Regression Gates

| Script / Command | Purpose | Pass Signal | Notes |
|------------------|---------|-------------|-------|
| `bash tools/run-cache-regression.sh` | Cache module regression: services, `CacheTests`, cache handler tests, cache dashboard UI tests | `Summary: ... failed` must be 0 | Requires a booted simulator for the UI portion |
| `bash tools/run-jsbridge-regression.sh` | JSBridge regression: core bridge tests, `BridgeTests`, handler tests, functional UI tests | `Summary: ... failed` must be 0 | Requires a booted simulator for the UI portion |
| `xcodebuild test ... -only-testing:SuperAppUITests/ModuleAvailabilityTests` | Current information architecture/module availability UI gate | 14 tests, 0 failures | Verifies `Web`, `Push`, `Bridge`, real WebView JSBridge Promise execution, `Settings`, Debug Center concrete child entries, Debug Center diagnostics/network/manifest child-tool content/actions, Deep Links, About/Legal, appearance preferences, remember-last-app, iOS Settings handoff |
| `bash tools/verify-module-availability-report.sh` | Guards `docs/verification/module-availability-verification.md` coverage: required sections, core modules, all `SettingsAction` entries, real WebView JSBridge evidence, Debug Center concrete-screen/content/action evidence, shanbox fixture evidence, shanbox command token semantics, and known unavailable markers | `100 passed, 0 failed` | Run after changing Settings navigation, module IA, availability docs, public fixture checks, shanbox command checks, or known unavailable status |
| `cd Server && swift test` | Swift Hummingbird backend route semantics | All `Manifest Routes`, `Push Routes`, `Command Routes` tests pass | Does not prove public shanbox deployment or APNs delivery |

### UI And Visual Gates

| Script | Purpose | Pass Signal | Notes |
|--------|---------|-------------|-------|
| `bash tools/verify-inbox-accordion-animation.sh` | Animation gate for the inbox group accordion: builds, records the simulator screen while `InboxGroupAnimationTests` runs, then verifies each collapse/expand anchor produced a continuous multi-frame animation (no snap, no freeze) via frame-burst analysis | `Summary: N passed, 0 failed`, exit 0 | Requires a booted simulator (`WBK_ANIM_SIM`, default iPhone 17 Pro Max) and ffmpeg; `--analyze-only` re-verifies an existing recording; deep-scroll positions are verified manually — synthetic XCUITest interaction at scrolled positions races iOS 26 snapshot resolution |
| `bash tools/run-ui-v4-regression.sh` | Aggregated UI v4 gate: services, SwiftLint, design lint, static visual checks, crash scan, screenshots, visual regression | `Summary: ... failed` must be 0 | Requires a booted simulator for screenshot/visual gates |
| `bash tools/visual-checks.sh` | Static UI contract checks: UILabel wrapping, search placeholder, row/card/pill heights, empty-state action, hardcoded component colors | `FAIL=0` | Warnings are acceptable only if documented |
| `bash tools/capture-screenshots.sh --build` | Builds/installs app, captures light/dark screenshots to `docs/screenshots/ui-redesign/` | Screenshots written successfully | Requires a booted simulator |
| `bash tools/run-visual-regression.sh` | Compares screenshot directories with threshold, writes HTML/JSON diff report | Exit 0, no screenshots over threshold | Use `--threshold N`, `--output-dir PATH`, `--screenshots-dir PATH` as needed |
| `bash tools/diff-screenshots.sh` | Low-level PIL screenshot diff engine | Exit 0 within threshold | Normally called by `run-visual-regression.sh` |

### External, Release, And Device Gates

| Script | Purpose | Pass Signal | Notes |
|--------|---------|-------------|-------|
| `bash tools/verify-shanbox-backend.sh` | Verifies public shanbox Swift backend routes, response JSON semantics, Bark-compatible GET/POST, encoded Bark query paths, command token URL-safe payload semantics, and public Node admin routes | `27 passed, 0 failed, 0 unavailable` | Route-level and command-token semantic evidence only; fake device token does not prove APNs delivery |
| `WBK_GATEWAY_URL=https://cloak.xbrowser.dev:5801 bash tools/verify-open-gateway.sh` | Verifies the portable gateway document, signed HTML app manifest shape, per-app lookup, health route, and anonymous mutation rejection | `5 passed, 0 failed` | Public HTTPS gateway evidence; this still does not prove APNs delivery |
| `bash tools/verify-shanbox-supervision.sh` | Verifies remote `WebBridgeServer` and `webbridge-node-admin` processes and whether they are supervised | `process=PASS, supervision=PASS, node_admin=PASS` | Requires SSH alias `shanbox` or `WBK_SHANBOX_SSH_HOST`; exits 1 if Swift backend or Node admin supervision is missing |
| `bash tools/verify-shanbox-fixtures.sh` | Verifies public shanbox static fixture pages for physical-phone WebView/cache/JSBridge checks, including `bridge-hub.html`, `bridge-promise-smoke.html`, `cache-showcase.html`, `WebBridge.js`, manifest, CSS/JS/image resources | `18 passed, 0 failed` | Static reachability/content-marker evidence only; does not prove native Bridge execution, APNs delivery, or offline cache behavior on a physical iPhone |
| `bash tools/verify-node-admin-local.sh` | Starts local `Server/node/server.js` and verifies Node admin, admin API, WebSocket status, messages, and packages routes | `11 passed, 0 failed` | Source/local evidence only; public deployment is covered by `verify-shanbox-backend.sh` |
| `bash tools/run-real-device-smoke.sh` | Auto-discovers paired/available iPhone, builds for device, installs, launches `com.webbridgekit.superapp` | Production pass signal: `4 passed, 0 failed`; current Personal Team evidence: `1 passed, 2 failed` | Proves physical build/install/launch only, not APNs/Bark delivery; current failure is expected until a Push-capable Apple Developer Program team/profile is used |
| `bash tools/verify-real-device-push-readiness.sh` | Verifies real-device push prerequisites: iPhone availability, backend/supervision, app install/launch, APNs entitlement, provisioning profile Push capability, token forwarding, default Bark server | Production pass signal: `0 failed`; current Personal Team evidence: `6 passed, 3 failed, 4 manual` | Current project is expected to fail under Personal Development Teams because Push Notifications requires an Apple Developer Program team/App ID/profile with `aps-environment`; manual notification receipt items must still be observed after automatic gates pass |
| `bash tools/run-release-gate.sh` | Release readiness: services, SwiftLint, design lint, Debug build, crash scan, Release archive, no test HTML in app bundle | `Summary: ... failed` must be 0 | Use before release/archive handoff |
| `bash tools/validate-cache-html.sh` | Validates cache-related HTML resources | Exit 0 | Use after changing test resources or cached HTML fixtures |

### Availability Evidence Rules

- Do not mark APNs registration, Bark end-to-end delivery, lock-screen/background notification behavior, or phone-specific LAN reachability as fully available from simulator-only evidence.
- iOS Settings handoff can be simulator-verified by proving `UIApplication.openSettingsURLString` opens `com.apple.Preferences`; require a physical confirmation only when release criteria explicitly demand a real-device Settings handoff check.
- `tools/verify-shanbox-backend.sh` proves public route behavior, Node admin public routes, and command token URL-safe payload semantics. It does not prove APNs delivery to a real iPhone.
- `tools/verify-shanbox-fixtures.sh` proves public static fixture reachability and content markers for `ae8fcb.shanbox.19930810.xyz:8443/test_resources`. It does not prove native Bridge execution, offline cache completion, APNs delivery, or phone-specific network behavior by itself.
- `tools/verify-node-admin-local.sh` proves local/source Node admin route availability only. Use `tools/verify-shanbox-backend.sh` and `tools/verify-shanbox-supervision.sh` before marking public shanbox Node admin deployment available.
- `tools/verify-shanbox-supervision.sh` proves whether the public Swift backend and Node admin have restart supervision. Current shanbox evidence is `process=PASS, supervision=PASS, node_admin=PASS` via supervisord; route checks and supervision checks should both stay green for production handoff.
- `tools/run-real-device-smoke.sh` proves the app can build, install, and launch on a paired iPhone. It does not prove notification permission, APNs token registration, or notification receipt.
- `tools/verify-real-device-push-readiness.sh` proves automatic APNs/Bark prerequisites and separates real iPhone notification observation into MANUAL rows. Do not mark APNs/Bark end-to-end available while this script has FAIL rows.
- `SuperApp/SuperApp.entitlements` is required for APNs production readiness. Do not remove `aps-environment` merely to make a Personal Development Team build pass; if `xcodebuild` reports that the team/profile does not support Push Notifications, mark APNs/Bark as unavailable and switch to a paid Apple Developer Program team/App ID/provisioning profile with Push Notifications enabled.
- As of 2026-06-03, command-line no-push smoke attempts with `CODE_SIGN_ENTITLEMENTS=` and temporary bundle id `com.webbridgekit.superapp.nopush` still fail because Xcode requires the Push Notifications capability for the SuperApp target. Do not claim real-device SuperApp install/launch until `run-real-device-smoke.sh` produces and launches `SuperApp.app`.
- When updating `docs/verification/module-availability-verification.md`, cite the exact command, pass/fail count, and report/log path.
- After updating `docs/verification/module-availability-verification.md`, run `bash tools/verify-module-availability-report.sh`. It intentionally fails if any `SettingsAction` exists in source without a corresponding `settings.cell.*` row in the report.

## Prototypes

| File | Purpose |
|------|---------|
| `docs/prototype/index.html` | V1 design prototype (English, 618 lines) |
| `docs/prototype/v2-current-implementation.html` | V2 current implementation (Chinese, 926 lines) |

## Key Dependencies

- **CocoaPods**: 10 pods (Alamofire, etc.)
- **SPM** (Server): Hummingbird 2, swift-nio, swift-crypto
- **XcodeGen**: `project.yml` generates pbxproj

## Development Workflow

1. Start services: `bash scripts/services.sh start`
2. Build: `xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd`
3. Install to simulator: `xcrun simctl install booted "$APP" && xcrun simctl launch booted com.webbridgekit.superapp`
4. Compare with prototype: open http://localhost:8083/index.html in browser
5. Run tests: `xcodebuild test ...`

## Crash Log Scanning (定期扫描)

App 内置 `CrashLogManager` 自动捕获崩溃（NSSetUncaughtExceptionHandler + signal handlers），持久化到 `Documents/crash_logs/*.json`。

### 扫描命令

```bash
# 快速扫描（推荐，定期执行）
bash scripts/scan-crash-logs.sh

# JSON 输出（用于自动化）
bash scripts/scan-crash-logs.sh --json

# 扫描 + 清理
bash scripts/scan-crash-logs.sh --fix
```

### 扫描范围

| 来源 | 路径 | 内容 |
|------|------|------|
| App 崩溃日志 | Simulator Documents/crash_logs/*.json | CrashLogManager 捕获的异常/signal 崩溃 |
| 系统诊断报告 | ~/Library/Logs/DiagnosticReports/SuperApp*.ips | macOS 系统级崩溃报告 |
| 系统日志 | simctl log show (最近 1h) | os_log error 级别 + crash/terminated/OOM 关键词 |
| 内存事件 | simctl log show (最近 1h) | memory/OOM/jetsam 事件 |

### 当用户说"扫一下日志"或"看下崩溃"时

1. 确保 booted simulator 存在且 app 已安装
2. 运行 `bash scripts/scan-crash-logs.sh`
3. 如有崩溃，分析崩溃类型/原因/调用栈，定位到对应源码
4. 将分析结果和修复建议写入 AGENTS.md 的 `## Crash Analysis` 章节下方
5. 提供修复方案

## Crash Analysis

<!-- 崩溃分析记录（最新在前） -->
<!-- 格式: | 日期 | 类型 | 原因 | 修复 | -->
<!-- 示例: | 2026-05-14 | SIGABRT | Realm schema migration | PR #123 | -->

| 日期 | 类型 | 原因 | 定位 | 修复 |
|------|------|------|------|------|
| 2026-08-17 | SIGSEGV ×2 | 21 个 ModuleAvailabilityTests 单进程全量重跑再次触发 XCUITest 高日志量隔离（栈顶 `XCTAutomationSupport runtime_issue_os_log_fault_callback`，与 2026-06-02/03、2026-08-10 记录同型），同轮 7 例失败为连锁；小批隔离重跑后仅剩分支既有失败（Home×3/通知卡/PWA 中心/TokenPush，均与设置无关） | `SuperAppUITests/ModuleAvailabilityTests.swift` 全量运行；crash_1786977990/1786978343（已清理，容器重装导致双份） | 分小批隔离重跑；`assertSettingsRowsNavigate` 导航等待 3s→8s（Cache Dashboard 首次推入时 AX 快照就绪慢，基线同样失败）后该测试转绿 |
| 2026-08-10 | UITableView termination | 消息分组收起时先变更数据源，随后按变更后的零行数删除，导致 UITableView 的批量更新与数据源不一致并退出 | SuperApp/Sources/Controllers/Tab/InboxViewController.swift:viewForHeaderInSection | 切换前保存消息总数，使用 `performBatchUpdates` 对同一批行插入/删除，并原地刷新分组头状态；分组展开/收起 UI 回归必须通过 |
| 2026-08-10 | SIGTRAP | Markdown 消息详情的 `WKWebView` 加载完成后，SnapKit 尝试更新一个只以 `greaterThanOrEqualTo` 创建的高度约束，触发 `updateConstraints` 断言 | SuperApp/Sources/Controllers/Message/MessageDetailViewController.swift:didFinish | 保留初始等值高度约束并通过保存的 `Constraint` 更新实际内容高度；消息详情、未读和应用筛选 UI 回归必须通过，随后重新扫描崩溃日志 |
| 2026-08-10 | SIGSEGV | 历史 ModuleAvailabilityTests 全量运行触发 XCUITest 高日志量隔离；崩溃发生在 `XCTAutomationSupport` 可访问性快照查询，不在通知渲染路径 | `Documents/crash_logs/crash_1786347228.json`; `runtime_issue_os_log_fault_callback` | 本轮仅保留目标化通知回归（2/2 通过），避免全量快照扫描；已按 `scan-crash-logs.sh --fix` 清理历史记录并复扫 |
| 2026-08-10 | SIGTRAP / disk exhaustion | Simulator disk had only 116 MB available; Realm initialization in the page-cache stats path threw through `try!` while Cache Dashboard data loaded | `PageCacheRuleManager.getRealm`; `CacheStatsAggregator.syncAggregate`; `CacheDashboardViewModelObservable.loadData` | Removed only rebuildable `/tmp/wbk-*` DerivedData artifacts, restored 8.5 GB free space, then rebuilt before resuming PWA notification regression |
| 2026-06-03 | SIGSEGV / scanner cleanup bug | Debug Center coverage expansion briefly reintroduced heavy XCUITest snapshot/navigation queries, and `scan-crash-logs.sh --fix` could not clean app crash JSON details because scan functions ran in command-substitution subshells and lost the `CRASHES` array | SuperAppUITests/ModuleAvailabilityTests.swift:421-453; scripts/scan-crash-logs.sh | Reduced broad navigation/scroll snapshot queries, added stable Debug Center child-screen identifiers, changed scanner functions to preserve `CRASHES`/`WARNINGS` state via `SCAN_COUNT`; focused Settings row and full ModuleAvailabilityTests 14/14 passed, crash scan returned `total: 0` |
| 2026-06-02 | SIGSEGV | `ModuleAvailabilityTests` 旧版单个超长 Settings row 用例产生大量 XCUITest snapshot/log 查询，`XCTAutomationSupport` 触发 high logging volume quarantine，CrashLogManager 记录为 SIGSEGV | SuperAppUITests/ModuleAvailabilityTests.swift:testSettingsOperationalRowsAreReachable; crash stack top: `XCTAutomationSupport runtime_issue_os_log_fault_callback` | 拆分为 `testSettingsCoreRowsAreReachable` 与 `testSettingsDebugAndSupportRowsAreReachable`，About 保留独立 deep-drill；完整 ModuleAvailabilityTests 11/11 通过，crash scan 回到 `total: 0` |
| 2026-05-20 | SIGTRAP | Notification Debug section header 未加入 card 视图层级就使用 SnapKit `equalToSuperview()`，触发 assertionFailure | SuperApp/Sources/Controllers/Debug/NotificationDebugViewController.swift:219 | 在约束 header 前补 `card.addSubview(header)` |

## Command History Access

### How to Access Command History

The Debug Panel provides access to command execution history with timestamps, status, and results.

**Access Path:**
1. Open Debug Panel: Settings → 测试面板 (or directly in development builds)
2. Navigate to **Logs tab** (tab index 2, labeled "日志" with 📄 icon)
3. View command traces with the following information:
   - **Timestamp**: When the command was executed
   - **Level**: Info/debug/error
   - **Category**: `.handler` for command executions
   - **Action**: Handler name (e.g., `push_notification`, `get_manifest`)
   - **Message**: Detailed log message
   - **Context**: Parameters (if any)
   - **Duration**: Execution time in milliseconds

**Features in Logs Tab:**
- **Filter All**: Shows all logs (default)
- **Filter Errors**: Shows only error-level logs
- **Copy All**: Copies all logs to clipboard
- **Export JSON**: Exports logs as JSON for external analysis

**Log Entry Format:**
Each command trace includes:
```
[TIMESTAMP] [LEVEL] [CATEGORY] action=ACTION_NAME message=MESSAGE context=PARAMS duration=XXXms
```

Example output:
```
2026-05-19 10:30:45.123 INFO [handler] action=push_notification message="Sent push to device" context={"token":"****","data":"..."} duration=125ms
2026-05-19 10:30:45.456 INFO [handler] action=get_manifest message="Manifest fetched successfully" duration=89ms
```

**Note**: Command history is stored in memory via `StructuredLogger.shared.memoryBuffer` with a maximum capacity of 1000 entries.

(暂无记录)

| 日期 | 类型 | 原因 | 定位 | 修复 |
|------|------|------|------|------|
| 2026-05-20 | SIGABRT | SnapKit 约束冲突：固定高度 90pt vs 内容高度超 90pt | ComponentCatalog/LayoutSections.swift:152-166 | 移除固定高度约束，改用 auto-layout 自适应 d9a7a38 |
| 2026-05-19 | SIGABRT | Podfile 重复链接 shared_pods 导致 ObjC runtime 重复类定义 | Podfile:107, WebBridgeKit+SuperApp targets | SuperApp `inherit! :search_paths` 从 WebBridgeKit 继承 pods |

## UI Testing

### Running UI Tests

```bash
# Build and run UI tests
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/wbk-dd \
  -only-testing:SuperAppUITests

# Run with component catalog visible
xcrun simctl launch booted com.webbridgekit.superapp --show-component-catalog
```

### Launch Arguments

| Argument | Purpose |
|----------|---------|
| `--ui-testing` | Seeds test data, skips onboarding |
| `--show-component-catalog` | Shows WBK component showcase |

## Release Checklist

### Pre-Release

- [ ] `bash scripts/services.sh start` — all 3 services running
- [ ] `xcodebuild build` — zero build errors
- [ ] Business warnings = 0 (toolchain warnings acceptable)
- [ ] `bash scripts/scan-crash-logs.sh` — zero crashes
- [ ] `xcodebuild test` — all tests pass
- [ ] UI smoke test on simulator (Home/Inbox/Discover/Settings)
- [ ] Dark mode visual check
- [ ] iPhone SE layout check

### Post-Release

- [ ] Update AGENTS.md Recent Commits
- [ ] Tag release: `git tag v{version}`
- [ ] Verify CI green: `gh run list --limit 5`

## Quality Policies

### Warning Policy

- **Business code warnings = 0**: All Swift source warnings in `Sources/` and `SuperApp/` must be zero
- **Toolchain warnings acceptable**: Warnings from CocoaPods, SPM dependencies, or Xcode itself are acceptable
- **Enforcement**: CI `lint` job checks for business warnings

### Crash Policy

- **Crash count must be 0**: No crashes allowed in any build
- **Enforcement**: `bash scripts/scan-crash-logs.sh` must return `total: 0`
- **If crash found**: Fix immediately before any other work, log in `## Crash Analysis`

## Recent Commits

| Commit | Description |
|--------|-------------|
| `e75dccb` | test(device): harden real-device smoke gate |
| `ab062a2` | test(ui): verify about legal deep link path |
| `4b2382e` | test(server): add shanbox backend verification gate |
| `3608f0e` | feat(ui): add screenshot capture tests, visual check scripts, CI design lint |
| `ef2874e` | feat(ui): v3 UI redesign — token system, 11 WBK components, 4 page redesigns (#2) |
| `3d79ccf` | fix(ui): inbox search bar shadow + home bookmark tap opens URL instead of camera |
| `5150fba` | fix(quality): production readiness — remove 559 prints, fix 85 force unwraps, extract hardcoded colors to ThemeTokens, add DEBUG guards |
| `12ebddc` | fix(ui): align all pages to design prototype — home token card, quick actions, app cards, inbox source pills/FAB, discover badges, settings icon tints |
| `864ad2c` | feat(offline): offline fallback, atomic updates, version status model |
| `3a9f9c1` | fix(core): HTML parser URL resolution, deferred WebView loading, crash scan improvements, cache validation tooling |
| `49a0e69` | perf(ci): share build artifacts, 4-group matrix, parallel lint+build, 30min timeout |
| `634cb49` | feat(security): CORS whitelist, third-party licenses page, 39 security tests |
| `d9a7a38` | fix(tests): skip MessageEngine in UI test mode to avoid async race condition |
| `4f53c00` | fix(build): UI build quality pass — warnings 25→4, UI audit, packaging (#1) |
| `d826dc1` | feat(productization): bookmarks, history, manifest preview, diagnostics, UI polish |
| `5218431` | feat(quality): accessibility audit, UI tests, CI hardening, release docs, screenshots |
