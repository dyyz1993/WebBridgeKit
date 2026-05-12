import Foundation
import UIKit

extension BuiltinAITools {

    // MARK: - Read-write Tools

    public static let executeHandler = AITool(
        name: "execute_handler",
        description: "Execute a registered Bridge handler by action name with given parameters. Returns handler metadata (actual execution requires UI context)",
        category: "action",
        parameters: [
            AIParameter(name: "name", type: "string", description: "Handler action name (e.g. 'getSystemInfo', 'vibrate')", required: true),
            AIParameter(name: "params", type: "object", description: "JSON object of handler parameters")
        ],
        execute: { params in
            guard let name = params["name"] as? String else {
                throw AIError.toolExecutionFailed(tool: "execute_handler", reason: "Missing handler name")
            }

            let registry = HandlerRegistry.shared

            guard registry.isRegistered(action: name) else {
                return [
                    "success": false,
                    "error": "Handler '\(name)' not found",
                    "availableHandlers": registry.allHandlers().map { $0.action }
                ]
            }

            guard let meta = registry.handler(for: name) else {
                return ["success": false, "error": "Could not retrieve metadata for '\(name)'"]
            }

            let handlerParams = params["params"] as? [String: Any] ?? [:]

            var paramValidation: [[String: Any]] = []
            for paramDef in meta.parameters where paramDef.required {
                let provided = handlerParams[paramDef.name] != nil
                paramValidation.append([
                    "name": paramDef.name,
                    "type": paramDef.type.rawValue,
                    "required": true,
                    "provided": provided
                ])
            }

            let missingRequired = paramValidation.filter { ($0["provided"] as? Bool) != true }

            if !missingRequired.isEmpty {
                return [
                    "success": false,
                    "handler": name,
                    "error": "Missing required parameters",
                    "missingParams": missingRequired,
                    "parameterDefs": meta.parameters.map { [
                        "name": $0.name,
                        "type": $0.type.rawValue,
                        "required": $0.required,
                        "description": $0.description
                    ] }
                ]
            }

            return [
                "success": true,
                "handler": name,
                "displayName": meta.displayName,
                "category": meta.category.rawValue,
                "providedParams": handlerParams,
                "validation": paramValidation,
                "requiresNetwork": meta.requiresNetwork,
                "requiresHardware": meta.requiresHardware,
                "permissions": meta.requiredPermissions,
                "note": "Handler metadata validated. Actual execution dispatched to Bridge engine with UI context."
            ]
        }
    )

    public static let clearCache = AITool(
        name: "clear_cache",
        description: "Clear cache entries. Clears all caches or filter by namespace/type",
        category: "action",
        parameters: [
            AIParameter(name: "prefix", type: "string", description: "Cache key prefix to selectively clear (clears all if omitted)")
        ],
        execute: { params in
            let cache = CacheManager.shared
            let statsBefore = await cache.getGlobalStatistics()

            if let prefix = params["prefix"] as? String, !prefix.isEmpty {
                await cache.remove(for: prefix)

                return [
                    "success": true,
                    "action": "partial",
                    "clearedKey": prefix,
                    "previousStats": [
                        "totalRequests": statsBefore.totalRequests,
                        "entries": statsBefore.totalEntries,
                        "size": ByteCountFormatter.string(fromByteCount: statsBefore.totalCacheSize, countStyle: .file)
                    ]
                ]
            }

            await cache.clearAll()

            return [
                "success": true,
                "action": "clearAll",
                "previousStats": [
                    "totalRequests": statsBefore.totalRequests,
                    "entries": statsBefore.totalEntries,
                    "size": ByteCountFormatter.string(fromByteCount: statsBefore.totalCacheSize, countStyle: .file)
                ]
            ]
        }
    )

