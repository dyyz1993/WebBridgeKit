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

        // Check if already exists by iterating known objects
        var existingId: String? = nil
        let allObjects = realm.objects(URLFavorite.self)
        for obj in allObjects where obj.url == urlString {
            existingId = obj.id
            break
        }
        if let eid = existingId, let existing = realm.object(ofType: URLFavorite.self, forPrimaryKey: eid) {
            WebBridgeLogger.shared.log(.debug, "⚠️ Favorite already exists: \(urlString)")
            try realm.write {
                if let title = title { existing.title = title }
                if let favicon = favicon { existing.favicon = favicon }
            }
            return URLFavorite(value: existing)
        }

        let favorite = URLFavorite()
        favorite.url = urlString
        favorite.title = title ?? url.host
        favorite.favicon = favicon
        favorite.createdAt = Date()

        // Get current count for sort order
        favorite.sortOrder = allObjects.count

        try realm.write {
            realm.add(favorite)
        }

        WebBridgeLogger.shared.log(.info, "➕ Favorite added: \(urlString)")
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
        var result: [URLFavorite] = []
        let allObjects = realm.objects(URLFavorite.self)
            .sorted(by: [
                SortDescriptor(keyPath: "isPinned", ascending: false),
                SortDescriptor(keyPath: "sortOrder", ascending: true)
            ])
        for obj in allObjects {
            result.append(URLFavorite(value: obj))
        }
        return result
    }

    /// Find favorite by URL
    func findFavorite(url: URL) async throws -> URLFavorite? {
        guard let urlString = url.absoluteString as String? else { return nil }
        let realm = try getRealm()
        let allObjects = realm.objects(URLFavorite.self)
        for obj in allObjects where obj.url == urlString {
            return URLFavorite(value: obj)
        }
        return nil
    }

    /// Find favorite by ID
    func findFavorite(id: String) async throws -> URLFavorite? {
        let realm = try getRealm()
        if let favorite = realm.object(ofType: URLFavorite.self, forPrimaryKey: id) {
            return URLFavorite(value: favorite)
        }
        return nil
    }

    /// Search favorites (title or URL contains keyword)
    func searchFavorites(keyword: String) async throws -> [URLFavorite] {
        let realm = try getRealm()
        let lowerKeyword = keyword.lowercased()
        var matched: [URLFavorite] = []
        let allObjects = realm.objects(URLFavorite.self)
        for obj in allObjects {
            if obj.url.lowercased().contains(lowerKeyword) ||
               (obj.title?.lowercased().contains(lowerKeyword) ?? false) {
                matched.append(URLFavorite(value: obj))
            }
        }
        matched.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.sortOrder < b.sortOrder
        }
        return matched
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

    public let realmConfiguration: Realm.Configuration
    private let databaseActor: FavoriteDatabaseActor

    private init() {
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("urlFavorite.realm"),
            schemaVersion: 1,
            objectTypes: [URLFavorite.self]
        )
        self.databaseActor = FavoriteDatabaseActor(realmConfiguration: realmConfiguration)
    }

    // MARK: - Add/Update Operations

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

    public func deleteFavorite(id: String) async throws {
        do {
            try await databaseActor.deleteFavorite(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

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

    public func getAllFavorites() async throws -> [URLFavorite] {
        do {
            return try await databaseActor.getAllFavorites()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    public func findFavorite(url: URL) async throws -> URLFavorite? {
        do {
            return try await databaseActor.findFavorite(url: url)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    public func findFavorite(id: String) async throws -> URLFavorite? {
        do {
            return try await databaseActor.findFavorite(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    public func searchFavorites(keyword: String) async throws -> [URLFavorite] {
        do {
            return try await databaseActor.searchFavorites(keyword: keyword)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

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

    public func updateCacheMode(id: String, enabled: Bool) async throws {
        do {
            try await databaseActor.updateCacheMode(id: id, enabled: enabled)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

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

extension URLFavoriteManager {

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

    public func updateFavorite(_ favorite: URLFavorite) {
        Task {
            do {
                try await updateFavorite(favorite)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to update favorite: \(error.localizedDescription)")
            }
        }
    }

    public func deleteFavorite(id: String) {
        Task {
            do {
                try await deleteFavorite(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to delete favorite by ID: \(error.localizedDescription)")
            }
        }
    }

    public func deleteFavorite(url: URL) {
        Task {
            do {
                try await deleteFavorite(url: url)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to delete favorite by URL: \(error.localizedDescription)")
            }
        }
    }

    public func getAllFavorites() -> [URLFavorite] {
        guard let realm = try? Realm(configuration: realmConfiguration) else {
            WebBridgeLogger.shared.log(.error, "[URLFavoriteManager] Failed to open Realm at \(realmConfiguration.fileURL?.path ?? "nil")")
            return []
        }
        var result: [URLFavorite] = []
        let allObjects = realm.objects(URLFavorite.self)
            .sorted(by: [
                SortDescriptor(keyPath: "isPinned", ascending: false),
                SortDescriptor(keyPath: "sortOrder", ascending: true)
            ])
        for obj in allObjects {
            result.append(URLFavorite(value: obj))
        }
        if result.isEmpty && !allObjects.isEmpty {
            WebBridgeLogger.shared.log(.warning, "[URLFavoriteManager] Realm has \(allObjects.count) objects but getAllFavorites returned empty (detached copy issue?)")
        }
        return result
    }

    public func getAllFavoritesAsArray() -> [URLFavorite] {
        return getAllFavorites()
    }

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

    public func searchFavorites(keyword: String) -> [URLFavorite] {
        guard let realm = try? Realm(configuration: realmConfiguration) else { return [] }
        let lowerKeyword = keyword.lowercased()
        var matched: [URLFavorite] = []
        let allObjects = realm.objects(URLFavorite.self)
        for obj in allObjects {
            if obj.url.lowercased().contains(lowerKeyword) ||
               (obj.title?.lowercased().contains(lowerKeyword) ?? false) {
                matched.append(URLFavorite(value: obj))
            }
        }
        matched.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.sortOrder < b.sortOrder
        }
        return matched
    }

    public func searchFavoritesAsArray(keyword: String) -> [URLFavorite] {
        return searchFavorites(keyword: keyword)
    }

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

    public func updateCacheMode(id: String, enabled: Bool) {
        Task {
            do {
                try await updateCacheMode(id: id, enabled: enabled)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to update cache mode: \(error.localizedDescription)")
            }
        }
    }

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
