//
//  WebCacheDebugHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

/// 缓存调试 Handler
/// 提供 JS Bridge API 用于查询和管理压缩缓存、页面级离线缓存
public class WebCacheDebugHandler: BaseWebNativeHandler {

    // MARK: - Handle Method

    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? ""

        switch action {
        // MARK: - 压缩缓存相关 (保留)
        case "getInfo", "getCacheInfo":
            getCacheInfo(completion: completion)
        case "getMemoryInfo":
            getMemoryInfo(completion: completion)
        case "getEntries":
            let filter = params["filter"] as? String
            getEntries(filter: filter, completion: completion)
        case "getEntriesGroupedByDomain":
            getEntriesGroupedByDomain(completion: completion)
        case "isCached":
            if let urlString = params["url"] as? String,
               let url = URL(string: urlString) {
                checkIsCached(url: url, completion: completion)
            } else {
                reject(error: "Invalid URL", completion: completion)
            }
        case "deleteByPattern", "deleteByGlob":
            if let pattern = params["pattern"] as? String {
                deleteByPattern(pattern: pattern, completion: completion)
            } else {
                reject(error: "Pattern is required", completion: completion)
            }
        case "deleteByKey":
            if let key = params["key"] as? String {
                deleteByKey(key: key, completion: completion)
            } else {
                reject(error: "Key is required", completion: completion)
            }
        case "clearAll":
            clearAll(completion: completion)
        case "getConfig":
            getConfig(completion: completion)
        case "setConfig":
            if let configParams = params["config"] as? [String: Any] {
                setConfig(configParams: configParams, completion: completion)
            } else {
                reject(error: "Config is required", completion: completion)
            }

        // MARK: - 页面缓存规则管理
        case "getPageRules":
            getPageRules(completion: completion)
        case "addPageRule":
            if let ruleParams = params["rule"] as? [String: Any] {
                addPageRule(ruleParams: ruleParams, completion: completion)
            } else {
                reject(error: "Rule is required", completion: completion)
            }
        case "updatePageRule":
            if let ruleParams = params["rule"] as? [String: Any] {
                updatePageRule(ruleParams: ruleParams, completion: completion)
            } else {
                reject(error: "Rule is required", completion: completion)
            }
        case "deletePageRule":
            if let ruleId = params["ruleId"] as? String {
                deletePageRule(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "clearAllPageRules":
            clearAllPageRules(completion: completion)
        case "resetToPresetPageRules":
            resetToPresetPageRules(completion: completion)
        case "addExcludePattern":
            if let ruleId = params["ruleId"] as? String,
               let pattern = params["pattern"] as? String {
                addExcludePattern(ruleId: ruleId, pattern: pattern, completion: completion)
            } else {
                reject(error: "Rule ID and pattern are required", completion: completion)
            }
        case "removeExcludePattern":
            if let ruleId = params["ruleId"] as? String,
               let pattern = params["pattern"] as? String {
                removeExcludePattern(ruleId: ruleId, pattern: pattern, completion: completion)
            } else {
                reject(error: "Rule ID and pattern are required", completion: completion)
            }

        // MARK: - 页面缓存操作
        case "getCachedPages":
            let ruleId = params["ruleId"] as? String
            getCachedPages(ruleId: ruleId, completion: completion)
        case "cachePage":
            if let urlString = params["url"] as? String,
               let url = URL(string: urlString),
               let ruleId = params["ruleId"] as? String {
                cachePage(url: url, ruleId: ruleId, completion: completion)
            } else {
                reject(error: "URL and ruleId are required", completion: completion)
            }
        case "refreshCachedPage":
            if let pageId = params["pageId"] as? String {
                refreshCachedPage(pageId: pageId, completion: completion)
            } else {
                reject(error: "Page ID is required", completion: completion)
            }
        case "deleteCachedPage":
            if let pageId = params["pageId"] as? String {
                deleteCachedPage(pageId: pageId, completion: completion)
            } else {
                reject(error: "Page ID is required", completion: completion)
            }

        // MARK: - 旧系统规则管理 (保留向后兼容)
        case "getRules":
            getRules(completion: completion)
        case "addRule":
            if let ruleParams = params["rule"] as? [String: Any] {
                addRule(ruleParams: ruleParams, completion: completion)
            } else {
                reject(error: "Rule is required", completion: completion)
            }
        case "updateRule":
            if let ruleId = params["ruleId"] as? String {
                let enabled = params["enabled"] as? Bool
                updateRule(ruleId: ruleId, enabled: enabled, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "deleteRule":
            if let ruleId = params["ruleId"] as? String {
                deleteRule(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "clearAllRules":
            clearAllRules(completion: completion)
        case "resetToPresetRules":
            resetToPresetRules(completion: completion)
        case "getRuleCache":
            if let ruleId = params["ruleId"] as? String {
                getRuleCache(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        case "deleteRuleCache":
            if let ruleId = params["ruleId"] as? String {
                deleteRuleCache(ruleId: ruleId, completion: completion)
            } else {
                reject(error: "Rule ID is required", completion: completion)
            }
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }
}