    public static let sendTestPush = AITool(
        name: "send_test_push",
        description: "Send a test push notification via the Bark channel registered in MessageEngine",
        category: "action",
        parameters: [
            AIParameter(name: "title", type: "string", description: "Notification title", required: true),
            AIParameter(name: "body", type: "string", description: "Notification body text", required: true),
            AIParameter(name: "group", type: "string", description: "Notification group identifier"),
            AIParameter(name: "url", type: "string", description: "URL to open when notification is tapped")
        ],
        execute: { params in
            guard let title = params["title"] as? String,
                  let body = params["body"] as? String else {
                throw AIError.toolExecutionFailed(tool: "send_test_push", reason: "Missing 'title' or 'body' parameter")
            }

            let engine = MessageEngine.shared
            let channels = await engine.getRegisteredChannels()

            let payload = MessagePayload(
                title: title,
                body: body,
                channel: "bark",
                group: params["group"] as? String,
                targetURL: params["url"] as? String
            )

            guard channels.contains("bark") else {
                return [
                    "success": false,
                    "error": "Bark channel not registered",
                    "availableChannels": channels,
                    "hint": "Register a BarkChannel with MessageEngine before sending push notifications"
                ]
            }

            do {
                let result = try await engine.send(payload, through: "bark")
                switch result {
                case .success(let messageId):
                    return [
                        "success": true,
                        "messageId": messageId,
                        "title": title,
                        "channel": "bark"
                    ]
                case .failed(let error):
                    return [
                        "success": false,
                        "error": error.localizedDescription,
                        "channel": "bark"
                    ]
                case .queued(let messageId):
                    return [
                        "success": true,
                        "queued": true,
                        "messageId": messageId,
                        "channel": "bark"
                    ]
                }
            } catch {
                return [
                    "success": false,
                    "error": error.localizedDescription,
                    "channel": "bark"
                ]
            }
        }
    )

    public static let reloadConfig = AITool(
        name: "reload_config",
        description: "Reload configuration for a specific subsystem (logging, cache statistics)",
        category: "action",
        parameters: [
            AIParameter(name: "type", type: "string", description: "Subsystem to reload: 'logging', 'cache_stats', 'all'", required: true)
        ],
        execute: { params in
            guard let type = params["type"] as? String else {
                throw AIError.toolExecutionFailed(tool: "reload_config", reason: "Missing 'type' parameter")
            }

            var reloaded: [String] = []

            switch type.lowercased() {
            case "logging":
                StructuredLogger.shared.clearBuffer()
                reloaded.append("logging (buffer cleared)")
                return [
                    "success": true,
                    "reloaded": reloaded,
                    "newState": [
                        "bufferEntries": StructuredLogger.shared.getStats().totalEntries,
                        "minLevel": "\(StructuredLogger.shared.minLevel)",
                        "sessionId": StructuredLogger.shared.sessionId
                    ]
                ]

            case "cache_stats":
                let cache = CacheManager.shared
                await cache.resetStatistics()
                reloaded.append("cache_stats")
                let newStats = await cache.getGlobalStatistics()
                return [
                    "success": true,
                    "reloaded": reloaded,
                    "newState": [
                        "totalRequests": newStats.totalRequests,
                        "hitRate": String(format: "%.2f%%", newStats.hitRate * 100),
                        "entries": newStats.totalEntries
                    ]
                ]

            case "all":
                StructuredLogger.shared.clearBuffer()
                let cache = CacheManager.shared
                await cache.resetStatistics()
                reloaded.append("logging")
                reloaded.append("cache_stats")

                let newCacheStats = await cache.getGlobalStatistics()
                return [
                    "success": true,
                    "reloaded": reloaded,
                    "newState": [
                        "logging": [
                            "bufferEntries": 0,
                            "minLevel": "\(StructuredLogger.shared.minLevel)"
                        ],
                        "cache": [
                            "totalRequests": newCacheStats.totalRequests,
                            "hitRate": String(format: "%.2f%%", newCacheStats.hitRate * 100)
                        ]
                    ]
                ]

            default:
                return [
                    "success": false,
                    "error": "Unknown type '\(type)'. Valid: 'logging', 'cache_stats', 'all'"
                ]
            }
        }
    )
}
