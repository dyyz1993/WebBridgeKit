//
//  PinnedURLRealm.swift
//  WebBridgeKit
//
//  Created on 2025-05-11.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

// MARK: - URL 类型自动识别枚举

public enum URLType: String, Codable, CaseIterable {
    case htmlPage
    case webApp
    case apiEndpoint
    case staticResource
    case websocket
    case mcpServer
    case manifest
    case other

    public var displayName: String {
        switch self {
        case .htmlPage: return "HTML 页面"
        case .webApp: return "Web 应用"
        case .apiEndpoint: return "API 接口"
        case .staticResource: return "静态资源"
        case .websocket: return "WebSocket"
        case .mcpServer: return "MCP 服务"
        case .manifest: return "Manifest"
        case .other: return "其他"
        }
    }

    public var iconName: String {
        switch self {
        case .htmlPage: return "file-text"
        case .webApp: return "globe"
        case .apiEndpoint: return "code"
        case .staticResource: return "image"
        case .websocket: return "wifi"
        case .mcpServer: return "bot"
        case .manifest: return "file-json"
        case .other: return "link"
        }
    }

    public static func detect(from urlString: String) -> URLType {
        let lower = urlString.lowercased()

        if lower.hasPrefix("wss://") || lower.hasPrefix("ws://") { return .websocket }

        if lower.hasSuffix(".json") && lower.contains("manifest") { return .manifest }
        if lower.contains("/manifest") || lower.contains("manifest.json") { return .manifest }

        let staticExts = [".js", ".css", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico",
                          ".woff", ".woff2", ".ttf", ".eot", ".mp4", ".webp", ".avif"]
        for ext in staticExts where lower.hasSuffix(ext) { return .staticResource }

        if lower.contains("/cdn.") || lower.contains("/static.") ||
           lower.contains("/assets/") || lower.contains("/resources/") ||
           lower.contains("fonts.googleapis.com") || lower.contains("cdn.jsdelivr.net") {
            return .staticResource
        }

        let apiPatterns = ["/api/", "/v1/", "/v2/", "/v3/", "/rest/",
                           "/graphql", "/query", "/rpc/", "_api/"]
        for pattern in apiPatterns where lower.contains(pattern) { return .apiEndpoint }

        if lower.contains("mcp") || lower.contains("modelcontextprotocol") { return .mcpServer }

        let spaHosts = ["chat.openai.com", "excalidraw.com", "stackblitz.com",
                        "figma.com", "notion.so", "linear.app", "vercel.app"]
        let host = URL(string: urlString)?.host?.lowercased() ?? ""
        if spaHosts.contains(where: { host.contains($0) }) { return .webApp }

        return .htmlPage
    }
}

// MARK: - PinnedURL Realm 模型

public class PinnedURLRealm: Object {

    // MARK: - Properties

    @objc dynamic public var id: String = UUID().uuidString
    @objc dynamic public var url: String = ""
    @objc dynamic public var title: String?
    @objc dynamic public var favicon: Data?
    @objc dynamic public var notes: String?
    @objc dynamic public var urlTypeRaw: String = URLType.other.rawValue
    @objc dynamic public var domain: String = ""
    @objc dynamic public var isPinned: Bool = true
    @objc dynamic public var createdAt: Date = Date()
    @objc dynamic public var lastAccessedAt: Date = Date()
    @objc dynamic public var accessCount: Int = 0
    @objc dynamic public var cacheSubsystemId: String?
    @objc dynamic public var cacheKey: String?
    @objc dynamic public var tagsJson: String = "[]"

    // MARK: - Computed Properties

    public var urlType: URLType {
        get { URLType(rawValue: urlTypeRaw) ?? .other }
        set { urlTypeRaw = newValue.rawValue }
    }

    public var tags: [String] {
        get {
            guard let data = tagsJson.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                tagsJson = str
            }
        }
    }

    public var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if !domain.isEmpty { return domain }
        return url.isEmpty ? "(无 URL)" : url
    }

    // MARK: - Realm Configuration

    override public class func primaryKey() -> String? {
        return "id"
    }

    override public class func indexedProperties() -> [String] {
        return ["url", "domain", "isPinned", "urlTypeRaw", "createdAt", "lastAccessedAt"]
    }
}

// MARK: - IdentifiableType

#if canImport(RxDataSources)
import RxDataSources

extension PinnedURLRealm: IdentifiableType {
    public var identity: String {
        return id
    }
}
#endif
