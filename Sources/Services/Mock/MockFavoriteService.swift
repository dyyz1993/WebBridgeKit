//
//  MockFavoriteService.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// Mock 收藏服务
/// 用于测试和开发，提供内存中的数据存储
public class MockFavoriteService: FavoriteServiceProtocol {

    public static let shared = MockFavoriteService()

    /// 内存中的收藏存储
    private var mockFavorites: [String: URLFavorite] = [:]
    /// 是否使用 Realm 内存数据库
    private let useInMemoryRealm: Bool
    /// Realm 配置
    private let realmConfiguration: Realm.Configuration
    /// 共享的 Realm 实例（确保数据一致性）
    private let sharedRealm: Realm?

    /// 指定初始化方法
    /// - Parameter useInMemoryRealm: 是否使用 Realm 内存数据库，默认使用内存字典
    public init(useInMemoryRealm: Bool = false) {
        self.useInMemoryRealm = useInMemoryRealm
        if useInMemoryRealm {
            self.realmConfiguration = Realm.Configuration(inMemoryIdentifier: "MockFavoriteRealm")
            self.sharedRealm = try? Realm(configuration: realmConfiguration)
            print("🔍 [MockFavoriteService] Initialized with in-memory Realm, success: \(sharedRealm != nil)")
        } else {
            self.realmConfiguration = Realm.Configuration(fileURL: URL(fileURLWithPath: "/dev/null/mock.realm"))
            self.sharedRealm = nil
            print("🔍 [MockFavoriteService] Initialized with dictionary storage")
        }
    }

    /// 获取 Realm 实例（仅在使用 in-memory 模式时有效）
    private func getRealm() -> Realm? {
        return sharedRealm
    }

    // MARK: - 添加/更新

    @discardableResult
    public func addFavorite(url: URL, title: String?, favicon: Data?) -> URLFavorite? {
        let urlString = url.absoluteString

        // 检查是否已存在
        if let existing = findFavorite(url: url) {
            if existing.favicon == nil, let favicon = favicon {
                if useInMemoryRealm, let realm = getRealm() {
                    try? realm.write {
                        existing.favicon = favicon
                    }
                } else {
                    existing.favicon = favicon
                }
            }
            return existing
        }

        if useInMemoryRealm, let realm = getRealm() {
            let favorite = URLFavorite()
            favorite.id = UUID().uuidString
            favorite.url = urlString
            favorite.title = title ?? url.host
            favorite.favicon = favicon
            favorite.createdAt = Date()
            favorite.sortOrder = getAllFavorites().count

            try? realm.write {
                realm.add(favorite)
            }

            return favorite
        } else {
            let favorite = URLFavorite()
            favorite.id = UUID().uuidString
            favorite.url = urlString
            favorite.title = title ?? url.host
            favorite.favicon = favicon
            favorite.createdAt = Date()
            favorite.sortOrder = mockFavorites.count

            mockFavorites[favorite.id] = favorite
            return favorite
        }
    }

    public func updateFavorite(_ favorite: URLFavorite) {
        if useInMemoryRealm, let realm = getRealm() {
            try? realm.write {
                realm.add(favorite, update: .modified)
            }
        } else {
            mockFavorites[favorite.id] = favorite
        }
    }

    // MARK: - 删除

