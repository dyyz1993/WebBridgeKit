import Foundation
import UIKit

extension BuiltinAITools {

    // MARK: - Read-only Tools

    public static let listHandlers = AITool(
        name: "list_handlers",
        description: "List all registered Bridge handlers with metadata (category, description, parameters)",
        category: "query",
        parameters: [
            AIParameter(name: "category", type: "string", description: "Filter by HandlerCategory (hardware, media, navigation, system, feedback, sensor, clipboard, permission, debug, cache, file, speech)")
        ],
        execute: { params in
            let registry = HandlerRegistry.shared
            var handlers = registry.allHandlers()

            if let category = params["category"] as? String,
               let cat = HandlerCategory(rawValue: category) {
                handlers = registry.handlers(category: cat)
            }

            let summary = registry.categorySummary()

            return [
                "count": handlers.count,
                "handlers": handlers.map { $0.jsonDict },
                "categories": summary.map { ["category": $0.0.rawValue, "displayName": $0.0.displayName, "count": $0.1] }
            ]
        }
    )

    public static let getHandlerDetail = AITool(
        name: "get_handler_detail",
        description: "Get full metadata for a specific handler including parameters, return types, and permissions",
        category: "query",
        parameters: [
            AIParameter(name: "name", type: "string", description: "Handler action name (e.g. 'camera', 'getSystemInfo')", required: true)
        ],
        execute: { params in
            guard let name = params["name"] as? String else {
                throw AIError.toolExecutionFailed(tool: "get_handler_detail", reason: "Missing 'name' parameter")
            }

            guard let meta = HandlerRegistry.shared.handler(for: name) else {
                return ["found": false, "message": "Handler '\(name)' not found"]
            }

            return ["found": true, "handler": meta.jsonDict]
        }
    )

    public static let getCacheStats = AITool(
        name: "get_cache_stats",
        description: "Get cache statistics including hit rate, memory/disk sizes, and entry counts",
        category: "query",
        parameters: [],
        execute: { _ in
            let cache = CacheManager.shared
            let global = await cache.getGlobalStatistics()
            let stats = await cache.getStatistics()

            return [
                "global": [
                    "totalRequests": global.totalRequests,
                    "hits": global.cacheHits,
                    "misses": global.cacheMisses,
                    "hitRate": String(format: "%.2f%%", global.hitRate * 100),
                    "totalSize": ByteCountFormatter.string(fromByteCount: global.totalCacheSize, countStyle: .file),
                    "totalSizeBytes": global.totalCacheSize,
                    "totalEntries": global.totalEntries
                ],
                "memory": [
                    "hits": stats.memory.cacheHits,
                    "misses": stats.memory.cacheMisses,
                    "hitRate": String(format: "%.2f%%", stats.memory.hitRate * 100),
                    "size": ByteCountFormatter.string(fromByteCount: stats.memory.totalCacheSize, countStyle: .file),
                    "entries": stats.memory.totalEntries
                ],
                "disk": [
                    "hits": stats.disk.cacheHits,
                    "misses": stats.disk.cacheMisses,
                    "hitRate": String(format: "%.2f%%", stats.disk.hitRate * 100),
                    "size": ByteCountFormatter.string(fromByteCount: stats.disk.totalCacheSize, countStyle: .file),
                    "entries": stats.disk.totalEntries
                ]
            ]
        }
    )

    public static let getCacheEntries = AITool(
        name: "get_cache_entries",
        description: "List cached entries with keys, sizes, and timestamps from the memory log buffer",
        category: "query",
        parameters: [
            AIParameter(name: "filter", type: "string", description: "Filter entries by key prefix")
        ],
        execute: { params in
            let logEntries = StructuredLogger.shared.query(category: .cache, limit: 100)

            var results = logEntries.map { entry -> [String: Any] in
                var dict: [String: Any] = [
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                    "message": entry.message
                ]
                if let action = entry.action { dict["action"] = action }
                if let context = entry.context { dict["context"] = context }
                return dict
            }

            if let filter = params["filter"] as? String, !filter.isEmpty {
                results = results.filter { entry in
                    (entry["message"] as? String)?.contains(filter) == true ||
                    (entry["action"] as? String)?.contains(filter) == true
                }
            }

            let cache = CacheManager.shared
            let global = await cache.getGlobalStatistics()

            return [
                "totalEntries": global.totalEntries,
                "recentCacheActivity": results,
                "note": "Cache entries are serialized on disk; this returns recent cache-related log activity"
            ]
        }
    )

