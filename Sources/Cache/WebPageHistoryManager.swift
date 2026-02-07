//
//  WebPageHistoryManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

// Framework imports

/// 历史记录管理器
/// 负责访问历史的追踪、添加、删除、查询
public class WebPageHistoryManager {

    public static let shared = WebPageHistoryManager()

    private let realmConfiguration: Realm.Configuration

    private init() {
        // 使用独立的 Realm 文件以避免与其他 Realm 冲突
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("pageHistory.realm"),
            schemaVersion: 1
        )
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    // MARK: - 添加/更新

    /// 添加或更新历史记录
    /// - Parameters:
    ///   - url: 页面URL
    ///   - title: 页面标题（可选）
    ///   - favicon: 页面图标（可选）
    public func addOrUpdateHistory(url: URL, title: String? = nil, favicon: Data? = nil) {
        guard let urlString = url.absoluteString as String? else { return }

        let realm = getRealm()

        // 查找是否已存在
        let predicate = NSPredicate(format: "url == %@", urlString)
        let existing = realm?.objects(WebPageHistory.self).filter(predicate).first

        if let existing = existing {
            // 更新现有记录
            try? realm?.write {
                existing.lastVisitDate = Date()
                existing.visitCount += 1
                if let title = title {
                    existing.title = title
                }
                if let favicon = favicon {
                    existing.favicon = favicon
                }
            }
            WebBridgeLogger.shared.log(.debug, "♻️ History updated: \(urlString)")
        } else {
            // 创建新记录
            let history = WebPageHistory()
            history.url = urlString
            history.title = title
            history.favicon = favicon
            history.visitCount = 1
            history.lastVisitDate = Date()

            try? realm?.write {
                realm?.add(history)
            }
            WebBridgeLogger.shared.log(.debug, "➕ History added: \(urlString)")
        }
    }

    // MARK: - 删除