    public func deleteFavorite(id: String) {
        if useInMemoryRealm, let realm = getRealm() {
            if let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) {
                try? realm.write {
                    realm.delete(favorite)
                }
            }
        } else {
            mockFavorites.removeValue(forKey: id)
        }
    }

    public func deleteFavorite(url: URL) {
        if let favorite = findFavorite(url: url) {
            deleteFavorite(id: favorite.id)
        }
    }

    // MARK: - 查询

    public func getAllFavorites() -> Results<URLFavorite> {
        if useInMemoryRealm, let realm = getRealm() {
            let results = realm.objects(URLFavorite.self)
                .sorted(by: [
                    SortDescriptor(keyPath: "isPinned", ascending: false),
                    SortDescriptor(keyPath: "sortOrder", ascending: true)
                ])
            print("🔍 [MockFavoriteService] getAllFavorites: useInMemoryRealm=true, count: \(results.count)")
            return results
        }

        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        let emptyRealm = try! Realm(configuration: config)
        print("🔍 [MockFavoriteService] getAllFavorites: useInMemoryRealm=false, returning empty Results")
        return emptyRealm.objects(URLFavorite.self).filter("FALSEPREDICATE")
    }

    /// 获取所有收藏的数组形式（用于 Mock 模式）
    public func getAllFavoritesArray() -> [URLFavorite] {
        if useInMemoryRealm, let realm = getRealm() {
            return Array(realm.objects(URLFavorite.self)
                .sorted(by: [
                    SortDescriptor(keyPath: "isPinned", ascending: false),
                    SortDescriptor(keyPath: "sortOrder", ascending: true)
                ]))
        }

        return Array(mockFavorites.values)
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    public func findFavorite(url: URL) -> URLFavorite? {
        let urlString = url.absoluteString

        if useInMemoryRealm, let realm = getRealm() {
            let predicate = NSPredicate(format: "url == %@", urlString)
            return realm.objects(URLFavorite.self).filter(predicate).first
        }

        return mockFavorites.values.first { $0.url == urlString }
    }

    public func findFavorite(id: String) -> URLFavorite? {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.object(ofType: URLFavorite.self, forPrimaryKey: id)
        }

        return mockFavorites[id]
    }

    public func searchFavorites(keyword: String) -> Results<URLFavorite> {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.objects(URLFavorite.self)
                .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
                .sorted(by: [
                    SortDescriptor(keyPath: "isPinned", ascending: false),
                    SortDescriptor(keyPath: "sortOrder", ascending: true)
                ])
        }

        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        let emptyRealm = try! Realm(configuration: config)
        return emptyRealm.objects(URLFavorite.self).filter("FALSEPREDICATE")
    }

    public func getTotalCount() -> Int {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.objects(URLFavorite.self).count
        }
        return mockFavorites.count
    }

    // MARK: - 特殊操作

    @discardableResult
    public func togglePin(id: String) -> Bool {
        if useInMemoryRealm, let realm = getRealm() {
            guard let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) else { return false }

            try? realm.write {
                favorite.isPinned.toggle()
            }

            return favorite.isPinned
        } else {
            guard let favorite = mockFavorites[id] else { return false }
            favorite.isPinned.toggle()
            return favorite.isPinned
        }
    }

    public func updateCacheMode(id: String, enabled: Bool) {
        if useInMemoryRealm, let realm = getRealm() {
            guard let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) else { return }

            try? realm.write {
                favorite.enableCacheMode = enabled
            }
        } else {
            mockFavorites[id]?.enableCacheMode = enabled
        }
    }

    public func updateSortOrder(favorites: [URLFavorite]) {
        if useInMemoryRealm, let realm = getRealm() {
            try? realm.write {
                for (index, favorite) in favorites.enumerated() {
                    favorite.sortOrder = index
                }
            }
        } else {
            for (index, favorite) in favorites.enumerated() {
                mockFavorites[favorite.id]?.sortOrder = index
            }
        }
    }

    // MARK: - 测试辅助方法

    /// 添加 Mock 数据（用于测试）
    public func addMockData(urls: [String], titles: [String]? = nil) {
        for (index, url) in urls.enumerated() {
            guard let urlObject = URL(string: url) else {
                print("⚠️ [MockFavoriteService] Invalid URL: \(url)")
                continue
            }
            let title = titles?.indices.contains(index) == true ? titles?[index] : nil
            addFavorite(url: urlObject, title: title, favicon: nil)
        }
    }

    /// 清空所有 Mock 数据
    public func clearMockData() {
        if useInMemoryRealm, let realm = getRealm() {
            try? realm.write {
                realm.deleteAll()
            }
        } else {
            mockFavorites.removeAll()
        }
    }
}
