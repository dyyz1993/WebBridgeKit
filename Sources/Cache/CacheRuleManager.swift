//
//  CacheRuleManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 缓存规则管理器（简化版本，用于调试功能）
public class CacheRuleManager {

    // MARK: - Singleton

    public static let shared = CacheRuleManager()

    private init() {}

    // MARK: - Properties

    private var rules: [CacheRule] = []
    private let queue = DispatchQueue(label: "com.webbridgekit.cacherulemanager")

    // MARK: - Public Methods

    /// 检查 URL 是否应该被缓存
    public func shouldCache(url: URL) -> (Bool, CacheRule?) {
        return queue.sync {
            for rule in rules where rule.isEnabled {
                if rule.matches(url: url) {
                    return (true, rule)
                }
            }
            return (false, nil)
        }
    }

    /// 添加规则
    public func addRule(_ rule: CacheRule) {
        queue.async { [weak self] in
            self?.rules.append(rule)
        }
    }

    /// 移除规则
    public func removeRule(id: String) {
        queue.async { [weak self] in
            self?.rules.removeAll { $0.id == id }
        }
    }

    /// 获取所有规则
    public func getAllRules() -> [CacheRule] {
        return queue.sync {
            return rules
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

    /// 更新规则
    public func updateRule(id: String, name: String? = nil, enabled: Bool? = nil) {
        queue.async { [weak self] in
            guard let index = self?.rules.firstIndex(where: { $0.id == id }) else { return }
            if let name = name {
                self?.rules[index].name = name
            }
            if let enabled = enabled {
                self?.rules[index].isEnabled = enabled
            }
        }
    }

    /// 删除规则（返回 Bool）
    public func deleteRule(ruleId: String) -> Bool {
        var result = false
        queue.sync {
            if let index = rules.firstIndex(where: { $0.id == ruleId }) {
                rules.remove(at: index)
                result = true
            }
        }
        return result
    }

    /// 重置为预设规则（返回 Bool）
    public func resetToPresetRules() -> Bool {
        queue.sync { [weak self] in
            self?.rules.removeAll()
            // 可以添加默认规则
        }
        return true
    }

    /// 按规则删除缓存（返回 Bool）
    public func deleteCacheByRule(rule: CacheRule) -> Bool {
        return deleteRule(ruleId: rule.id)
    }
}