    /// 删除历史记录
    public func deleteHistory(id: String) {
        let realm = getRealm()
        guard let history = realm?.object(ofType: WebPageHistory.self, forPrimaryKey: id) else { return }

        // 如果有缓存，先删除缓存
        if history.isCached {
            WebPageOfflineCacheManager.shared.deleteCache(history: history)
        }

        try? realm?.write {
            realm?.delete(history)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ History deleted: \(id)")
    }

    /// 清空所有历史（保留收藏和置顶项）
    public func clearAllHistory() {
        let realm = getRealm()

        // 查找非收藏且非置顶的项目
        let predicate = NSPredicate(format: "isFavorite == false AND isPinned == false")
        let itemsToDelete = realm?.objects(WebPageHistory.self).filter(predicate)

        try? realm?.write {
            if let items = itemsToDelete {
                for item in items {
                    // 如果有缓存，先删除缓存
                    if item.isCached {
                        WebPageOfflineCacheManager.shared.deleteCache(history: item)
                    }
                }
                realm?.delete(items)
            }
        }
        
        WebBridgeLogger.shared.log(.info, "🗑️ Non-favorite/pinned history cleared")
    }

    /// 清理低频访问项（仅针对非收藏和非置顶项）
    /// 当历史记录超过 limit 时，删除访问次数最少的项
    public func cleanupLowFrequencyItems(limit: Int = 100) {
        guard let realm = getRealm() else { return }
        
        // 仅筛选非收藏且非置顶的项目进行清理
        let predicate = NSPredicate(format: "isFavorite == false AND isPinned == false")
        let removableItems = realm.objects(WebPageHistory.self).filter(predicate)
        
        if removableItems.count <= limit { return }
        
        let toDeleteCount = removableItems.count - limit
        // 按照最后访问时间升序排列（最旧的在前），取前 toDeleteCount 个进行删除
        let itemsToDelete = removableItems.sorted(byKeyPath: "lastVisitDate", ascending: true).prefix(toDeleteCount)
        
        try? realm.write {
            for item in itemsToDelete {
                // 如果有缓存，先删除缓存
                if item.isCached {
                    WebPageOfflineCacheManager.shared.deleteCache(history: item)
                }
                realm.delete(item)
            }
        }
        
        WebBridgeLogger.shared.log(.info, "🧹 Cleaned up \(toDeleteCount) low-frequency history items (protected favorites/pinned)")
    }

    // MARK: - 查询

    /// 获取所有历史记录（按最后访问时间降序）
    public func getAllHistories() -> Results<WebPageHistory> {
        guard let realm = getRealm() else {
            // 使用临时内存 Realm 返回空 Results
            let config = Realm.Configuration(inMemoryIdentifier: "EmptyResults_\(UUID().uuidString)")
            let tempRealm = try! Realm(configuration: config)
            return tempRealm.objects(WebPageHistory.self).filter("FALSEPREDICATE")
        }
        return realm.objects(WebPageHistory.self)
            .sorted(byKeyPath: "lastVisitDate", ascending: false)
    }

    /// 获取已缓存的历史记录
    public func getCachedHistories() -> Results<WebPageHistory> {
        guard let realm = getRealm() else {
            let config = Realm.Configuration(inMemoryIdentifier: "EmptyResults_\(UUID().uuidString)")
            let tempRealm = try! Realm(configuration: config)
            return tempRealm.objects(WebPageHistory.self).filter("FALSEPREDICATE")
        }
        return realm.objects(WebPageHistory.self)
            .filter("isCached == true")
            .sorted(byKeyPath: "cacheDate", ascending: false)
    }

    /// 根据URL查找历史记录
    public func findHistory(url: URL) -> WebPageHistory? {
        guard let urlString = url.absoluteString as String? else { return nil }
        let realm = getRealm()
        let predicate = NSPredicate(format: "url == %@", urlString)
        return realm?.objects(WebPageHistory.self).filter(predicate).first
    }

    /// 根据ID查找历史记录
    public func findHistory(id: String) -> WebPageHistory? {
        let realm = getRealm()
        return realm?.object(ofType: WebPageHistory.self, forPrimaryKey: id)
    }

    /// 搜索历史记录（标题或URL包含关键词）
    public func searchHistories(keyword: String) -> Results<WebPageHistory> {
        guard let realm = getRealm() else {
            let config = Realm.Configuration(inMemoryIdentifier: "EmptyResults_\(UUID().uuidString)")
            let tempRealm = try! Realm(configuration: config)
            return tempRealm.objects(WebPageHistory.self).filter("FALSEPREDICATE")
        }
        return realm.objects(WebPageHistory.self)
            .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
            .sorted(byKeyPath: "lastVisitDate", ascending: false)
    }

    // MARK: - 统计

    /// 获取历史记录总数
    public func getTotalCount() -> Int {
        let realm = getRealm()
        return realm?.objects(WebPageHistory.self).count ?? 0
    }

    /// 获取今日访问数
    public func getTodayVisitCount() -> Int {
        let realm = getRealm()
        let today = Calendar.current.startOfDay(for: Date())
        return realm?.objects(WebPageHistory.self)
            .filter("lastVisitDate >= %@", today as NSDate)
            .count ?? 0
    }

    /// 获取最常访问的页面（前N个）
    public func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
        guard let realm = getRealm() else { return [] }
        return Array(realm.objects(WebPageHistory.self)
            .sorted(byKeyPath: "visitCount", ascending: false)
            .prefix(limit))
    }

    /// 清理旧的缩略图，只保留最新的N个
    /// - Parameter keepLatest: 保留的数量
    func cleanOldThumbnails(keepLatest: Int = 100) {
        guard let realm = getRealm() else { return }

        // 获取所有有缩略图的历史记录，按访问时间倒序
        let histories = realm.objects(WebPageHistory.self)
            .filter("thumbnail != nil")
            .sorted(byKeyPath: "lastVisitDate", ascending: false)

        // 超出保留数量的，清除缩略图
        let toClean = Array(histories.dropFirst(keepLatest))

        try? realm.write {
            for history in toClean {
                history.thumbnail = nil
            }
        }

        WebBridgeLogger.shared.log(.info, "🧹 Cleaned \(toClean.count) old thumbnails")
    }
}
