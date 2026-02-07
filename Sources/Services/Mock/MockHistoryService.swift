//
//  MockHistoryService.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// Mock 历史记录服务
/// 用于测试和开发，提供内存中的数据存储
public class MockHistoryService: HistoryServiceProtocol {

    public static let shared = MockHistoryService()

    /// 内存中的历史记录存储
    private var mockHistories: [String: WebPageHistory] = [:]
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
            self.realmConfiguration = Realm.Configuration(inMemoryIdentifier: "MockHistoryRealm")
            self.sharedRealm = try? Realm(configuration: realmConfiguration)
            print("🔍 [MockHistoryService] Initialized with in-memory Realm, success: \(sharedRealm != nil)")
        } else {
            // 创建一个无效配置，强制使用内存存储
            self.realmConfiguration = Realm.Configuration(fileURL: URL(fileURLWithPath: "/dev/null/mock.realm"))
            self.sharedRealm = nil
            print("🔍 [MockHistoryService] Initialized with dictionary storage")
        }
    }

    /// 获取 Realm 实例（仅在使用 in-memory 模式时有效）
    private func getRealm() -> Realm? {
        return sharedRealm
    }

    // MARK: - 添加/更新

    public func addOrUpdateHistory(url: URL, title: String?, favicon: Data?) {
        let urlString = url.absoluteString

        if useInMemoryRealm, let realm = getRealm() {
            // 使用 Realm 内存数据库
            let predicate = NSPredicate(format: "url == %@", urlString)
            let existing = realm.objects(WebPageHistory.self).filter(predicate).first

            try? realm.write {
                if let existing = existing {
                    existing.lastVisitDate = Date()
                    existing.visitCount += 1
                    if let title = title, existing.title == nil {
                        existing.title = title
                    }
                    if let favicon = favicon, existing.favicon == nil {
                        existing.favicon = favicon
                    }
                    print("🔍 [MockHistoryService] Updated history: \(urlString)")
                } else {
                    let history = WebPageHistory()
                    history.id = UUID().uuidString
                    history.url = urlString
                    history.title = title
                    history.favicon = favicon
                    history.visitCount = 1
                    history.lastVisitDate = Date()
                    realm.add(history)
                    print("🔍 [MockHistoryService] Added history: \(urlString), total count: \(realm.objects(WebPageHistory.self).count)")
                }
            }
        } else {
            // 使用内存字典
            if let existing = mockHistories[urlString] {
                existing.lastVisitDate = Date()
                existing.visitCount += 1
                if let title = title, existing.title == nil {
                    existing.title = title
                }
                if let favicon = favicon, existing.favicon == nil {
                    existing.favicon = favicon
                }
            } else {
                let history = WebPageHistory()
                history.id = UUID().uuidString
                history.url = urlString
                history.title = title
                history.favicon = favicon
                history.visitCount = 1
                history.lastVisitDate = Date()
                mockHistories[urlString] = history
            }
        }
    }

    // MARK: - 删除

    public func deleteHistory(id: String) {
        if useInMemoryRealm, let realm = getRealm() {
            if let history = realm.object(ofType: WebPageHistory.self, forPrimaryKey: id) {
                try? realm.write {
                    realm.delete(history)
                }
            }
        } else {
            mockHistories.removeValue(forKey: id)
        }
    }

    public func clearAllHistory() {
        if useInMemoryRealm, let realm = getRealm() {
            try? realm.write {
                realm.deleteAll()
            }
        } else {
            mockHistories.removeAll()
        }
    }

    // MARK: - 查询

    public func getAllHistories() -> Results<WebPageHistory> {
        if useInMemoryRealm, let realm = getRealm() {
            let results = realm.objects(WebPageHistory.self)
                .sorted(byKeyPath: "lastVisitDate", ascending: false)
            print("🔍 [MockHistoryService] getAllHistories: useInMemoryRealm=true, count: \(results.count)")
            return results
        }

        // 创建临时内存 Realm 来获取空 Results
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        let tempRealm = try! Realm(configuration: config)
        print("🔍 [MockHistoryService] getAllHistories: useInMemoryRealm=false, returning empty Results")
        return tempRealm.objects(WebPageHistory.self).filter("FALSEPREDICATE")
    }

    /// 获取所有历史记录的数组形式（用于 Mock 模式）
    public func getAllHistoriesArray() -> [WebPageHistory] {
        if useInMemoryRealm, let realm = getRealm() {
            return Array(realm.objects(WebPageHistory.self)
                .sorted(byKeyPath: "lastVisitDate", ascending: false))
        }

        return Array(mockHistories.values)
            .sorted { $0.lastVisitDate > $1.lastVisitDate }
    }

    public func getCachedHistories() -> Results<WebPageHistory> {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.objects(WebPageHistory.self)
                .filter("isCached == true")
                .sorted(byKeyPath: "cacheDate", ascending: false)
        }
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        let tempRealm = try! Realm(configuration: config)
        return tempRealm.objects(WebPageHistory.self).filter("FALSEPREDICATE")
    }

    public func findHistory(url: URL) -> WebPageHistory? {
        let urlString = url.absoluteString

        if useInMemoryRealm, let realm = getRealm() {
            let predicate = NSPredicate(format: "url == %@", urlString)
            return realm.objects(WebPageHistory.self).filter(predicate).first
        }

        return mockHistories[urlString]
    }

    public func findHistory(id: String) -> WebPageHistory? {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.object(ofType: WebPageHistory.self, forPrimaryKey: id)
        }

        return mockHistories.values.first { $0.id == id }
    }

    public func searchHistories(keyword: String) -> Results<WebPageHistory> {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.objects(WebPageHistory.self)
                .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
                .sorted(byKeyPath: "lastVisitDate", ascending: false)
        }
        let config = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        let tempRealm = try! Realm(configuration: config)
        return tempRealm.objects(WebPageHistory.self).filter("FALSEPREDICATE")
    }

    // MARK: - 统计

    public func getTotalCount() -> Int {
        if useInMemoryRealm, let realm = getRealm() {
            return realm.objects(WebPageHistory.self).count
        }
        return mockHistories.count
    }

    public func getTodayVisitCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())

        if useInMemoryRealm, let realm = getRealm() {
            return realm.objects(WebPageHistory.self)
                .filter("lastVisitDate >= %@", today as NSDate)
                .count
        }

        return mockHistories.values
            .filter { $0.lastVisitDate >= today }
            .count
    }

    public func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
        if useInMemoryRealm, let realm = getRealm() {
            return Array(realm.objects(WebPageHistory.self)
                .sorted(byKeyPath: "visitCount", ascending: false)
                .prefix(limit))
        }

        return mockHistories.values
            .sorted { $0.visitCount > $1.visitCount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - 测试辅助方法

    /// 添加 Mock 数据（用于测试）
    public func addMockData(urls: [String], titles: [String]? = nil) {
        for (index, url) in urls.enumerated() {
            let title = titles?.indices.contains(index) == true ? titles?[index] : "Mock: \(url)"
            addOrUpdateHistory(url: URL(string: url)!, title: title, favicon: nil)
        }
    }

    /// 清空所有 Mock 数据
    public func clearMockData() {
        clearAllHistory()
    }
}
