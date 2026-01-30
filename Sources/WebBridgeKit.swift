//
//  WebBridgeKit.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import WebKit

/// WebBridgeKit is a comprehensive framework for bridging native iOS functionality with web content.

/// Main framework class providing access to WebBridgeKit functionality
public final class WebBridgeKit {
    /// Shared singleton instance
    public static let shared = WebBridgeKit()

    private init() {}

    /// Version information
    public struct Version {
        public static let major = 1
        public static let minor = 0
        public static let patch = 0
        public static let string = "\(major).\(minor).\(patch)"
    }

    /// Initialize the WebBridgeKit framework
    public func initialize() {
        WebBridgeLogger.shared.info("WebBridgeKit v\(Version.string) initialized")

        // 预热 WebView 和 Bridge 池，提升首次打开速度
        // 异步预热，不阻塞应用启动
        WebViewPool.shared.warmup {
            WebBridgeLogger.shared.info("✅ [WebBridgeKit] WebViewPool warmed up")
        }
        WebBridgePool.shared.warmup {
            WebBridgeLogger.shared.info("✅ [WebBridgeKit] WebBridgePool warmed up")
        }
    }
}
