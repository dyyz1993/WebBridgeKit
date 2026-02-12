//
//  APIKeyManager.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import CommonCrypto

// MARK: - Actor for Thread-Safe Database Operations

/// Thread-safe actor for database operations
/// Ensures all Realm operations are serialized and safe from concurrent access
actor APIKeyDatabaseActor {
    private let realmConfiguration: Realm.Configuration
    private let permanentKeyID = "permanent-key"

    init(realmConfiguration: Realm.Configuration) {
        self.realmConfiguration = realmConfiguration
    }

    /// Get Realm instance
    private func getRealm() throws -> Realm {
        return try Realm(configuration: realmConfiguration)
    }

    /// Generate API key string
    private func generateAPIKey() -> String {
        // Format: wbk_ + 32 random characters
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomPart = String((0..<32).map { _ in characters.randomElement()! })

        // Add device identifier prefix
        let deviceID = UIDevice.current.identifierForVendor?.uuidString.prefix(8) ?? "unknown"
        return "wbk_\(deviceID)_\(randomPart)"
    }

    // MARK: - Permanent Key Operations

    /// Get permanent key object
    private func getPermanentKeyObject() throws -> APIKey? {
        let realm = try getRealm()
        let predicate = NSPredicate(format: "id == %@", permanentKeyID)
        return realm.objects(APIKey.self).filter(predicate).first
    }

    /// Ensure permanent key exists
    func ensurePermanentKeyExists() async throws {
        guard try getPermanentKeyObject() == nil else {
            return
        }
        // Create if not exists
        _ = try createPermanentKey()
    }

    /// Get permanent key value
    func getPermanentKey() async throws -> String {
        guard let key = try getPermanentKeyObject() else {
            return try createPermanentKey()
        }
        return key.keyValue
    }

    /// Create permanent key
    private func createPermanentKey() throws -> String {
        let realm = try getRealm()

        let key = APIKey()
        key.id = permanentKeyID
        key.keyType = "permanent"
        key.keyValue = generateAPIKey()
        key.isActive = true
        key.createdAt = Date()
        key.expiresAt = nil

        try realm.write {
            realm.add(key)
        }

        WebBridgeLogger.shared.log(.info, "🔑 Permanent key created")
        return key.keyValue
    }

    /// Refresh permanent key
    func refreshPermanentKey() async throws -> String {
        let realm = try getRealm()

        // Delete old permanent key
        if let oldKey = try getPermanentKeyObject() {
            try realm.write {
                realm.delete(oldKey)
            }
        }

        // Create new permanent key
        let newKey = try createPermanentKey()
        WebBridgeLogger.shared.log(.info, "🔄 Permanent key refreshed")
        return newKey
    }

    // MARK: - Temporary Key Operations

    /// Generate temporary key
    func generateTemporaryKey(duration: TimeInterval) async throws -> APIKey {
        let realm = try getRealm()

        let key = APIKey()
        key.id = UUID().uuidString
        key.keyType = "temporary"
        key.keyValue = generateAPIKey()
        key.isActive = true
        key.createdAt = Date()
        key.expiresAt = Date().addingTimeInterval(duration)

        try realm.write {
            realm.add(key)
        }

        WebBridgeLogger.shared.log(.info, "🔑 Temporary key generated, valid for \(Int(duration))s")
        // Return independent copy to avoid cross-thread access issues
        return APIKey(value: key)
    }

    /// Validate key
    func validateKey(key: String) async throws -> Bool {
        let realm = try getRealm()
        let predicate = NSPredicate(format: "keyValue == %@ AND isActive == true", key)
        guard let keyObj = realm.objects(APIKey.self).filter(predicate).first else {
            return false
        }

        // Check if expired
        if keyObj.isExpired {
            return false
        }

        return true
    }

    // MARK: - CRUD Operations

    /// Delete key
    func deleteKey(id: String) async throws {
        let realm = try getRealm()
        guard let key = realm.object(ofType: APIKey.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("Key not found with ID: \(id)")
        }

        // Don't allow deleting permanent key
        if key.id == permanentKeyID {
            WebBridgeLogger.shared.log(.warning, "⚠️ Cannot delete permanent key")
            throw WebBridgeError.invalidInput("Cannot delete permanent key")
        }

        try realm.write {
            realm.delete(key)
        }

        WebBridgeLogger.shared.log(.info, "🗑️ Key deleted: \(id)")
    }

    /// Get all keys
    func getAllKeys() async throws -> [APIKey] {
        let realm = try getRealm()
        let results = realm.objects(APIKey.self)
            .sorted(byKeyPath: "createdAt", ascending: false)
        // Create independent copies to avoid cross-thread access issues
        return results.map { APIKey(value: $0) }
    }

    /// Get temporary keys
    func getTemporaryKeys() async throws -> [APIKey] {
        let realm = try getRealm()
        let predicate = NSPredicate(format: "keyType == 'temporary'")
        let results = realm.objects(APIKey.self)
            .filter(predicate)
            .sorted(byKeyPath: "createdAt", ascending: false)
        // Create independent copies to avoid cross-thread access issues
        return results.map { APIKey(value: $0) }
    }

    // MARK: - Maintenance Operations

    /// Clean up expired temporary keys
    func cleanupExpiredKeys() async throws {
        let realm = try getRealm()
        let now = Date()
        let predicate = NSPredicate(format: "keyType == 'temporary' AND expiresAt <= %@", now as NSDate)
        let expired = realm.objects(APIKey.self).filter(predicate)

        let count = expired.count
        try realm.write {
            realm.delete(expired)
        }

        WebBridgeLogger.shared.log(.info, "🧹 Cleaned up \(count) expired keys")
    }
}

