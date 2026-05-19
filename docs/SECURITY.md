# WebBridgeKit Security Documentation

This document describes the security controls and boundaries implemented in WebBridgeKit.

## Overview

WebBridgeKit implements multiple layers of security controls to protect against common web vulnerabilities and attacks.

## Security Controls

### 1. WebView URL Allowlist (#77)

**Location:** `Sources/Controllers/WebViewController.swift:236`, `Sources/Controllers/WebBrowserViewController+Navigation.swift:14`

**Purpose:** Prevent loading of dangerous URLs and restrict URL schemes.

**Implementation:**
- Validates URL scheme against allowed list: `["http", "https", "file", "custom", "about", "manifest-cache"]`
- Explicitly blocks dangerous schemes: `["javascript", "data", "vbscript"]`
- Logs all blocked attempts with `Log.error()` category `.security`

**Example Blocked URLs:**
- `javascript:alert('XSS')` - Blocked (javascript: scheme)
- `data:text/html,<script>alert('XSS')</script>` - Blocked (data: scheme)
- `vbscript:MsgBox("XSS")` - Blocked (vbscript: scheme)

**Allowed Schemes:**
- `http://`, `https://` - Standard web protocols
- `file://` - Local file access (limited to app bundle)
- `custom://` - Custom scheme for manifest cache
- `about://`, `manifest-cache://` - Internal schemes

### 2. JS Bridge Command Allowlist (#78)

**Location:** `Sources/Core/WebJavaScriptBridge.swift:46-107`

**Purpose:** Prevent execution of unauthorized JavaScript commands through the bridge.

**Implementation:**
- Maintains an allowlist of permitted commands in `ALLOWED_COMMANDS` set
- Validates all incoming commands against allowlist before processing
- Logs and rejects unknown commands with security metadata

**Permitted Commands (31 total):**
```
share, getLocation, requestPermission, getSystemInfo, getNetworkInfo,
haptic, vibrate, clipboard, scan, camera, videoStream, speech,
audioLevel, contacts, screen, layout, mirroring, sensors,
media, systemExtra, tts, bluetooth, file, photo, getPermissionStatus,
openSettings, openPage, closePage, getHistory, getPayload,
goBack, setModal, gesture, cacheDebug, page, showNotification
```

**Security Logging:**
```swift
Log.error("Command not allowed: \(command)", category: .security, metadata: ["command": command])
```

**Example Blocked Command:**
```javascript
// This would be blocked:
window.BarkBridge.callNative('execSystemCommand', {cmd: 'rm -rf /'});

// Error response: {"success": false, "error": "Command not allowed: execSystemCommand"}
```

### 3. Manifest Tamper Protection (#79)

**Location:** `Sources/Cache/ManifestStore.swift:29-44, 203-269`, `Sources/Cache/ManifestStorage/ManifestPersistence.swift`

**Purpose:** Detect and prevent tampering of cached manifest files.

**Implementation:**
- Stores SHA-256 hash of each manifest when caching
- Verifies hash integrity on load
- Automatically removes tampered manifests
- Provides batch verification API

**Data Structure:**
```swift
struct ManifestCacheEntry {
    let manifest: Manifest
    let timestamp: Date
    let contentHash: String  // SHA-256 hash
}
```

**Hash Calculation:**
```swift
private func calculateManifestHash(manifest: Manifest) -> String {
    let encoder = JSONEncoder()
    let data = try encoder.encode(manifest)
    let hash = SHA256.hash(data: data)
    return Data(hash).map { String(format: "%02x", $0) }.joined()
}
```

**Verification API:**
```swift
// Verify single manifest
public func verifyManifestIntegrity(_ cachedEntry: ManifestCacheEntry) -> Bool

// Verify all manifests (returns stats)
public func verifyAllManifestsIntegrity() -> (total: Int, intact: Int, tampered: Int)
```

**Security Logging:**
```swift
Log.error(
    "Manifest tampering detected! Expected: \(expected), Actual: \(actual)",
    category: .security,
    metadata: ["expectedHash": expected, "actualHash": actual]
)
```

