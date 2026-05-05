//
//  URLFavoriteManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// Thread-safe actor for database operations
/// Ensures all Realm operations are serialized and safe from concurrent access
actor FavoriteDatabaseActor {
    private let realmConfiguration: Realm.Configuration

    init(realmConfiguration: Realm.Configuration) {
        self.realmConfiguration = realmConfiguration
    }

    /// Get Realm instance
    private func getRealm() throws -> Realm {
        return try Realm(configuration: realmConfiguration)
    }

    // MARK: - Add/Update Operations

    /// Add favorite
    /// - Parameters:
    ///   - url: Page URL
    ///   - title: Page title (optional)
    ///   - favicon: Page icon (optional)
    /// - Returns: Created favorite object
    @discardableResult
    func addFavorite(url: URL, title: String? = nil, favicon: Data? = nil) async throws -> URLFavorite {
        guard let urlString = url.absoluteString as String? else {
            throw WebBridgeError.invalidInput("Invalid URL string")
        }

        let realm = try getRealm()

        // Check if already exists
        let predicate = NSPredicate(format: "url == %@", urlString)
        if let existing = realm.objects(URLFavorite.self).filter(predicate).first {
            WebBridgeLogger.shared.log(.debug, "⚠️ Favorite already exists: \(urlString)")
            // Update title and favicon
            try realm.write {
                if let title = title {
                    existing.title = title
                }
                if let favicon = favicon {
                    existing.favicon = favicon
                }
            }
            // Return independent copy
            return URLFavorite(value: existing)
        }

        let favorite = URLFavorite()
        favorite.url = urlString
        favorite.title = title ?? url.host
        favorite.favicon = favicon
        favorite.createdAt = Date()

        // Get current count for sort order
        let currentCount = realm.objects(URLFavorite.self).count
        favorite.sortOrder = currentCount

        try realm.write {
            realm.add(favorite)
        }

        WebBridgeLogger.shared.log(.info, "➕ Favorite added: \(urlString)")
        // Return independent copy
        return URLFavorite(value: favorite)
    }

    /// Update favorite
    func updateFavorite(_ favorite: URLFavorite) async throws {
        let realm = try getRealm()
        try realm.write {
            realm.add(favorite, update: .modified)
        }
        WebBridgeLogger.shared.log(.debug, "♻️ Favorite updated: \(favorite.id)")
    }

    // MARK: - Delete Operations

    /// Delete favorite by ID
    func deleteFavorite(id: String) async throws {
        let realm = try getRealm()
        guard let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("Favorite not found with ID: \(id)")
        }

        try realm.write {
            realm.delete(favorite)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Favorite deleted: \(id)")
    }

    /// Delete favorite by URL
    func deleteFavorite(url: URL) async throws {
        guard let favorite = try await findFavorite(url: url) else {
            throw WebBridgeError.invalidInput("Favorite not found with URL: \(url.absoluteString)")
        }
        try await deleteFavorite(id: favorite.id)
    }

    // MARK: - Query Operations

    /// Get all favorites (sorted by pinned status and sort order)
    func getAllFavorites() async throws -> [URLFavorite] {
        let realm = try getRealm()
        let results = realm.objects(URLFavorite.self)
            .sorted(by: [
                SortDescriptor(keyPath: "isPinned", ascending: false),
                SortDescriptor(keyPath: "sortOrder", ascending: true)
            ])
        // Create independent copies to avoid cross-thread access issues
        return results.map { URLFavorite(value: $0) }
    }

    /// Find favorite by URL
    func findFavorite(url: URL) async throws -> URLFavorite? {
        guard let urlString = url.absoluteString as String? else {
            return nil
        }
        let realm = try getRealm()
        let predicate = NSPredicate(format: "url == %@", urlString)
        if let favorite = realm.objects(URLFavorite.self).filter(predicate).first {
            // Return unfrozen (independent) object copy to avoid cross-thread access crashes
            return URLFavorite(value: favorite)
        }
        return nil
    }

    /// Find favorite by ID
    func findFavorite(id: String) async throws -> URLFavorite? {
        let realm = try getRealm()
        if let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) {
            // Return unfrozen (independent) object copy to avoid cross-thread access crashes
            return URLFavorite(value: favorite)
        }
        return nil
    }

    /// Search favorites (title or URL contains keyword)
    func searchFavorites(keyword: String) async throws -> [URLFavorite] {
        let realm = try getRealm()
        let results = realm.objects(URLFavorite.self)
            .filter("url CONTAINS[c] %@ OR title CONTAINS[c] %@", keyword, keyword)
            .sorted(by: [
                SortDescriptor(keyPath: "isPinned", ascending: false),
                SortDescriptor(keyPath: "sortOrder", ascending: true)
            ])
        // Create independent copies to avoid cross-thread access issues
        return results.map { URLFavorite(value: $0) }
    }

    /// Get total favorite count
    func getTotalCount() async throws -> Int {
        let realm = try getRealm()
        return realm.objects(URLFavorite.self).count
    }

    // MARK: - Special Operations

    /// Toggle pin status
    /// - Parameter id: Favorite ID
    /// - Returns: New pin status
    @discardableResult
    func togglePin(id: String) async throws -> Bool {
        let realm = try getRealm()
        guard let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("Favorite not found with ID: \(id)")
        }

        try realm.write {
            favorite.isPinned.toggle()
        }

        WebBridgeLogger.shared.log(.info, favorite.isPinned ? "📌 Favorite pinned: \(id)" : "📍 Favorite unpinned: \(id)")
        return favorite.isPinned
    }

    /// Update cache mode
    func updateCacheMode(id: String, enabled: Bool) async throws {
        let realm = try getRealm()
        guard let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("Favorite not found with ID: \(id)")
        }

        try realm.write {
            favorite.enableCacheMode = enabled
        }

        WebBridgeLogger.shared.log(.info, "\(enabled ? "✅" : "❌") Cache mode \(enabled ? "enabled" : "disabled"): \(id)")
    }

    /// Update sort order
    func updateSortOrder(favorites: [URLFavorite]) async throws {
        let realm = try getRealm()
        try realm.write {
            for (index, favorite) in favorites.enumerated() {
                favorite.sortOrder = index
            }
        }
        WebBridgeLogger.shared.log(.debug, "♻️ Sort order updated")
    }
}

