//
//  WebBridgeKit.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import WebKit

// WebBridgeKit is a comprehensive framework for bridging native iOS functionality with web content.

// MARK: - Debug Configuration

#if DEBUG
/// Configure logger for debug mode
private func configureLoggerForDebug() {
    WebBridgeLogger.shared.includeFileLocation = true
    WebBridgeLogger.shared.minLogLevel = .debug
}
#else
/// Configure logger for release mode
private func configureLoggerForRelease() {
    WebBridgeLogger.shared.includeFileLocation = false
    WebBridgeLogger.shared.minLogLevel = .warning
}
#endif

/// Main framework class providing access to WebBridgeKit functionality
public final class WebBridgeKit {
    /// Shared singleton instance
    public static let shared = WebBridgeKit()

    private init() {
        // Configure logger based on build configuration
        #if DEBUG
        configureLoggerForDebug()
        #else
        configureLoggerForRelease()
        #endif
    }

    /// Version information
    public struct Version {
        public static let major = 1
        public static let minor = 0
        public static let patch = 0
        public static let string = "\(major).\(minor).\(patch)"
    }

    /// Initialize the WebBridgeKit framework
    public func initialize() {
        // Register all handler metadata for auto-discovery
        _ = HandlerMetaRegistry.registerAll

        Log.info("WebBridgeKit v\(Version.string) initialized", category: .general)

        // 预热 WebView 和 Bridge 池，提升首次打开速度
        // 异步预热，不阻塞应用启动

        // 确保在主线程开始预热，内部会处理异步逻辑
        DispatchQueue.main.async {
            WebViewPool.shared.warmup {
                Log.info("WebViewPool warmed up", category: .general)
            }
            WebBridgePool.shared.warmup {
                Log.info("WebBridgePool warmed up", category: .general)
            }
        }
    }
}
