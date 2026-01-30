//
//  CacheRule.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 缓存规则类型
@available(*, deprecated, message: "Use PageCacheRule instead for page-level offline caching")
public enum CacheRuleType: String, Codable {
    /// 域名匹配 - 匹配整个域名及其所有子域名和路径
    case domain
    /// Glob 模式匹配 - 使用通配符匹配 URL
    case glob
    /// 正则表达式匹配
    case regex
    /// 精确 URL 匹配
    case exact
}

/// 缓存资源类型
@available(*, deprecated, message: "Use PageCacheRule instead for page-level offline caching")
public enum CacheResourceType: String, Codable {
    /// 静态资源 - CSS, JS, 图片, 字体等（默认启用）
    case staticResource
    /// 动态请求 - XHR, Fetch API 等（默认禁用，需要显式开启）
    case dynamicResource
}

/// 缓存规则
@available(*, deprecated, message: "Use PageCacheRule instead for page-level offline caching. CacheRule is deprecated and will be removed in a future version.")
public struct CacheRule: Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: CacheRuleType
    public let pattern: String
    public let resourceType: CacheResourceType // 新增：资源类型
    public var isEnabled: Bool
    public let createdAt: Date
    public var priority: Int // 优先级，数字越大优先级越高

    public init(
        id: String? = nil,
        name: String,
        type: CacheRuleType,
        pattern: String,
        resourceType: CacheResourceType = .staticResource, // 默认为静态资源
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.type = type
        self.pattern = pattern
        self.resourceType = resourceType
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.priority = priority
    }

    /// 检查 URL 是否匹配此规则
    public func matches(url: URL) -> Bool {
        guard isEnabled else { return false }

        switch type {
        case .domain:
            // 域名匹配：检查 URL 的 host 是否匹配 pattern
            // 支持子域名匹配（如 *.example.com）
            return matchesDomain(url: url)

        case .glob:
            // Glob 模式匹配
            return GlobPattern.matches(pattern, against: url.absoluteString)

        case .regex:
            // 正则表达式匹配
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(url.absoluteString.startIndex..., in: url.absoluteString)
                return regex.firstMatch(in: url.absoluteString, range: range) != nil
            } catch {
                return false
            }

        case .exact:
            // 精确匹配
            return url.absoluteString == pattern
        }
    }

    /// 域名匹配逻辑
    private func matchesDomain(url: URL) -> Bool {
        guard let host = url.host else { return false }

        let rulePattern = pattern.lowercased()
        let urlHost = host.lowercased()

        // 精确匹配
        if urlHost == rulePattern {
            return true
        }

        // 通配符子域名匹配 (*.example.com)
        if rulePattern.hasPrefix("*.") {
            let baseDomain = String(rulePattern.dropFirst(2))
            // 检查是否是 baseDomain 或其子域名
            if urlHost == baseDomain || urlHost.hasSuffix(".\(baseDomain)") {
                return true
            }
        }

        return false
    }

    /// 检查 URL 是否是静态资源（CSS, JS, 图片, 字体等）
    public static func isStaticResource(url: URL) -> Bool {
        let path = url.path.lowercased()
        let staticExtensions = [
            ".css", ".js", ".json", ".xml",
            ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico",
            ".woff", ".woff2", ".ttf", ".eot", ".otf",
            ".mp4", ".webm", ".ogg", ".mp3", ".wav"
        ]
        return staticExtensions.contains { path.hasSuffix($0) }
    }

    /// 检查 URL 是否是动态请求（XHR, Fetch API 等）
    public static func isDynamicRequest(url: URL) -> Bool {
        // 通常动态请求带有查询参数或特定的路径模式
        return url.query != nil && !url.query!.isEmpty
    }

    /// 获取规则的显示描述
    public var displayDescription: String {
        let typePrefix: String
        switch resourceType {
        case .staticResource:
            typePrefix = "📁 静态"
        case .dynamicResource:
            typePrefix = "🔄 动态"
        }

        switch type {
        case .domain:
            return "\(typePrefix) - 域名: \(pattern)"
        case .glob:
            return "\(typePrefix) - Glob: \(pattern)"
        case .regex:
            return "\(typePrefix) - 正则: \(pattern)"
        case .exact:
            return "\(typePrefix) - URL: \(pattern)"
        }
    }

    /// 检查 URL 是否应该被此规则缓存（考虑资源类型）
    public func shouldCache(url: URL, requestType: CacheResourceType) -> Bool {
        guard isEnabled && matches(url: url) else { return false }

        // 静态资源规则可以缓存静态资源
        // 动态资源规则只缓存明确匹配的动态请求
        switch (self.resourceType, requestType) {
        case (.staticResource, .staticResource), (.dynamicResource, .dynamicResource):
            return true
        case (.staticResource, .dynamicResource):
            // 静态资源规则不缓存动态请求
            return false
        case (.dynamicResource, .staticResource):
            // 动态资源规则不缓存静态资源
            return false
        }
    }

    /// 获取匹配的资源数量（从缓存统计中获取）
    public var matchedResourceCount: Int {
        // TODO: 从缓存中统计匹配的资源数量
        return 0
    }
}

/// 预设的缓存规则
public extension CacheRule {
    /// 百度相关域名 - 静态资源
    static let baiduStaticRule = CacheRule(
        name: "百度 (静态)",
        type: .domain,
        pattern: "*.baidu.com",
        resourceType: .staticResource,
        priority: 100
    )

    /// VIP 相关域名 - 静态资源
    static let vipStaticRule = CacheRule(
        name: "VIP 视频 (静态)",
        type: .domain,
        pattern: "*.vip.com",
        resourceType: .staticResource,
        priority: 90
    )

    /// VIP 相关域名 - 动态请求（默认禁用）
    static let vipDynamicRule = CacheRule(
        name: "VIP API (动态)",
        type: .glob,
        pattern: "https://*.vip.com/api/**",
        resourceType: .dynamicResource,
        isEnabled: false, // 动态请求默认禁用
        priority: 85
    )

    /// GitHub JS/CSS 资源
    static let githubCDNRule = CacheRule(
        name: "GitHub CDN",
        type: .glob,
        pattern: "https://*.github.com/**/*.js",
        resourceType: .staticResource,
        priority: 80
    )

    /// 所有图片资源
    static let allImagesRule = CacheRule(
        name: "所有图片",
        type: .glob,
        pattern: "https://**/*.{png,jpg,jpeg,gif,webp,svg}",
        resourceType: .staticResource,
        priority: 70
    )

    /// 常用 CDN 域名
    static let cdnRule = CacheRule(
        name: "常用 CDN",
        type: .glob,
        pattern: "https://{cdn,static,assets}.*/*.{js,css}",
        resourceType: .staticResource,
        priority: 60
    )

    /// 通用动态 API 规则（默认禁用）
    static let genericAPIRule = CacheRule(
        name: "通用 API",
        type: .glob,
        pattern: "https://**/api/**",
        resourceType: .dynamicResource,
        isEnabled: false, // 动态请求默认禁用
        priority: 50
    )

    /// 所有预设规则
    static let presetRules: [CacheRule] = [
        baiduStaticRule,
        vipStaticRule,
        vipDynamicRule, // 新增：动态规则
        githubCDNRule,
        allImagesRule,
        cdnRule,
        genericAPIRule // 新增：通用 API 规则
    ]
}
