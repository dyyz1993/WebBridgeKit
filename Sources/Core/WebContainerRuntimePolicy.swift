//
//  WebContainerRuntimePolicy.swift
//  WebBridgeKit
//
//  Keeps the reusable runtime bridge-capable by default while allowing a
//  product to ship a pure web container with no native JavaScript surface.
//

import Foundation

/// Native capabilities exposed to pages hosted by a web container.
///
/// `containerOnly` deliberately does not inject WebBridge.js, BarkBridge, a
/// launch-context script, or any `WKScriptMessageHandler`. It is intended for
/// products that use push only to open a developer-owned web tool.
public enum WebContainerRuntimeMode: Sendable {
    case bridgeEnabled
    case containerOnly

    public var bridgeEnabled: Bool {
        self == .bridgeEnabled
    }
}

/// Process-wide host policy. The SDK remains bridge-enabled by default so
/// existing WebBridgeKit hosts keep their public behavior. A product must set
/// this before creating its first browser container.
public final class WebContainerRuntimePolicy: @unchecked Sendable {
    public static let shared = WebContainerRuntimePolicy()

    private let lock = NSLock()
    private var storedMode: WebContainerRuntimeMode = .bridgeEnabled

    private init() {}

    public var mode: WebContainerRuntimeMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedMode
        }
        set {
            lock.lock()
            storedMode = newValue
            lock.unlock()
        }
    }
}
