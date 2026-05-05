import Foundation
import UIKit

/// Built-in AI tools for WebBridgeKit
public enum BuiltinAITools {

    /// List all registered handlers
    public static let listHandlers = AITool(
        name: "list_handlers",
        description: "List all registered Bridge handlers with their metadata",
        category: "bridge",
        parameters: [
            AIParameter(name: "category", description: "Filter by category (optional)")
        ],
        execute: { _ in
            // This would connect to HandlerRegistry
            // For now, return a placeholder
            return [
                "handlers": [],
                "count": 0
            ]
        }
    )

    /// Execute a handler
    public static let executeHandler = AITool(
        name: "execute_handler",
        description: "Execute a Bridge handler with specified parameters",
        category: "bridge",
        parameters: [
            AIParameter(name: "name", description: "Handler name", required: true),
            AIParameter(name: "params", type: "object", description: "Handler parameters")
        ],
        execute: { params in
            guard let name = params["name"] as? String else {
                throw AIError.toolExecutionFailed(tool: "execute_handler", reason: "Missing handler name")
            }
            // This would connect to HandlerRegistry
            return ["status": "executed", "handler": name]
        }
    )

    /// Get cache statistics
    public static let getCacheStats = AITool(
        name: "get_cache_stats",
        description: "Get cache statistics including hit rate, size, and eviction count",
        category: "cache",
        parameters: [],
        execute: { _ in
            // This would connect to CacheManager
            return [
                "memory": ["hits": 0, "misses": 0, "hitRate": 0.0],
                "disk": ["hits": 0, "misses": 0, "hitRate": 0.0]
            ]
        }
    )

    /// Clear cache
    public static let clearCache = AITool(
        name: "clear_cache",
        description: "Clear all cache entries",
        category: "cache",
        parameters: [
            AIParameter(name: "type", description: "Cache type: all, memory, disk (default: all)")
        ],
        execute: { params in
            let type = params["type"] as? String ?? "all"
            return ["status": "cleared", "type": type]
        }
    )

    /// Get message inbox
    public static let getMessages = AITool(
        name: "get_messages",
        description: "Get message inbox with optional filtering",
        category: "message",
        parameters: [
            AIParameter(name: "filter", description: "Filter: all, unread"),
            AIParameter(name: "channel", description: "Filter by channel: bark, webhook")
        ],
        execute: { _ in
            // This would connect to MessageEngine
            return ["messages": [], "count": 0]
        }
    )

    /// Send push notification
    public static let sendNotification = AITool(
        name: "send_notification",
        description: "Send a push notification via Bark",
        category: "message",
        parameters: [
            AIParameter(name: "title", description: "Notification title", required: true),
            AIParameter(name: "body", description: "Notification body", required: true),
            AIParameter(name: "url", description: "URL to open when tapped"),
            AIParameter(name: "group", description: "Notification group")
        ],
        execute: { params in
            guard let title = params["title"] as? String,
                  let body = params["body"] as? String else {
                throw AIError.toolExecutionFailed(tool: "send_notification", reason: "Missing title or body")
            }
            return ["status": "sent", "title": title, "body": body]
        }
    )

    /// Get diagnostics
    public static let getDiagnostics = AITool(
        name: "get_diagnostics",
        description: "Get diagnostic information about the app",
        category: "diagnostic",
        parameters: [
            AIParameter(name: "type", description: "Diagnostic type: system, bridge, cache, message, all")
        ],
        execute: { _ in
            return [
                "system": ["platform": "iOS", "version": UIDevice.current.systemVersion],
                "bridge": ["handlers": 0],
                "cache": ["entries": 0],
                "messages": ["unread": 0]
            ]
        }
    )

    /// All built-in tools
    public static let all: [AITool] = [
        listHandlers,
        executeHandler,
        getCacheStats,
        clearCache,
        getMessages,
        sendNotification,
        getDiagnostics
    ]
}