/// URL Favorite Manager
/// Responsible for add, delete, update, query, pin, and cache mode management of favorites
public class URLFavoriteManager {

    public static let shared = URLFavoriteManager()

    private let realmConfiguration: Realm.Configuration
    private let databaseActor: FavoriteDatabaseActor

    private init() {
        // Use independent Realm file
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("urlFavorite.realm"),
            schemaVersion: 1
        )
        self.databaseActor = FavoriteDatabaseActor(realmConfiguration: realmConfiguration)
    }

    // MARK: - Add/Update Operations

    /// Add favorite
    /// - Parameters:
    ///   - url: Page URL
    ///   - title: Page title (optional)
    ///   - favicon: Page icon (optional)
    /// - Returns: Created favorite object
    @discardableResult
    public func addFavorite(url: URL, title: String? = nil, favicon: Data? = nil) async throws -> URLFavorite {
        do {
            return try await databaseActor.addFavorite(url: url, title: title, favicon: favicon)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Update favorite
    public func updateFavorite(_ favorite: URLFavorite) async throws {
        do {
            try await databaseActor.updateFavorite(favorite)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Delete Operations

    /// Delete favorite by ID
    public func deleteFavorite(id: String) async throws {
        do {
            try await databaseActor.deleteFavorite(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Delete favorite by URL
    public func deleteFavorite(url: URL) async throws {
        do {
            try await databaseActor.deleteFavorite(url: url)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Query Operations

    /// Get all favorites (sorted by pinned status and sort order)
    /// Returns independent copy array to avoid cross-thread access issues
    public func getAllFavorites() async throws -> [URLFavorite] {
        do {
            return try await databaseActor.getAllFavorites()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Find favorite by URL
    public func findFavorite(url: URL) async throws -> URLFavorite? {
        do {
            return try await databaseActor.findFavorite(url: url)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Find favorite by ID
    public func findFavorite(id: String) async throws -> URLFavorite? {
        do {
            return try await databaseActor.findFavorite(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Search favorites (title or URL contains keyword)
    /// Returns independent copy array to avoid cross-thread access issues
    public func searchFavorites(keyword: String) async throws -> [URLFavorite] {
        do {
            return try await databaseActor.searchFavorites(keyword: keyword)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Get total favorite count
    public func getTotalCount() async throws -> Int {
        do {
            return try await databaseActor.getTotalCount()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Special Operations

    /// Toggle pin status
    /// - Parameter id: Favorite ID
    /// - Returns: New pin status
    @discardableResult
    public func togglePin(id: String) async throws -> Bool {
        do {
            return try await databaseActor.togglePin(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Update cache mode
    public func updateCacheMode(id: String, enabled: Bool) async throws {
        do {
            try await databaseActor.updateCacheMode(id: id, enabled: enabled)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Update sort order
    public func updateSortOrder(favorites: [URLFavorite]) async throws {
        do {
            try await databaseActor.updateSortOrder(favorites: favorites)
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

extension URLFavoriteManager {

    /// Synchronous version of addFavorite for backward compatibility
    @discardableResult
    public func addFavorite(url: URL, title: String? = nil, favicon: Data? = nil) -> URLFavorite? {
        var result: URLFavorite?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await addFavorite(url: url, title: title, favicon: favicon)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to add favorite: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of updateFavorite for backward compatibility
    public func updateFavorite(_ favorite: URLFavorite) {
        Task {
            do {
                try await updateFavorite(favorite)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to update favorite: \(error.localizedDescription)")
            }
        }
    }

    /// Synchronous version of deleteFavorite(id:) for backward compatibility
    public func deleteFavorite(id: String) {
        Task {
            do {
                try await deleteFavorite(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to delete favorite by ID: \(error.localizedDescription)")
            }
        }
    }

    /// Synchronous version of deleteFavorite(url:) for backward compatibility
    public func deleteFavorite(url: URL) {
        Task {
            do {
                try await deleteFavorite(url: url)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to delete favorite by URL: \(error.localizedDescription)")
            }
        }
    }

    /// Synchronous version of getAllFavorites for backward compatibility
    /// Returns Results<URLFavorite> for protocol compatibility
    public func getAllFavorites() -> Results<URLFavorite> {
        let realm = try? Realm(configuration: realmConfiguration)
        guard let realm = realm else {
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

    /// Synchronous version of getAllFavorites returning array
    /// Returns empty array on error
    public func getAllFavoritesAsArray() -> [URLFavorite] {
        var result: [URLFavorite] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getAllFavorites()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get all favorites: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of findFavorite(url:) for backward compatibility
    /// Returns nil on error
    public func findFavorite(url: URL) -> URLFavorite? {
        var result: URLFavorite?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await findFavorite(url: url)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to find favorite by URL: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of findFavorite(id:) for backward compatibility
    /// Returns nil on error
    public func findFavorite(id: String) -> URLFavorite? {
        var result: URLFavorite?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await findFavorite(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to find favorite by ID: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of searchFavorites for backward compatibility
    /// Returns Results<URLFavorite> for protocol compatibility
    public func searchFavorites(keyword: String) -> Results<URLFavorite> {
        let realm = try? Realm(configuration: realmConfiguration)
        guard let realm = realm else {
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

    /// Synchronous version of searchFavorites returning array
    /// Returns empty array on error
    public func searchFavoritesAsArray(keyword: String) -> [URLFavorite] {
        var result: [URLFavorite] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await searchFavorites(keyword: keyword)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to search favorites: \(error.localizedDescription)")
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

    /// Synchronous version of togglePin for backward compatibility
    /// Returns false on error
    @discardableResult
    public func togglePin(id: String) -> Bool {
        var result: Bool = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await togglePin(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to toggle pin: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of updateCacheMode for backward compatibility
    public func updateCacheMode(id: String, enabled: Bool) {
        Task {
            do {
                try await updateCacheMode(id: id, enabled: enabled)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to update cache mode: \(error.localizedDescription)")
            }
        }
    }

    /// Synchronous version of updateSortOrder for backward compatibility
    public func updateSortOrder(favorites: [URLFavorite]) {
        Task {
            do {
                try await updateSortOrder(favorites: favorites)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to update sort order: \(error.localizedDescription)")
            }
        }
    }
}