    public static let getMessageStats = AITool(
        name: "get_message_stats",
        description: "Get message engine statistics including total received/sent/failed and per-channel breakdown",
        category: "query",
        parameters: [],
        execute: { _ in
            let engine = MessageEngine.shared
            let stats = await engine.getStatistics()
            let channels = await engine.getRegisteredChannels()
            let unread = await engine.getUnreadCount()

            return [
                "totalReceived": stats.totalReceived,
                "totalSent": stats.totalSent,
                "totalFailed": stats.totalFailed,
                "totalQueued": stats.totalQueued,
                "unreadCount": unread,
                "channels": channels,
                "byChannel": stats.byChannel.mapValues { stats -> [String: Any] in
                    [
                        "received": stats.received,
                        "sent": stats.sent,
                        "failed": stats.failed,
                        "queued": stats.queued
                    ]
                },
                "lastUpdated": ISO8601DateFormatter().string(from: stats.lastUpdated)
            ]
        }
    )

    public static let getRecentErrors = AITool(
        name: "get_recent_errors",
        description: "Get recent error and warning logs with timestamps, messages, and context",
        category: "query",
        parameters: [
            AIParameter(name: "count", type: "integer", description: "Max entries to return (default 20)"),
            AIParameter(name: "level", type: "string", description: "Minimum log level: error, warning, info, debug, verbose")
        ],
        execute: { params in
            let count = params["count"] as? Int ?? 20

            let minLevel: LogLevel
            if let levelStr = params["level"] as? String {
                switch levelStr.lowercased() {
                case "verbose": minLevel = .verbose
                case "debug": minLevel = .debug
                case "info": minLevel = .info
                case "warning": minLevel = .warning
                case "error": minLevel = .error
                default: minLevel = .warning
                }
            } else {
                minLevel = .warning
            }

            let entries = StructuredLogger.shared.query(minLevel: minLevel, limit: count)

            let logStats = StructuredLogger.shared.getStats()

            return [
                "count": entries.count,
                "errors": entries.map { $0.jsonDict },
                "summary": [
                    "totalBufferEntries": logStats.totalEntries,
                    "errorCount": logStats.errorCount,
                    "warningCount": logStats.warningCount
                ]
            ]
        }
    )

    public static let getConfig = AITool(
        name: "get_config",
        description: "Get current framework configuration including theme, server URL, push token status, and engine states",
        category: "query",
        parameters: [],
        execute: { _ in
            let engine = MessageEngine.shared
            let channels = await engine.getRegisteredChannels()

            let cache = CacheManager.shared
            let cacheStats = await cache.getGlobalStatistics()

            return [
                "handlers": [
                    "totalRegistered": HandlerRegistry.shared.count,
                    "categories": HandlerRegistry.shared.categorySummary().map {
                        ["category": $0.0.rawValue, "count": $0.1]
                    }
                ],
                "message": [
                    "registeredChannels": channels,
                    "totalReceived": await engine.getStatistics().totalReceived,
                    "unreadCount": await engine.getUnreadCount()
                ],
                "cache": [
                    "totalRequests": cacheStats.totalRequests,
                    "hitRate": String(format: "%.2f%%", cacheStats.hitRate * 100),
                    "totalSize": ByteCountFormatter.string(fromByteCount: cacheStats.totalCacheSize, countStyle: .file)
                ],
                "logging": [
                    "bufferEntries": StructuredLogger.shared.getStats().totalEntries,
                    "minLevel": "\(StructuredLogger.shared.minLevel)",
                    "sessionId": StructuredLogger.shared.sessionId
                ],
                "system": [
                    "platform": "iOS",
                    "osVersion": await MainActor.run { UIDevice.current.systemVersion },
                    "deviceModel": await MainActor.run { UIDevice.current.model },
                    "debugLogging": WebBridgeKitConfiguration.Debug.isLoggingEnabled,
                    "performanceMonitoring": WebBridgeKitConfiguration.Debug.isPerformanceMonitoringEnabled
                ]
            ]
        }
    )

