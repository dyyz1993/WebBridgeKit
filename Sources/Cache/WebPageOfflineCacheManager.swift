//
//  WebPageOfflineCacheManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

// Framework imports

/// 离线缓存管理器
/// 负责页面的缓存、删除、刷新等操作
public class WebPageOfflineCacheManager {

    public static let shared = WebPageOfflineCacheManager()

    private let parser = HTMLResourceParser()
    private let downloader = ResourceDownloader()

    private let cacheBaseDirectory: URL = {
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheBase.appendingPathComponent("WebPageCache")
    }()

    private let realmConfiguration: Realm.Configuration

    private init() {
        self.realmConfiguration = WebPageHistoryManager.shared.realmConfiguration

        // 确保缓存目录存在
        try? FileManager.default.createDirectory(at: cacheBaseDirectory, withIntermediateDirectories: true)
    }

    /// 获取 Realm 实例（同步）
    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    /// 获取 Realm 实例（异步）
    private func asyncRealm() async throws -> Realm {
        return try await Realm(configuration: realmConfiguration)
    }

    // MARK: - 缓存操作

    /// 缓存页面（包含所有资源）
    /// - Parameters:
    ///   - history: 历史记录对象
    ///   - progress: 进度回调 (0.0 - 1.0)
    ///   - completion: 完成回调
    public func cachePage(
        history: WebPageHistory,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                guard let url = URL(string: history.url) else {
                    throw CacheError.invalidURL
                }

                // 1. 创建缓存目录
                let cacheDir = cacheBaseDirectory.appendingPathComponent(history.id)
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                progress(0.1)

                // 2. 下载HTML
                WebBridgeLogger.shared.log(.info, "📥 Downloading HTML from: \(history.url)")
                let html = try await downloader.downloadHTML(from: url)
                progress(0.3)

                // 3. 解析资源URL
                let resources = parser.parseResources(html: html, baseURL: url)
                WebBridgeLogger.shared.log(.info, "🔍 Found \(resources.count) resources")
                progress(0.4)

                // 4. 下载资源（并发）
                let resourceMap = try await downloader.downloadResources(
                    resources,
                    to: cacheDir.appendingPathComponent("resources"),
                    progress: { p in
                        Task { @MainActor in
                            progress(0.4 + p * 0.5)
                        }
                    }
                )
                progress(0.9)

                // 5. 重写HTML中的URL
                let rewrittenHTML = parser.rewriteURLs(html: html, baseURL: url, uuid: history.id)

                // 6. 保存HTML
                let htmlPath = cacheDir.appendingPathComponent("index.html")
                try rewrittenHTML.write(to: htmlPath, atomically: true, encoding: .utf8)

                // 7. 生成缩略图（可选）
                // 注意: 生成页面缩略图需要使用 WKWebView 的 snapshot 功能
                // 这需要在主线程创建 WebView，加载 HTML，然后截取快照
                // 由于涉及异步操作和内存开销，这里暂时不实现
                // 未来可以通过 WebPageThumbnailGenerator 来实现

                // 8. 更新Realm记录
                let realm = try await asyncRealm()
                try await realm.write {
                    if let cachedHistory = realm.object(ofType: WebPageHistory.self, forPrimaryKey: history.id) {
                        cachedHistory.htmlPath = htmlPath.path
                        cachedHistory.resourcePaths.removeAll()
                        cachedHistory.resourcePaths.append(objectsIn: resourceMap.values)
                        cachedHistory.cachedSize = calculateDirectorySize(cacheDir)
                        cachedHistory.isCached = true
                        cachedHistory.cacheDate = Date()
                        // 保存规则关联信息
                        cachedHistory.ruleId = history.ruleId
                        cachedHistory.ruleName = history.ruleName
                    }
                }

                progress(1.0)
                WebBridgeLogger.shared.log(.info, "✅ Page cached successfully: \(history.url)")

                completion(.success(()))
            } catch {
                WebBridgeLogger.shared.log(.error, "❌ Failed to cache page: \(error.localizedDescription)")

                // 清理失败的缓存
                try? FileManager.default.removeItem(at: cacheBaseDirectory.appendingPathComponent(history.id))

                completion(.failure(error))
            }
        }
    }

    /// 删除缓存
    /// - Parameters:
    ///   - history: 历史记录对象
    ///   - realm: 可选的 Realm 实例，如果已在事务中，请传入该实例
    /// 删除特定历史记录对应的缓存
    /// - Parameters:
    ///   - history: 历史记录对象
    ///   - realm: 可选的 Realm 实例（用于事务嵌套）
    public func deleteCache(history: WebPageHistory, realm: Realm? = nil) {
        let historyId = history.id
        let cacheDir = history.cacheDirectory

        // 1. 删除物理文件 (IO 操作，不依赖 Realm 线程)
        if let dir = cacheDir {
            try? FileManager.default.removeItem(at: dir)
        }

        // 2. 更新数据库状态 (必须在 Realm 实例所属线程执行)
        let currentRealm = realm ?? getRealm()
        guard let r = currentRealm else { return }

        let updateLogic = {
            if let cachedHistory = r.object(ofType: WebPageHistory.self, forPrimaryKey: historyId) {
                cachedHistory.htmlPath = nil
                cachedHistory.resourcePaths.removeAll()
                cachedHistory.cachedSize = 0
                cachedHistory.isCached = false
                cachedHistory.cacheDate = nil
            }
        }

        if r.isInWriteTransaction {
            updateLogic()
        } else {
            try? r.write {
                updateLogic()
            }
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Cache deleted for ID: \(historyId)")
    }

    /// 刷新缓存（重新下载）
    func refreshCache(
        history: WebPageHistory,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 先删除旧缓存
        deleteCache(history: history)

        // 重新缓存
        cachePage(history: history, progress: progress, completion: completion)
    }

    /// 清理所有缓存
    func clearAllCache() {
        let realm = getRealm()
        let cachedHistories = realm?.objects(WebPageHistory.self).filter("isCached == true")

        if let r = realm, let histories = cachedHistories {
            try? r.write {
                histories.forEach { history in
                    deleteCache(history: history, realm: r)
                }
            }
        }

        WebBridgeLogger.shared.log(.info, "🧹 All caches cleared")
    }

    /// 获取缓存总大小
    func getTotalCacheSize() -> Int64 {
        let realm = getRealm()
        return realm?.objects(WebPageHistory.self)
            .filter("isCached == true")
            .sum(ofProperty: "cachedSize") ?? 0
    }

    /// 获取已缓存的数量
    func getCachedCount() -> Int {
        let realm = getRealm()
        return realm?.objects(WebPageHistory.self)
            .filter("isCached == true")
            .count ?? 0
    }

    /// LRU清理：删除最旧的缓存
    func cleanupLRU(maxCount: Int = 20) {
        let realm = getRealm()
        let histories = realm?.objects(WebPageHistory.self)
            .filter("isCached == true")
            .sorted(byKeyPath: "lastVisitDate", ascending: true)

        if let histories = histories, histories.count > maxCount {
            let toDelete = Array(histories.prefix(histories.count - maxCount))

            if let r = realm {
                try? r.write {
                    for history in toDelete {
                        deleteCache(history: history, realm: r)
                    }
                }
            }

            WebBridgeLogger.shared.log(.info, "🧹 LRU cleanup: removed \(toDelete.count) old caches")
        }
    }

    // MARK: - Helper

    private func calculateDirectorySize(_ directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        return totalSize
    }

    // MARK: - Rule-Driven Caching
}

