//
//  PageCacheRule.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 页面缓存规则
public struct PageCacheRule: Codable, Identifiable {
    public let id: String
    public let name: String                      // 规则名称，如"百度"
    public var includePatterns: [String]         // 包含的 Glob 模式数组
    public var excludePatterns: [String]         // 排除的 Glob 模式数组
    public var isEnabled: Bool
    public let createdAt: Date
    public var lastCachedAt: Date?               // 最后缓存时间

    public init(
        id: String? = nil,
        name: String,
        includePatterns: [String],
        excludePatterns: [String] = [],
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        lastCachedAt: Date? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.includePatterns = includePatterns
        self.excludePatterns = excludePatterns
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastCachedAt = lastCachedAt
    }

    /// 检查 URL 是否匹配此规则
    public func matches(url: URL) -> Bool {
        guard isEnabled else { return false }

        let urlString = url.absoluteString

        // 先检查是否在排除列表中
        for pattern in excludePatterns where GlobPattern.matches(pattern, against: urlString) {
            return false
        }

        // 再检查是否匹配包含列表
        for pattern in includePatterns where GlobPattern.matches(pattern, against: urlString) {
            return true
        }

        return false
    }

    /// 显示描述
    public var displayDescription: String {
        let includeStr = includePatterns.count == 1
            ? includePatterns[0]
            : "\(includePatterns.count) 个模式"

        if excludePatterns.isEmpty {
            return "\(name) - \(includeStr)"
        } else {
            let excludeStr = excludePatterns.count == 1
                ? excludePatterns[0]
                : "\(excludePatterns.count) 个模式"
            return "\(name) - \(includeStr) (排除: \(excludeStr))"
        }
    }

    /// 简短描述（用于列表显示）
    public var shortDescription: String {
        if excludePatterns.isEmpty {
            return "\(name) (\(includePatterns.count) 个包含模式)"
        } else {
            return "\(name) (\(includePatterns.count) 包含, \(excludePatterns.count) 排除)"
        }
    }
}

/// 缓存页面信息
public struct CachedPageInfo: Codable, Identifiable {
    public let id: String                // 页面 ID
    public let url: String               // 原始 URL
    public let title: String             // 页面标题
    public let ruleId: String            // 关联的规则 ID
    public let ruleName: String          // 规则名称
    public let resourceCount: Int        // 资源数量
    public let totalSize: Int64          // 总大小
    public let cachedAt: Date            // 缓存时间
    public let isOfflineAvailable: Bool  // 是否可离线访问
    public let isExcluded: Bool          // 是否被排除（手动标记）

    public init(
        id: String,
        url: String,
        title: String,
        ruleId: String,
        ruleName: String,
        resourceCount: Int,
        totalSize: Int64,
        cachedAt: Date,
        isOfflineAvailable: Bool = true,
        isExcluded: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.resourceCount = resourceCount
        self.totalSize = totalSize
        self.cachedAt = cachedAt
        self.isOfflineAvailable = isOfflineAvailable
        self.isExcluded = isExcluded
    }

    /// 格式化大小显示
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// 格式化缓存时间
    public var formattedCachedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: cachedAt, relativeTo: Date())
    }
}

/// 规则及其关联的缓存页面（用于 UI 显示）
public struct RuleWithPages: Identifiable {
    public var rule: PageCacheRule
    public var cachedPages: [CachedPageInfo]  // 该规则下已缓存的页面
    public var isExpanded: Bool                // UI 展开状态

    public init(rule: PageCacheRule, cachedPages: [CachedPageInfo] = [], isExpanded: Bool = false) {
        self.rule = rule
        self.cachedPages = cachedPages
        self.isExpanded = isExpanded
    }

    public var id: String { rule.id }

    /// 该规则下的缓存页面总数
    public var totalPagesCount: Int { cachedPages.count }

    /// 该规则下的总大小
    public var totalSize: Int64 {
        cachedPages.reduce(0) { $0 + $1.totalSize }
    }

    /// 格式化总大小
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// 排除的页面数
    public var excludedCount: Int {
        cachedPages.filter { $0.isExcluded }.count
    }
}

// MARK: - Preset Rules

public extension PageCacheRule {

    /// 百度规则
    static let baiduRule = PageCacheRule(
        id: "preset-baidu",
        name: "百度",
        includePatterns: ["https://*.baidu.com/**"],
        excludePatterns: ["https://*.baidu.com/login/**"]
    )

    /// VIP 视频规则
    static let vipVideoRule = PageCacheRule(
        id: "preset-vip-video",
        name: "VIP 视频",
        includePatterns: [
            "https://*.vip.com/video/**",
            "https://*.vip.com/movie/**"
        ],
        excludePatterns: [
            "https://*.vip.com/login*",
            "https://*.vip.com/register*"
        ]
    )

    /// GitHub 规则
    static let githubRule = PageCacheRule(
        id: "preset-github",
        name: "GitHub",
        includePatterns: ["https://github.com/**"],
        excludePatterns: []
    )

    /// 所有预设规则
    static let presetRules: [PageCacheRule] = [
        baiduRule,
        vipVideoRule,
        githubRule
    ]
}
