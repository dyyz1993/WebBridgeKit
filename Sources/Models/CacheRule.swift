//
//  CacheRule.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 缓存规则类型
public enum CacheRuleType: String, Codable {
    case domain
    case glob
    case regex
    case exact
}

/// 缓存资源类型
public enum CacheResourceType: String, Codable {
    case staticResource
    case dynamicResource
}

/// 缓存规则（简化版本，用于调试功能）
public struct CacheRule: Codable, Identifiable {
    public let id: String
    public var name: String
    public let type: CacheRuleType
    public let pattern: String
    public let resourceType: CacheResourceType
    public var isEnabled: Bool
    public let createdAt: Date
    public var priority: Int

    public init(
        id: String? = nil,
        name: String,
        type: CacheRuleType,
        pattern: String,
        resourceType: CacheResourceType = .staticResource,
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
            return matchesDomain(url: url)
        case .glob:
            return GlobPattern.matches(pattern, against: url.absoluteString)
        case .regex:
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(url.absoluteString.startIndex..., in: url.absoluteString)
                return regex.firstMatch(in: url.absoluteString, range: range) != nil
            } catch {
                return false
            }
        case .exact:
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
}
