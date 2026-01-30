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
    public func addOrUpdateHistory(url: URL, title: String? = nil) {
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
                if let title = title, existing.title == nil {
                    existing.title = title
                }
            }
            WebBridgeLogger.shared.log(.debug, "♻️ History updated: \(urlString)")
        } else {
            // 创建新记录
            let history = WebPageHistory()
            history.url = urlString
            history.title = title
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

    /// 清空所有历史
    func clearAllHistory() {
        let realm = getRealm()

        // 先清理所有缓存
        WebPageOfflineCacheManager.shared.clearAllCache()

        // 删除所有历史记录
        try? realm?.write {
            let histories = realm?.objects(WebPageHistory.self)
            if let histories = histories {
                realm?.delete(histories)
            }
        }

        WebBridgeLogger.shared.log(.info, "🧹 All history cleared")
    }

    // MARK: - 查询

    /// 获取所有历史记录（按最后访问时间降序）
    public func getAllHistories() -> Results<WebPageHistory> {
        guard let realm = getRealm() else {
            // Return empty Results if realm is unavailable
            return try! Realm().objects(WebPageHistory.self).filter("FALSEPREDICATE")
        }
        return realm.objects(WebPageHistory.self)
            .sorted(byKeyPath: "lastVisitDate", ascending: false)
    }

    /// 获取已缓存的历史记录
    func getCachedHistories() -> Results<WebPageHistory> {
        guard let realm = getRealm() else {
            return try! Realm().objects(WebPageHistory.self).filter("FALSEPREDICATE")
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
    func findHistory(id: String) -> WebPageHistory? {
        let realm = getRealm()
        return realm?.object(ofType: WebPageHistory.self, forPrimaryKey: id)
    }

    /// 搜索历史记录（标题或URL包含关键词）
    func searchHistories(keyword: String) -> Results<WebPageHistory> {
        guard let realm = getRealm() else {
            return try! Realm().objects(WebPageHistory.self).filter("FALSEPREDICATE")
        }
        return realm.objects(WebPageHistory.self)
            .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
            .sorted(byKeyPath: "lastVisitDate", ascending: false)
    }

    // MARK: - 统计

    /// 获取历史记录总数
    func getTotalCount() -> Int {
        let realm = getRealm()
        return realm?.objects(WebPageHistory.self).count ?? 0
    }

    /// 获取今日访问数
    func getTodayVisitCount() -> Int {
        let realm = getRealm()
        let today = Calendar.current.startOfDay(for: Date())
        return realm?.objects(WebPageHistory.self)
            .filter("lastVisitDate >= %@", today as NSDate)
            .count ?? 0
    }

    /// 获取最常访问的页面（前N个）
    func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
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
