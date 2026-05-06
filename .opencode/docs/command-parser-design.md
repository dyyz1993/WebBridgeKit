# Command Parser Design Document (口令解析引擎)

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      SuperApp (Business Layer)           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  AppDelegate / SceneDelegate                        │ │
│  │  - onForeground → ClipboardMonitor.check()          │ │
│  │  - handleCommand(payload) → openBrowser(...)        │ │
│  └──────────────────────┬──────────────────────────────┘ │
└─────────────────────────┼───────────────────────────────┘
                          │ @Sendable callback
┌─────────────────────────┼───────────────────────────────┐
│  WebBridgeKit (Framework Layer)                         │
│  ┌──────────────────────┼──────────────────────────────┐│
│  │        CommandParser (actor, singleton)              ││
│  │  ┌───────────────────┴───────────────────┐          ││
│  │  │  parse(input: String) → CommandPayload │          ││
│  │  └───────────────────┬───────────────────┘          ││
│  │          ┌───────────┼───────────┐                   ││
│  │  ┌───────▼──────┐ ┌──▼────────┐ ┌▼───────────┐     ││
│  │  │ CommandDecoder│ │ Signature │ │ Command    │     ││
│  │  │ (3 formats)  │ │ Verifier  │ │ Router     │     ││
│  │  └──────────────┘ └───────────┘ └────────────┘     ││
│  │          ┌──────────────────────────────┐           ││
│  │  ┌───────▼──────────────────────────┐   │           ││
│  │  │ ClipboardMonitor (UIKit)         │   │           ││
│  │  │ - checkOnAppForeground()         │   │           ││
│  │  │ - detectCommandPrefix()          │   │           ││
│  │  └──────────────────────────────────┘   │           ││
│  └─────────────────────────────────────────┘           ││
│  ┌────────────────┐  ┌──────────────┐  ┌────────────┐  ││
│  │ Cache Engine   │  │ Message      │  │ Bridge     │  ││
│  │ (ManifestCache)│  │ Engine       │  │ Engine     │  ││
│  └────────────────┘  └──────────────┘  └────────────┘  ││
└─────────────────────────────────────────────────────────┘
```

## 2. Protocol Definitions

### 2.1 CommandParserProtocol

```swift
public protocol CommandParserProtocol: Sendable {
    func parse(_ input: String) async throws -> CommandPayload
    func parseFromClipboard() async throws -> CommandPayload?
    func registerSignatureVerifier(_ verifier: any CommandSignatureVerifier)
}
```

### 2.2 CommandDecoderProtocol

```swift
public protocol CommandDecoderProtocol: Sendable {
    var format: CommandFormat { get }
    func canDecode(_ input: String) -> Bool
    func decode(_ input: String) throws -> CommandRawPayload
}
```

### 2.3 CommandSignatureVerifier

```swift
public protocol CommandSignatureVerifier: Sendable {
    func verify(payload: CommandRawPayload, signature: String) -> Bool
}
```

### 2.4 CommandRouterProtocol

```swift
public protocol CommandRouterProtocol: Sendable {
    func route(_ payload: CommandPayload) -> CommandRoute
}
```

### 2.5 ClipboardMonitorProtocol

```swift
public protocol ClipboardMonitorProtocol: Sendable {
    func checkForCommand() -> String?
    func startMonitoring()
    func stopMonitoring()
    var onCommandDetected: (@Sendable (String) -> Void)? { get set }
}
```

## 3. Data Flow

```
Clipboard Text
     │
     ▼
ClipboardMonitor.checkForCommand()
     │
     │ detect prefix / URL scheme / base64 pattern
     ▼
CommandParser.parse(input)
     │
     ├─── CommandDecoderRegistry finds matching decoder
     │    ├── Base64CommandDecoder   → "eyJ..." pattern
     │    ├── URLSchemeCommandDecoder → "wbsk://command?..."
     │    └── PlainTextCommandDecoder → "【WebBridgeKit】..."
     │
     ▼
CommandRawPayload (intermediate, unsigned)
     │
     ├─── SignatureVerifier.verify()
     │    ├── HMAC-SHA256 with server-shared secret
     │    └── Reject if signature mismatch
     │
     ▼
