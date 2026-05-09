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

/// Thread-safe actor for database operations
/// Ensures all Realm operations are serialized and safe from concurrent access
actor HistoryDatabaseActor {
    private let realmConfiguration: Realm.Configuration

    init(realmConfiguration: Realm.Configuration) {
        self.realmConfiguration = realmConfiguration
    }

    /// Get Realm instance
    private func getRealm() throws -> Realm {
        return try Realm(configuration: realmConfiguration)
    }

    // MARK: - Add/Update Operations

    /// Add or update history record
    func addOrUpdateHistory(url: URL, title: String?, favicon: Data?) async throws {
        try await PerformanceMonitor.shared.measure(
            "Database.addOrUpdateHistory",
            metadata: ["url": url.absoluteString, "operation": "write"]
        ) {
            guard let urlString = url.absoluteString as String? else {
                throw WebBridgeError.invalidInput("Invalid URL string")
            }

            let realm = try getRealm()

            // Check if already exists
            let predicate = NSPredicate(format: "url == %@", urlString)
            guard let existing = realm.objects(WebPageHistory.self).filter(predicate).first else {
                // Create new record
                let history = WebPageHistory()
                history.url = urlString
                history.title = title
                history.favicon = favicon
                history.visitCount = 1
                history.lastVisitDate = Date()

                try realm.write {
                    realm.add(history)
                }
                WebBridgeLogger.shared.log(.debug, "➕ History added: \(urlString)")
                return
            }

            // Update existing record
            try realm.write {
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
        }
    }

    // MARK: - Delete Operations

    /// Delete history record by ID
    func deleteHistory(id: String) async throws {
        let realm = try getRealm()
        guard let history = realm.object(ofType: WebPageHistory.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("History not found with ID: \(id)")
        }

        try realm.write {
            // Delete cache if exists
            if history.isCached {
                WebPageOfflineCacheManager.shared.deleteCache(history: history, realm: realm)
            }
            realm.delete(history)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ History deleted: \(id)")
    }

    /// Clear all history (preserves favorites and pinned items)
    func clearAllHistory() async throws {
        let realm = try getRealm()

        // Find non-favorite and non-pinned items
        let predicate = NSPredicate(format: "isFavorite == false AND isPinned == false")
        let itemsToDelete = realm.objects(WebPageHistory.self).filter(predicate)

        try realm.write {
            for item in itemsToDelete where item.isCached {
                WebPageOfflineCacheManager.shared.deleteCache(history: item, realm: realm)
            }
            realm.delete(itemsToDelete)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Non-favorite/pinned history cleared")
    }

    /// Clean up low-frequency items (only non-favorite and non-pinned)
    /// When history exceeds limit, delete least visited items
    func cleanupLowFrequencyItems(limit: Int = 100) async throws {
        let realm = try getRealm()

        // Only filter non-favorite and non-pinned items for cleanup
        let predicate = NSPredicate(format: "isFavorite == false AND isPinned == false")
        let removableItems = realm.objects(WebPageHistory.self).filter(predicate)

        guard removableItems.count > limit else {
            return
        }

        let toDeleteCount = removableItems.count - limit
        // Sort by last visit date ascending (oldest first), take first toDeleteCount
        let itemsToDelete = Array(removableItems.sorted(byKeyPath: "lastVisitDate", ascending: true).prefix(toDeleteCount))

        try realm.write {
            for item in itemsToDelete {
                // Delete cache if exists
                if item.isCached {
                    WebPageOfflineCacheManager.shared.deleteCache(history: item, realm: realm)
                }
                realm.delete(item)
            }
        }

        WebBridgeLogger.shared.log(.info, "🧹 Cleaned up \(toDeleteCount) low-frequency history items (protected favorites/pinned)")
    }

    // MARK: - Query Operations

    /// Get all history records (sorted by last visit date descending)
    func getAllHistories() async throws -> [WebPageHistory] {
        return try await PerformanceMonitor.shared.measure(
            "Database.getAllHistories",
            metadata: ["operation": "query", "sort": "lastVisitDate"]
        ) {
            let realm = try getRealm()
            let results = realm.objects(WebPageHistory.self)
                .sorted(byKeyPath: "lastVisitDate", ascending: false)
            // Create independent copies to avoid cross-thread access issues
            return results.map { WebPageHistory(value: $0) }
        }
    }

    /// Get cached history records
    func getCachedHistories() async throws -> [WebPageHistory] {
        let realm = try getRealm()
        let results = realm.objects(WebPageHistory.self)
            .filter("isCached == true")
            .sorted(byKeyPath: "cacheDate", ascending: false)
        // Create independent copies to avoid cross-thread access issues
        return results.map { WebPageHistory(value: $0) }
    }

    /// Find history record by URL
    func findHistory(url: URL) async throws -> WebPageHistory? {
        guard let urlString = url.absoluteString as String? else {
            return nil
        }
        let realm = try getRealm()
        let predicate = NSPredicate(format: "url == %@", urlString)
        if let history = realm.objects(WebPageHistory.self).filter(predicate).first {
            // Return unfrozen (independent) object copy to avoid cross-thread access crashes
            return WebPageHistory(value: history)
        }
        return nil
    }

    /// Find history record by ID
    func findHistory(id: String) async throws -> WebPageHistory? {
        let realm = try getRealm()
        if let history = realm.object(ofType: WebPageHistory.self, forPrimaryKey: id) {
            // Return unfrozen (independent) object copy to avoid cross-thread access crashes
            return WebPageHistory(value: history)
        }
        return nil
    }

    /// Search history records (title or URL contains keyword)
    func searchHistories(keyword: String) async throws -> [WebPageHistory] {
        return try await PerformanceMonitor.shared.measure(
            "Database.searchHistories",
            metadata: ["keyword": keyword, "operation": "search"]
        ) {
            let realm = try getRealm()
            let results = realm.objects(WebPageHistory.self)
                .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
                .sorted(byKeyPath: "lastVisitDate", ascending: false)
            // Create independent copies to avoid cross-thread access issues
            return results.map { WebPageHistory(value: $0) }
        }
    }

    // MARK: - Statistics Operations

    /// Get total history count
    func getTotalCount() async throws -> Int {
        let realm = try getRealm()
        return realm.objects(WebPageHistory.self).count
    }

    /// Get today's visit count
    func getTodayVisitCount() async throws -> Int {
        let realm = try getRealm()
        let today = Calendar.current.startOfDay(for: Date())
        return realm.objects(WebPageHistory.self)
            .filter("lastVisitDate >= %@", today as NSDate)
            .count
    }

    /// Get most visited pages (top N)
    func getMostVisited(limit: Int = 10) async throws -> [WebPageHistory] {
        let realm = try getRealm()
        return Array(realm.objects(WebPageHistory.self)
                        .sorted(byKeyPath: "visitCount", ascending: false)
                        .prefix(limit))
    }

    // MARK: - Utility Operations

    /// Clean old thumbnails, keep only latest N
    /// - Parameter keepLatest: Number to keep
    func cleanOldThumbnails(keepLatest: Int = 100) async throws {
        let realm = try getRealm()

        // Get all history with thumbnails, sorted by visit date descending
        let histories = realm.objects(WebPageHistory.self)
            .filter("thumbnail != nil")
            .sorted(byKeyPath: "lastVisitDate", ascending: false)

        // Clear thumbnails for items exceeding keep limit
        let toClean = Array(histories.dropFirst(keepLatest))

        try realm.write {
            for history in toClean {
                history.thumbnail = nil
            }
        }

        WebBridgeLogger.shared.log(.info, "🧹 Cleaned \(toClean.count) old thumbnails")
    }
}

/// History manager
/// Responsible for tracking, adding, deleting, and querying access history
public class WebPageHistoryManager: WebPageHistoryManaging {

    public static let shared = WebPageHistoryManager()

    public let realmConfiguration: Realm.Configuration
    private let databaseActor: HistoryDatabaseActor

    // Allow creating test instances
    public init() {
        // Use independent Realm file to avoid conflicts with other Realm instances
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("pageHistory.realm"),
            schemaVersion: 2,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    migration.enumerateObjects(ofType: WebPageHistory.className()) { oldObject, newObject in
                        newObject?["ruleId"] = nil
                        newObject?["ruleName"] = nil
                        newObject?["isExcluded"] = false
                    }
                }
            },
            deleteRealmIfMigrationNeeded: false,
            objectTypes: [WebPageHistory.self]
        )
        self.databaseActor = HistoryDatabaseActor(realmConfiguration: realmConfiguration)
    }

    // MARK: - Add/Update Operations

    /// Add or update history record
    /// - Parameters:
    ///   - url: Page URL
    ///   - title: Page title (optional)
    ///   - favicon: Page icon (optional)
    public func addOrUpdateHistory(url: URL, title: String? = nil, favicon: Data? = nil) async throws {
        do {
            try await databaseActor.addOrUpdateHistory(url: url, title: title, favicon: favicon)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Delete Operations

    /// Delete history record
    public func deleteHistory(id: String) async throws {
        do {
            try await databaseActor.deleteHistory(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Clear all history (preserves favorites and pinned items)
    public func clearAllHistory() async throws {
        do {
            try await databaseActor.clearAllHistory()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Clean up low-frequency items (only non-favorite and non-pinned)
    /// When history exceeds limit, delete least visited items
    public func cleanupLowFrequencyItems(limit: Int = 100) async throws {
        do {
            try await databaseActor.cleanupLowFrequencyItems(limit: limit)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Query Operations

    /// Get all history records (sorted by last visit date descending)
    /// Returns independent copy array to avoid cross-thread access issues
    public func getAllHistories() async throws -> [WebPageHistory] {
        do {
            return try await databaseActor.getAllHistories()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Get cached history records
    /// Returns independent copy array to avoid cross-thread access issues
    public func getCachedHistories() async throws -> [WebPageHistory] {
        do {
            return try await databaseActor.getCachedHistories()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Find history record by URL
    public func findHistory(url: URL) async throws -> WebPageHistory? {
        do {
            return try await databaseActor.findHistory(url: url)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Find history record by ID
    public func findHistory(id: String) async throws -> WebPageHistory? {
        do {
            return try await databaseActor.findHistory(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Search history records (title or URL contains keyword)
    /// Returns independent copy array to avoid cross-thread access issues
    public func searchHistories(keyword: String) async throws -> [WebPageHistory] {
        do {
            return try await databaseActor.searchHistories(keyword: keyword)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Statistics Operations

    /// Get total history count
    public func getTotalCount() async throws -> Int {
        do {
            return try await databaseActor.getTotalCount()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Get today's visit count
    public func getTodayVisitCount() async throws -> Int {
        do {
            return try await databaseActor.getTodayVisitCount()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Get most visited pages (top N)
    public func getMostVisited(limit: Int = 10) async throws -> [WebPageHistory] {
        do {
            return try await databaseActor.getMostVisited(limit: limit)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Utility Operations

    /// Clean old thumbnails, keep only latest N
    /// - Parameter keepLatest: Number to keep
    func cleanOldThumbnails(keepLatest: Int = 100) async throws {
        do {
            try await databaseActor.cleanOldThumbnails(keepLatest: keepLatest)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }
}

// MARK: - Synchronous Compatibility Layer
// These methods provide backward compatibility with existing code
// that calls the manager synchronously. They wrap the async methods.

extension WebPageHistoryManager {

    /// Synchronous version of addOrUpdateHistory for backward compatibility
    public func addOrUpdateHistory(url: URL, title: String? = nil, favicon: Data? = nil) {
        Task {
            try? await addOrUpdateHistory(url: url, title: title, favicon: favicon)
        }
    }

    /// Synchronous version of deleteHistory for backward compatibility
    public func deleteHistory(id: String) {
        Task {
            try? await deleteHistory(id: id)
        }
    }

    /// Synchronous version of clearAllHistory for backward compatibility
    public func clearAllHistory() {
        Task {
            try? await clearAllHistory()
        }
    }

    /// Synchronous version of cleanupLowFrequencyItems for backward compatibility
    public func cleanupLowFrequencyItems(limit: Int = 100) {
        Task {
            try? await cleanupLowFrequencyItems(limit: limit)
        }
    }

    /// Synchronous version of getAllHistories for backward compatibility
    /// Returns empty array on error
    public func getAllHistories() -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getAllHistories()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get all histories: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of getCachedHistories for backward compatibility
    /// Returns empty array on error
    public func getCachedHistories() -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getCachedHistories()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get cached histories: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of findHistory(url:) for backward compatibility
    /// Returns nil on error
    public func findHistory(url: URL) -> WebPageHistory? {
        var result: WebPageHistory?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await findHistory(url: url)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to find history by URL: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of findHistory(id:) for backward compatibility
    /// Returns nil on error
    public func findHistory(id: String) -> WebPageHistory? {
        var result: WebPageHistory?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await findHistory(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to find history by ID: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of searchHistories for backward compatibility
    /// Returns empty array on error
    public func searchHistories(keyword: String) -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await searchHistories(keyword: keyword)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to search histories: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of getTotalCount for backward compatibility
    /// Returns 0 on error
    public func getTotalCount() -> Int {
        var result: Int = 0
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getTotalCount()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get total count: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of getTodayVisitCount for backward compatibility
    /// Returns 0 on error
    public func getTodayVisitCount() -> Int {
        var result: Int = 0
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getTodayVisitCount()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get today visit count: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of getMostVisited for backward compatibility
    /// Returns empty array on error
    public func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
        var result: [WebPageHistory] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getMostVisited(limit: limit)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get most visited: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }
}