extension WebPageOfflineCacheManager {

    /// 根据规则缓存页面
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - rule: 页面缓存规则
    ///   - progress: 进度回调 (0.0 - 1.0)
    ///   - completion: 完成回调，返回 CachedPageInfo
    public func cachePage(
        url: URL,
        rule: PageCacheRule,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<CachedPageInfo, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                // 1. 检查 URL 是否被排除
                if !rule.matches(url: url) {
                    completion(.failure(CacheError.ruleMatchFailed))
                    return
                }

                // 2. 查找或创建 WebPageHistory，并设置规则信息
                let realm = try await asyncRealm()
                let historyId = url.sha256

                try await realm.write {
                    let history: WebPageHistory
                    if let existingHistory = realm.object(ofType: WebPageHistory.self, forPrimaryKey: historyId) {
                        history = existingHistory
                    } else {
                        history = WebPageHistory()
                        history.id = historyId
                        history.url = url.absoluteString
                        history.title = url.host ?? "Unknown"
                        realm.add(history)
                    }

                    // 设置关联的规则信息（在写事务内）
                    history.ruleId = rule.id
                    history.ruleName = rule.name
                }

                // 3. 重新从数据库获取对象（用于后续操作）
                guard let historyObject = realm.object(ofType: WebPageHistory.self, forPrimaryKey: historyId) else {
                    completion(.failure(CacheError.invalidURL))
                    return
                }

                // 4. 使用现有缓存逻辑
                cachePage(history: historyObject) { p in
                    progress(p)
                } completion: { result in
                    switch result {
                    case .success:
                        // 5. 获取资源统计
                        let resourceCount = self.getResourceCount(for: historyId)
                        let totalSize = self.getCachedSize(for: historyId)

                        // 6. 创建 CachedPageInfo
                        let pageInfo = CachedPageInfo(
                            id: historyId,
                            url: url.absoluteString,
                            title: historyObject.title ?? url.host ?? "Unknown",
                            ruleId: rule.id,
                            ruleName: rule.name,
                            resourceCount: resourceCount,
                            totalSize: totalSize,
                            cachedAt: Date(),
                            isOfflineAvailable: true,
                            isExcluded: false
                        )

                        // 6. 更新规则的最后缓存时间
                        var updatedRule = rule
                        updatedRule.lastCachedAt = Date()
                        _ = PageCacheRuleManager.shared.updateRule(updatedRule)

                        WebBridgeLogger.shared.info("✅ Page cached by rule '\(rule.name)': \(url.absoluteString)")
                        completion(.success(pageInfo))

                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// 获取所有已缓存的页面
    public func getCachedPages() -> [CachedPageInfo] {
        guard let realm = getRealm() else { return [] }

        return realm.objects(WebPageHistory.self)
            .filter("isCached == true")
            .sorted(byKeyPath: "cacheDate", ascending: false)
            .compactMap { history -> CachedPageInfo? in
                guard let url = URL(string: history.url) else { return nil }

                // 查找关联的规则
                let ruleId = history.ruleId ?? ""
                let ruleName = history.ruleName ?? "未分类"

                return CachedPageInfo(
                    id: history.id,
                    url: history.url,
                    title: history.title ?? url.host ?? "Unknown",
                    ruleId: ruleId,
                    ruleName: ruleName,
                    resourceCount: getResourceCount(for: history.id),
                    totalSize: history.cachedSize,
                    cachedAt: history.cacheDate ?? Date(),
                    isOfflineAvailable: true,
                    isExcluded: false
                )
            }
    }

    /// 获取规则下的所有缓存页面
    public func getCachedPages(for ruleId: String) -> [CachedPageInfo] {
        return getCachedPages().filter { $0.ruleId == ruleId }
    }

    /// 刷新已缓存的页面
    public func refreshCachedPage(
        pageId: String,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let realm = getRealm(),
              let history = realm.object(ofType: WebPageHistory.self, forPrimaryKey: pageId),
              let url = URL(string: history.url) else {
            completion(.failure(CacheError.invalidURL))
            return
        }

        // 如果有规则，使用规则刷新
        if let ruleId = history.ruleId,
           let rule = PageCacheRuleManager.shared.getAllRules().first(where: { $0.id == ruleId }) {
            cachePage(url: url, rule: rule, progress: progress) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            // 没有规则，使用普通刷新
            refreshCache(history: history, progress: progress, completion: completion)
        }
    }

    /// 删除已缓存的页面
    public func deleteCachedPage(pageId: String) -> Bool {
        guard let realm = getRealm(),
              let history = realm.object(ofType: WebPageHistory.self, forPrimaryKey: pageId) else {
            return false
        }

        deleteCache(history: history)
        return true
    }

    // MARK: - Helper Methods

    /// 获取缓存页面的资源数量
    private func getResourceCount(for pageId: String) -> Int {
        guard let realm = getRealm(),
              let history = realm.object(ofType: WebPageHistory.self, forPrimaryKey: pageId) else {
            return 0
        }
        return history.resourcePaths.count
    }

    /// 获取缓存页面的实际大小
    private func getCachedSize(for pageId: String) -> Int64 {
        guard let cacheDir = cacheBaseDirectory.appendingPathComponent(pageId) as URL? else {
            return 0
        }
        return calculateDirectorySize(cacheDir)
    }

    enum CacheError: Error, LocalizedError {
        case invalidURL
        case downloadFailed
        case ruleMatchFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .downloadFailed: return "Download failed"
            case .ruleMatchFailed: return "Rule does not match this URL"
            }
        }
    }
}