**Tampering Detection Flow:**
1. Manifest saved → SHA-256 hash calculated and stored
2. Manifest loaded → Hash recalculated and compared
3. If mismatch → Logged as security event, manifest removed
4. Batch check → Statistics reported to logs

### 4. Local Server CORS Strategy (#80)

**Location:** `Server/Sources/WebBridgeServer/entrypoint.swift`, `Server/Sources/WebBridgeServer/CORSWhitelistMiddleware.swift`

**Purpose:** Configure CORS headers to control cross-origin requests with environment-driven origin whitelisting.

**Configuration:**
- **Environment variable:** `CORS_ALLOWED_ORIGINS` (comma-separated list of allowed origins)
- **Dev mode fallback:** If not set, `allowOrigin: .all` is used
- **Production mode:** If set, only whitelisted origins receive CORS headers
- **Preflight cache:** `maxAge: 3600` (1 hour)

**Production Configuration:**
```bash
export CORS_ALLOWED_ORIGINS="https://yourdomain.com,https://app.yourdomain.com"
```

**How it works:**
- `CORSWhitelistMiddleware` validates the request `Origin` header against the configured whitelist
- Whitelisted origins receive full CORS headers (`Access-Control-Allow-Origin`, `Vary: Origin`)
- Non-whitelisted origins receive no CORS headers → browser blocks the request/response
- Preflight (OPTIONS) requests from non-whitelisted origins return 204 with no CORS headers
- `Access-Control-Max-Age: 3600` caches preflight results for 1 hour

**Headers Configured:**
- `Access-Control-Allow-Origin: <matched-origin>` (whitelist) or `*` (dev mode)
- `Access-Control-Allow-Headers: accept, authorization, content-type, origin`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH`
- `Access-Control-Max-Age: 3600`
- `Vary: Origin` (whitelist mode only)

### 5. Debug Panel Production Switch (#81)

**Location:** Throughout codebase wrapped in `#if DEBUG`

**Purpose:** Ensure debug features are not available in production builds.

**Implementation:**
- Debug UI components wrapped in `#if DEBUG` blocks
- Debug logging only compiled in DEBUG builds
- Release builds automatically exclude debug code

**Example:**
```swift
#if DEBUG
let debugScript = """
(function() {
    const debugPanel = document.createElement('div');
    debugPanel.id = 'wb-debug-panel';
    // Debug UI code...
})();
"""
webView.configuration.userContentController.addUserScript(
    WKUserScript(source: debugScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
)
#endif
```

## Security Best Practices

### Input Validation
- All user inputs validated using `InputValidator` enum
- URL schemes checked against allowlist
- File paths validated for path traversal
- HTML names sanitized for special characters

### Logging and Monitoring
- All security events logged with `Log.error()` or `Log.warning()`
- Category `.security` used for filtering
- Metadata included for forensics

### Defense in Depth
- Multiple layers of validation (URL scheme, command allowlist, manifest integrity)
- Fail-safe defaults (unknown commands blocked, invalid URLs rejected)
- Automatic cleanup of tampered resources

### Production Hardening
- Debug features disabled in release builds
- CORS should be restricted to specific origins
- Dangerous URL schemes explicitly blocked

## Security Audit Checklist

- [ ] WebView URL allowlist enforced
- [ ] JS Bridge command allowlist enforced
- [ ] Manifest integrity verification enabled
- [x] CORS headers configured for production
- [ ] Debug features disabled in release builds
- [ ] Security logging enabled and monitored
- [ ] All blocked attempts logged with context

## Incident Response

If a security event is detected:

1. **Check Logs:** Review security category logs for details
2. **Identify Source:** Examine metadata (IP, user agent, command name)
3. **Take Action:** Block malicious IP/user if necessary
4. **Review Code:** Check for additional vulnerabilities
5. **Update Allowlists:** Add/remove entries as needed

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [iOS Security Guide](https://developer.apple.com/security/)
- [WebKit Security](https://webkit.org/security/)

## Version History

| Date | Version | Changes |
|-------|----------|---------|
| 2026-05-19 | 1.0 | Initial security documentation (4 boundary tasks completed) |