CommandPayload (validated, typed)
     │
     ▼
CommandRouter.route(payload)
     │
     ├── .cachedApp(appid:) → ManifestCacheManager.getHTML(for:)
     ├── .url(url:)         → WebBrowserManager.openBrowser(url:)
     └── .deeplink(url:)    → URL scheme open
```

## 4. Command Formats

### 4.1 Base64 Encoded Format

```
Raw: {"appid":"shop","url":"https://...","title":"...","token":"...","sig":"hmac_hex"}
Encoded: eyJhcHBpZCI6InNob3AiLC...
```

The payload is a JSON object Base64URL-encoded. The `sig` field is HMAC-SHA256 of the payload (excluding `sig` itself) using a pre-shared key.

### 4.2 URL Scheme Format

```
wbsk://command?data=<base64url-encoded-payload>&sig=<hmac_hex>
```

### 4.3 Plain Text Format

```
【WebBridgeKit】eyJhcHBpZCI6InNob3Ai...
```

The text between the prefix marker `【WebBridgeKit】` and end-of-string is the Base64URL-encoded payload.

## 5. Security Considerations

### 5.1 Signature Verification

- Every command MUST carry an HMAC-SHA256 signature
- The signature covers all fields except `sig` itself
- Key rotation: support multiple keys with key IDs
- Business layer injects the `CommandSignatureVerifier` implementation

### 5.2 Anti-Replay

- Payload includes a `timestamp` field (Unix epoch seconds)
- Reject commands older than `maxAge` seconds (configurable, default 300)
- Payload includes `nonce` for deduplication

### 5.3 Input Sanitization

- All URLs validated against allowed schemes (http, https)
- appid validated against allowed character set
- Maximum payload size enforced (default 4KB)
- Base64 decoding with strict padding validation

### 5.4 Clipboard Privacy

- Only read clipboard on app foreground (not background)
- Clear detection flag after reading to prevent re-processing
- Do not log clipboard content

## 6. Integration Points

### 6.1 Cache Engine

```swift
// CommandRouter resolves .cachedApp → ManifestCacheManager
let html = ManifestCacheManager.shared.getHTML(for: payload.appid)
```

### 6.2 Message Engine

```swift
// Command can be forwarded as MessagePayload for notification pipeline
let messagePayload = payload.toMessagePayload()
try await MessageEngine.shared.receive(messagePayload)
```

### 6.3 Bridge Engine

```swift
// Route result used by WebBrowserManager
let route = CommandRouter.shared.route(payload)
switch route {
case .url(let url):
    WebBrowserManager.shared.openBrowser(url: url, ...)
case .cachedApp(let appid):
    // load from cache or download
}
```

## 7. Configuration

```swift
public struct CommandParserConfiguration: Sendable {
    public var maxPayloadSize: Int = 4096
    public var maxAge: TimeInterval = 300
    public var allowedSchemes: Set<String> = ["http", "https"]
    public var commandPrefix: String = "【WebBridgeKit】"
    public var urlSchemePrefix: String = "wbsk://command"
    public var enableSignatureVerification: Bool = true
    public var enableTimestampValidation: Bool = true

    public static let `default` = CommandParserConfiguration()
}
```

## 8. Usage in SuperApp (Business Layer)

```swift
// In AppDelegate or SceneDelegate
func sceneDidEnterBackground(_ scene: UIScene) {
    CommandParser.shared.clearLastClipboardHash()
}

func sceneDidBecomeActive(_ scene: UIScene) {
    Task {
        if let payload = try? await CommandParser.shared.parseFromClipboard() {
            handleCommand(payload)
        }
    }
}

func handleCommand(_ payload: CommandPayload) {
    let route = CommandRouter.shared.route(payload)
    switch route {
    case .cachedApp(let appid):
        // Open cached mini-app
        openCachedApp(appid: appid, token: payload.token, extra: payload.extra)
    case .url(let url):
        // Open URL in browser
        WebBrowserManager.shared.openBrowser(url: url, ...)
    case .deeplink, .none:
        break
    }
}
```
