//
//  URLRuleMatcher.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

// MARK: - MatchType

/// 匹配类型
public enum MatchType: Int, Comparable, Codable {
    case exact = 5        // 精确匹配（最高优先级）
    case domain = 4       // 域名匹配
    case pathPrefix = 3   // 路径前缀匹配
    case glob = 2         // Glob 模式
    case regex = 1        // 正则表达式

    public static func < (lhs: MatchType, rhs: MatchType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ManifestCacheRule

/// Manifest 缓存规则
public struct ManifestCacheRule: Codable, Identifiable {
    public let id: String
    public var name: String
    public var matchType: MatchType
    public var pattern: String
    public var manifestURL: URL
    public var priority: Int
    public var isEnabled: Bool

    public init(
        id: String? = nil,
        name: String,
        matchType: MatchType,
        pattern: String,
        manifestURL: URL,
        priority: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.matchType = matchType
        self.pattern = pattern
        self.manifestURL = manifestURL
        self.priority = priority
        self.isEnabled = isEnabled
    }

    /// 检查 URL 是否匹配此规则
    public func matches(url: URL) -> Bool {
        guard isEnabled else { return false }

        switch matchType {
        case .exact:
            return url.absoluteString == pattern
        case .domain:
            return matchesDomain(url: url)
        case .pathPrefix:
            return url.path.hasPrefix(pattern)
        case .glob:
            return GlobPattern.matches(pattern, against: url.absoluteString)
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(url.absoluteString.startIndex..., in: url.absoluteString)
            return regex.firstMatch(in: url.absoluteString, range: range) != nil
        }
    }

    private func matchesDomain(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == pattern || host.hasSuffix("." + pattern)
    }
}

// MARK: - MatchResult

/// 匹配结果
public struct MatchResult {
    public let ruleId: String
    public let matchType: MatchType
    public let manifestURL: URL
    public let priority: Int

    public init(ruleId: String, matchType: MatchType, manifestURL: URL, priority: Int) {
        self.ruleId = ruleId
        self.matchType = matchType
        self.manifestURL = manifestURL
        self.priority = priority
    }
}

// MARK: - URLRuleMatcher

/// URL 规则匹配器 - 单例模式
public class URLRuleMatcher {

    // MARK: - Singleton

    public static let shared = URLRuleMatcher()

    private init() {}

    // MARK: - Properties

    private var rules: [ManifestCacheRule] = []
    private let queue = DispatchQueue(label: "com.webbridgekit.urlrulematcher")
    private var regexCache: [String: NSRegularExpression] = [:]
    private let cacheQueue = DispatchQueue(label: "com.webbridgekit.urlrulematcher.cache")

    // MARK: - Public Methods

    /// 匹配 URL
    public func match(url: URL) -> MatchResult? {
        return queue.sync {
            // 找出所有匹配的规则
            let matchingRules = rules.filter { $0.matches(url: url) }

            guard !matchingRules.isEmpty else { return nil }

            // 按优先级排序
            let sorted = matchingRules.sorted { rule1, rule2 in
                if rule1.priority != rule2.priority {
                    return rule1.priority > rule2.priority
                }
                return rule1.matchType > rule2.matchType
            }

            let best = sorted.first!
            return MatchResult(
                ruleId: best.id,
                matchType: best.matchType,
                manifestURL: best.manifestURL,
                priority: best.priority
            )
        }
    }

    /// 添加域名规则
    public func addDomainRule(
        name: String,
        domain: String,
        manifestURL: URL,
        priority: Int = 100
    ) {
        let rule = ManifestCacheRule(
            name: name,
            matchType: .domain,
            pattern: domain,
            manifestURL: manifestURL,
            priority: priority
        )
        addRule(rule)
    }

    /// 添加路径前缀规则
    public func addPathPrefixRule(
        name: String,
        pathPrefix: String,
        manifestURL: URL,
        priority: Int = 90
    ) {
        let rule = ManifestCacheRule(
            name: name,
            matchType: .pathPrefix,
            pattern: pathPrefix,
            manifestURL: manifestURL,
            priority: priority
        )
        addRule(rule)
    }

    /// 添加 Glob 规则
    public func addGlobRule(
        name: String,
        globPattern: String,
        manifestURL: URL,
        priority: Int = 80
    ) {
        let rule = ManifestCacheRule(
            name: name,
            matchType: .glob,
            pattern: globPattern,
            manifestURL: manifestURL,
            priority: priority
        )
        addRule(rule)
    }

    /// 添加精确匹配规则
    public func addExactRule(
        name: String,
        url: String,
        manifestURL: URL,
        priority: Int = 100
    ) {
        let rule = ManifestCacheRule(
            name: name,
            matchType: .exact,
            pattern: url,
            manifestURL: manifestURL,
            priority: priority
        )
        addRule(rule)
    }

    /// 添加正则表达式规则
    public func addRegexRule(
        name: String,
        regexPattern: String,
        manifestURL: URL,
        priority: Int = 70
    ) {
        let rule = ManifestCacheRule(
            name: name,
            matchType: .regex,
            pattern: regexPattern,
            manifestURL: manifestURL,
            priority: priority
        )
        addRule(rule)
    }

    /// 添加规则
    public func addRule(_ rule: ManifestCacheRule) {
        queue.async { [weak self] in
            self?.rules.append(rule)
        }
    }

    /// 批量添加规则
    public func addRules(_ newRules: [ManifestCacheRule]) {
        queue.async { [weak self] in
            self?.rules.append(contentsOf: newRules)
        }
    }

    /// 移除规则
    public func removeRule(id: String) {
        queue.async { [weak self] in
            self?.rules.removeAll { $0.id == id }
        }
    }

    /// 更新规则
    public func updateRule(_ rule: ManifestCacheRule) {
        queue.async { [weak self] in
            if let index = self?.rules.firstIndex(where: { $0.id == rule.id }) {
                self?.rules[index] = rule
            }
        }
    }

    /// 获取所有规则
    public func getAllRules() -> [ManifestCacheRule] {
        return queue.sync {
            return rules
        }
    }

    /// 获取规则
    public func getRule(id: String) -> ManifestCacheRule? {
        return queue.sync {
            return rules.first { $0.id == id }
        }
    }

    /// 清空所有规则
    public func clearAllRules() {
        queue.async { [weak self] in
            self?.rules.removeAll()
        }
    }

    /// 启用/禁用规则
    public func setRuleEnabled(id: String, enabled: Bool) {
        queue.async { [weak self] in
            if let index = self?.rules.firstIndex(where: { $0.id == id }) {
                self?.rules[index].isEnabled = enabled
            }
        }
    }

    // MARK: - Private Methods

    private func getCachedRegex(pattern: String) -> NSRegularExpression? {
        var regex: NSRegularExpression?

        cacheQueue.sync {
            regex = regexCache[pattern]
        }

        if let cached = regex {
            return cached
        }

        do {
            let newRegex = try NSRegularExpression(pattern: pattern)
            cacheQueue.async { [weak self] in
                self?.regexCache[pattern] = newRegex
            }
            return newRegex
        } catch {
            return nil
        }
    }
}