// MARK: - Main Manager Class

/// API Key Manager
/// Responsible for key generation, refresh, validation, and deletion
public class APIKeyManager {

    public static let shared = APIKeyManager()

    private let realmConfiguration: Realm.Configuration
    private let databaseActor: APIKeyDatabaseActor

    private init() {
        // Use independent Realm file
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("apiKey.realm"),
            schemaVersion: 1
        )
        self.databaseActor = APIKeyDatabaseActor(realmConfiguration: realmConfiguration)

        // Initialize permanent key asynchronously
        Task {
            try? await databaseActor.ensurePermanentKeyExists()
        }
    }

    // MARK: - Permanent Key Operations

    /// Get permanent key
    /// - Returns: Permanent key string
    public func getPermanentKey() async throws -> String {
        do {
            return try await databaseActor.getPermanentKey()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Refresh permanent key
    /// - Returns: New permanent key string
    @discardableResult
    public func refreshPermanentKey() async throws -> String {
        do {
            return try await databaseActor.refreshPermanentKey()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Temporary Key Operations

    /// Generate temporary key
    /// - Parameter duration: Valid duration in seconds
    /// - Returns: Created temporary key object
    @discardableResult
    public func generateTemporaryKey(duration: TimeInterval) async throws -> APIKey {
        do {
            return try await databaseActor.generateTemporaryKey(duration: duration)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Validate key
    /// - Parameter key: Key string
    /// - Returns: Whether valid
    public func validateKey(key: String) async throws -> Bool {
        do {
            return try await databaseActor.validateKey(key: key)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - CRUD Operations

    /// Delete key
    public func deleteKey(id: String) async throws {
        do {
            try await databaseActor.deleteKey(id: id)
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Get all keys
    public func getAllKeys() async throws -> [APIKey] {
        do {
            return try await databaseActor.getAllKeys()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    /// Get temporary keys
    public func getTemporaryKeys() async throws -> [APIKey] {
        do {
            return try await databaseActor.getTemporaryKeys()
        } catch let error as WebBridgeError {
            throw error
        } catch {
            throw WebBridgeError.databaseOperationFailed(underlying: error)
        }
    }

    // MARK: - Maintenance Operations

    /// Clean up expired temporary keys
    public func cleanupExpiredKeys() async throws {
        do {
            try await databaseActor.cleanupExpiredKeys()
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

extension APIKeyManager {

    /// Synchronous version of getPermanentKey for backward compatibility
    /// Returns empty string on error
    public func getPermanentKey() -> String {
        var result: String = ""
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getPermanentKey()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get permanent key: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of refreshPermanentKey for backward compatibility
    /// Returns empty string on error
    @discardableResult
    public func refreshPermanentKey() -> String {
        var result: String = ""
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await refreshPermanentKey()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to refresh permanent key: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of generateTemporaryKey for backward compatibility
    /// Returns nil on error
    @discardableResult
    public func generateTemporaryKey(duration: TimeInterval) -> APIKey? {
        var result: APIKey? = nil
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await generateTemporaryKey(duration: duration)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to generate temporary key: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of validateKey for backward compatibility
    /// Returns false on error
    public func validateKey(key: String) -> Bool {
        var result: Bool = false
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await validateKey(key: key)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to validate key: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of deleteKey for backward compatibility
    public func deleteKey(id: String) {
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                try await deleteKey(id: id)
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to delete key: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
    }

    /// Synchronous version of getAllKeys for backward compatibility
    /// Returns empty array on error
    public func getAllKeys() -> [APIKey] {
        var result: [APIKey] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getAllKeys()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get all keys: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of getTemporaryKeys for backward compatibility
    /// Returns empty array on error
    public func getTemporaryKeys() -> [APIKey] {
        var result: [APIKey] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await getTemporaryKeys()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to get temporary keys: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Synchronous version of cleanupExpiredKeys for backward compatibility
    public func cleanupExpiredKeys() {
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                try await cleanupExpiredKeys()
            } catch {
                WebBridgeLogger.shared.log(.error, "Failed to cleanup expired keys: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
    }
}
