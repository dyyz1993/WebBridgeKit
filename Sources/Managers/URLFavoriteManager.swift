//
//  URLFavoriteManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// URL 收藏管理器
/// 负责收藏的增删改查、置顶、排序、缓存模式管理
public class URLFavoriteManager {

    public static let shared = URLFavoriteManager()

    private let realmConfiguration: Realm.Configuration

    private init() {
        // 使用独立的 Realm 文件
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("urlFavorite.realm"),
            schemaVersion: 1
        )
    }

    /// 获取 Realm 实例
    private func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    // MARK: - 添加/更新

    /// 添加收藏
    /// - Parameters:
    ///   - url: 页面URL
    ///   - title: 页面标题（可选）
    ///   - favicon: 页面图标（可选）
    /// - Returns: 创建的收藏对象
    @discardableResult
    public func addFavorite(url: URL, title: String? = nil, favicon: Data? = nil) -> URLFavorite? {
        let realm = getRealm()
        let urlString = url.absoluteString

        // 检查是否已存在
        if let existing = findFavorite(url: url) {
            WebBridgeLogger.shared.log(.debug, "⚠️ Favorite already exists: \(urlString)")
            // 更新标题和图标
            try? realm?.write {
                if let title = title {
                    existing.title = title
                }
                if let favicon = favicon {
                    existing.favicon = favicon
                }
            }
            return existing
        }

        let favorite = URLFavorite()
        favorite.url = urlString
        favorite.title = title ?? url.host
        favorite.favicon = favicon
        favorite.createdAt = Date()
        favorite.sortOrder = getAllFavorites().count

        try? realm?.write {
            realm?.add(favorite)
        }

        WebBridgeLogger.shared.log(.info, "➕ Favorite added: \(urlString)")
        return favorite
    }

    /// 更新收藏
    func updateFavorite(_ favorite: URLFavorite) {
        let realm = getRealm()
        try? realm?.write {
            realm?.add(favorite, update: .modified)
        }
        WebBridgeLogger.shared.log(.debug, "♻️ Favorite updated: \(favorite.id)")
    }

    // MARK: - 删除

    /// 删除收藏
    public func deleteFavorite(id: String) {
        let realm = getRealm()
        guard let favorite = realm?.object(ofType: URLFavorite.self, forPrimaryKey: id) else { return }

        try? realm?.write {
            realm?.delete(favorite)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Favorite deleted: \(id)")
    }

    /// 删除收藏（根据URL）
    public func deleteFavorite(url: URL) {
        guard let favorite = findFavorite(url: url) else { return }
        deleteFavorite(id: favorite.id)
    }

    // MARK: - 查询

    /// 获取所有收藏（按置顶和排序）
    public func getAllFavorites() -> Results<URLFavorite> {
        guard let realm = getRealm() else {
            let config = Realm.Configuration(inMemoryIdentifier: "EmptyResults_\(UUID().uuidString)")
            let tempRealm = try! Realm(configuration: config)
            return tempRealm.objects(URLFavorite.self).filter("FALSEPREDICATE")
        }
        return realm.objects(URLFavorite.self)
            .sorted(by: [
                SortDescriptor(keyPath: "isPinned", ascending: false),
                SortDescriptor(keyPath: "sortOrder", ascending: true)
            ])
    }

    /// 根据URL查找收藏
    public func findFavorite(url: URL) -> URLFavorite? {
        guard let urlString = url.absoluteString as String? else { return nil }
        let realm = getRealm()
        let predicate = NSPredicate(format: "url == %@", urlString)
        return realm?.objects(URLFavorite.self).filter(predicate).first
    }

    /// 根据ID查找收藏
    func findFavorite(id: String) -> URLFavorite? {
        let realm = getRealm()
        return realm?.object(ofType: URLFavorite.self, forPrimaryKey: id)
    }

    /// 搜索收藏（标题或URL包含关键词）
    func searchFavorites(keyword: String) -> Results<URLFavorite> {
        guard let realm = getRealm() else {
            let config = Realm.Configuration(inMemoryIdentifier: "EmptyResults_\(UUID().uuidString)")
            let tempRealm = try! Realm(configuration: config)
            return tempRealm.objects(URLFavorite.self).filter("FALSEPREDICATE")
        }
        return realm.objects(URLFavorite.self)
            .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
            .sorted(by: [
                SortDescriptor(keyPath: "isPinned", ascending: false),
                SortDescriptor(keyPath: "sortOrder", ascending: true)
            ])
    }

    /// 获取收藏总数
    func getTotalCount() -> Int {
        let realm = getRealm()
        return realm?.objects(URLFavorite.self).count ?? 0
    }

    // MARK: - 特殊操作

    /// 切换置顶状态
    /// - Parameter id: 收藏ID
    /// - Returns: 切换后的置顶状态
    @discardableResult
    public func togglePin(id: String) -> Bool {
        let realm = getRealm()
        guard let favorite = realm?.object(ofType: URLFavorite.self, forPrimaryKey: id) else { return false }

        try? realm?.write {
            favorite.isPinned.toggle()
        }

        WebBridgeLogger.shared.log(.info, favorite.isPinned ? "📌 Favorite pinned: \(id)" : "📍 Favorite unpinned: \(id)")
        return favorite.isPinned
    }

    /// 更新缓存模式
    public func updateCacheMode(id: String, enabled: Bool) {
        let realm = getRealm()
        guard let favorite = realm?.object(ofType: URLFavorite.self, forPrimaryKey: id) else { return }

        try? realm?.write {
            favorite.enableCacheMode = enabled
        }

        WebBridgeLogger.shared.log(.info, "\(enabled ? "✅" : "❌") Cache mode \(enabled ? "enabled" : "disabled"): \(id)")
    }

    /// 更新排序顺序
    public func updateSortOrder(favorites: [URLFavorite]) {
        let realm = getRealm()
        try? realm?.write {
            for (index, favorite) in favorites.enumerated() {
                favorite.sortOrder = index
            }
        }
        WebBridgeLogger.shared.log(.debug, "♻️ Sort order updated")
    }
}