    public static let readFile = AITool(
        name: "read_file",
        description: "Read a file's contents from the app's documents or caches directory (max 1MB)",
        category: "query",
        parameters: [
            AIParameter(name: "path", type: "string", description: "File path relative to app documents directory", required: true),
            AIParameter(name: "directory", type: "string", description: "Base directory: 'documents' (default), 'caches', 'tmp'")
        ],
        execute: { params in
            guard let path = params["path"] as? String else {
                throw AIError.toolExecutionFailed(tool: "read_file", reason: "Missing 'path' parameter")
            }

            let dirName = params["directory"] as? String ?? "documents"
            let fm = FileManager.default

            let baseURL: URL
            switch dirName {
            case "caches":
                baseURL = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            case "tmp":
                baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            default:
                baseURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            }

            let fileURL = baseURL.appendingPathComponent(path)

            guard fileURL.path.hasPrefix(baseURL.path) else {
                return ["error": "Path traversal not allowed", "path": path]
            }

            guard fm.fileExists(atPath: fileURL.path) else {
                return ["error": "File not found", "path": path, "resolvedPath": fileURL.path]
            }

            let maxSize = 1024 * 1024
            guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attrs[.size] as? Int, fileSize <= maxSize else {
                return ["error": "File too large (max 1MB)", "path": path]
            }

            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else {
                return ["error": "Could not read file as UTF-8 text", "path": path, "size": fileSize]
            }

            return [
                "path": path,
                "resolvedPath": fileURL.path,
                "size": fileSize,
                "content": content
            ]
        }
    )

    public static let getDiagnosticReport = AITool(
        name: "get_diagnostic_report",
        description: "Get a full diagnostic report combining handler count, cache stats, message stats, memory usage, uptime, and OS version",
        category: "query",
        parameters: [],
        execute: { _ in
            let registry = HandlerRegistry.shared
            let cache = CacheManager.shared
            let engine = MessageEngine.shared

            async let globalCache = cache.getGlobalStatistics()
            async let msgStats = engine.getStatistics()
            async let channels = engine.getRegisteredChannels()
            async let unread = engine.getUnreadCount()

            let logStats = StructuredLogger.shared.getStats()

            let memoryInfo = ProcessInfo.processInfo
            let physicalMem = memoryInfo.physicalMemory
            let osVersion = "\(memoryInfo.operatingSystemVersionString)"

            var uptime: TimeInterval = 0
            uptime = TimeInterval(memoryInfo.systemUptime)

            let global = await globalCache
            let msgs = await msgStats
            let chs = await channels
            let unreadCount = await unread

            return [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "handlers": [
                    "total": registry.count,
                    "categories": registry.categorySummary().count
                ],
                "cache": [
                    "totalRequests": global.totalRequests,
                    "hitRate": String(format: "%.2f%%", global.hitRate * 100),
                    "totalSize": ByteCountFormatter.string(fromByteCount: global.totalCacheSize, countStyle: .file),
                    "entries": global.totalEntries
                ],
                "messages": [
                    "received": msgs.totalReceived,
                    "sent": msgs.totalSent,
                    "failed": msgs.totalFailed,
                    "unread": unreadCount,
                    "channels": chs
                ],
                "logging": [
                    "bufferEntries": logStats.totalEntries,
                    "errors": logStats.errorCount,
                    "warnings": logStats.warningCount
                ],
                "system": [
                    "platform": "iOS",
                    "osVersion": await MainActor.run { UIDevice.current.systemVersion },
                    "kernelVersion": osVersion,
                    "deviceModel": await MainActor.run { UIDevice.current.model },
                    "physicalMemory": ByteCountFormatter.string(fromByteCount: Int64(physicalMem), countStyle: .memory),
                    "uptime": String(format: "%.0f", uptime) + "s",
                    "processId": ProcessInfo.processInfo.processIdentifier
                ]
            ]
        }
    )
}
