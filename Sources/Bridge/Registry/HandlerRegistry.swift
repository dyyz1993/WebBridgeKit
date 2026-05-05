//
//  HandlerRegistry.swift
//  WebBridgeKit
//

import Foundation

/// Handler 注册表 — 自动发现、查询、生成文档
public class HandlerRegistry {

    public static let shared = HandlerRegistry()

    /// 所有已注册的 Handler 元数据
    private var handlers: [String: HandlerMeta] = [:]
    private let lock = NSLock()

    private init() {}

    // MARK: - Registration

    /// 注册一个 Handler 的元数据
    public func register(_ meta: HandlerMeta) {
        lock.lock()
        defer { lock.unlock() }
        handlers[meta.action] = meta
        StructuredLogger.shared.debug(
            "Handler registered: \(meta.action)",
            category: .bridge,
            action: meta.action,
            context: ["category": meta.category.rawValue, "name": meta.displayName]
        )
    }

    /// 批量注册
    public func register(_ metas: [HandlerMeta]) {
        for meta in metas {
            register(meta)
        }
    }

    // MARK: - Query

    /// 获取所有 Handler 元数据
    public func allHandlers() -> [HandlerMeta] {
        lock.lock()
        defer { lock.unlock() }
        return Array(handlers.values).sorted { $0.action < $1.action }
    }

    /// 按 action 查询
    public func handler(for action: String) -> HandlerMeta? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[action]
    }

    /// 按分类查询
    public func handlers(category: HandlerCategory) -> [HandlerMeta] {
        return allHandlers().filter { $0.category == category }
    }

    /// 所有分类及其 Handler 数量
    public func categorySummary() -> [(HandlerCategory, Int)] {
        let all = allHandlers()
        return HandlerCategory.allCases.compactMap { cat in
            let count = all.filter { $0.category == cat }.count
            return count > 0 ? (cat, count) : nil
        }
    }

    /// 查询是否已注册
    public func isRegistered(action: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return handlers[action] != nil
    }

    /// 已注册的 Handler 总数
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return handlers.count
    }

    // MARK: - Documentation Generation

    /// 生成 API 文档（JSON）
    public func generateAPIDocJSON() -> [[String: Any]] {
        return allHandlers().map { $0.jsonDict }
    }

    /// 生成 API 文档（Markdown）
    public func generateAPIDocMarkdown() -> String {
        var lines = ["# WebBridgeKit Handler API Reference", ""]
        lines.append("Total: \(count) handlers")
        lines.append("")

        for (category, count) in categorySummary() {
            lines.append("## \(category.emoji) \(category.displayName) (\(count))")
            lines.append("")

            for handler in handlers(category: category) {
                lines.append("### `\(handler.action)` — \(handler.displayName)")
                lines.append("")
                lines.append(handler.description)
                if !handler.requiredPermissions.isEmpty {
                    lines.append("")
                    lines.append("**Permissions:** \(handler.requiredPermissions.joined(separator: ", "))")
                }
                if !handler.parameters.isEmpty {
                    lines.append("")
                    lines.append("**Parameters:**")
                    for param in handler.parameters {
                        var paramLine = "- `\(param.name)` (\(param.type.rawValue))"
                        if param.required { paramLine += " *required*" }
                        if !param.description.isEmpty { paramLine += " — \(param.description)" }
                        if let options = param.options { paramLine += " [\(options.joined(separator: "|"))]" }
                        lines.append(paramLine)
                    }
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }
}
