//
//  PinnedURLManager.swift
//  WebBridgeKit
//
//  Created on 2025-05-11.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

// MARK: - PinnedURLManaging Protocol

public protocol PinnedURLManaging: AnyObject {
    func add(url: String, title: String?, notes: String?) async throws -> PinnedURLRealm
    func unpin(id: String) async throws
    func delete(id: String) async throws
    func recordAccess(id: String) async
    func getAllPinned() async throws -> [PinnedURLRealm]
    func getByType(_ type: URLType) async throws -> [PinnedURLRealm]
    func search(_ query: String) async throws -> [PinnedURLRealm]
    func getSummary() async throws -> PinnedURLSummary
    func importPresets(_ items: [PresetURLItem]) async throws -> Int
    func seedRecommendedPresetsIfNeeded() async throws -> Int
}

// MARK: - Database Actor

actor PinnedURLDatabaseActor {
    private let realmConfiguration: Realm.Configuration

    init(realmConfiguration: Realm.Configuration) {
        self.realmConfiguration = realmConfiguration
    }

    private func getRealm() throws -> Realm {
        try Realm(configuration: realmConfiguration)
    }

    // MARK: - CREATE

    func add(url: String, title: String?, notes: String?) throws -> PinnedURLRealm {
        let realm = try getRealm()

        let existing = realm.objects(PinnedURLRealm.self).filter("url == %@", url).first
        if let existing {
            try realm.write {
                existing.lastAccessedAt = Date()
                existing.accessCount += 1
                if let title, !title.isEmpty { existing.title = title }
                if let notes { existing.notes = notes }
            }
            return PinnedURLRealm(value: existing)
        }

        let obj = PinnedURLRealm()
        obj.url = url
        obj.title = title?.isEmpty == nil ? URL(string: url)?.host : title
        obj.notes = notes
        obj.domain = URL(string: url)?.host ?? ""
        obj.urlType = URLType.detect(from: url)
        obj.createdAt = Date()
        obj.lastAccessedAt = Date()
        obj.accessCount = 1

        try realm.write { realm.add(obj) }
        return PinnedURLRealm(value: obj)
    }

    // MARK: - UPDATE (Unpin)

    func unpin(id: String) throws {
        let realm = try getRealm()
        guard let obj = realm.object(ofType: PinnedURLRealm.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("PinnedURL not found: \(id)")
        }
        try realm.write { obj.isPinned = false }
    }

    // MARK: - DELETE

    func delete(id: String) throws {
        let realm = try getRealm()
        guard let obj = realm.object(ofType: PinnedURLRealm.self, forPrimaryKey: id) else {
            throw WebBridgeError.invalidInput("PinnedURL not found: \(id)")
        }
        try realm.write { realm.delete(obj) }
    }

    // MARK: - ACCESS

    func recordAccess(id: String) throws {
        let realm = try getRealm()
        guard let obj = realm.object(ofType: PinnedURLRealm.self, forPrimaryKey: id) else { return }
        try realm.write {
            obj.lastAccessedAt = Date()
            obj.accessCount += 1
        }
    }

    // MARK: - QUERY

    func getAllPinned() throws -> [PinnedURLRealm] {
        let realm = try getRealm()
        return realm.objects(PinnedURLRealm.self)
            .filter("isPinned == true")
            .sorted(by: [SortDescriptor(keyPath: "lastAccessedAt", ascending: false)])
            .map { PinnedURLRealm(value: $0) }
    }

    func getByType(_ type: URLType) throws -> [PinnedURLRealm] {
        let realm = try getRealm()
        return realm.objects(PinnedURLRealm.self)
            .filter("urlTypeRaw == %@ AND isPinned == true", type.rawValue)
            .sorted(by: [SortDescriptor(keyPath: "lastAccessedAt", ascending: false)])
            .map { PinnedURLRealm(value: $0) }
    }

    func search(_ query: String) throws -> [PinnedURLRealm] {
        let realm = try getRealm()
        let q = query.lowercased()
        return realm.objects(PinnedURLRealm.self)
            .filter("isPinned == true AND (url CONTAINS[c] %@ OR title CONTAINS[c] %@ OR domain CONTAINS[c] %@ OR notes CONTAINS[c] %@)",
                    q, q, q, q)
            .sorted(by: [SortDescriptor(keyPath: "lastAccessedAt", ascending: false)])
            .map { PinnedURLRealm(value: $0) }
    }

    func getSummary() throws -> PinnedURLSummary {
        let realm = try getRealm()
        let all = realm.objects(PinnedURLRealm.self)
        let pinned = all.filter("isPinned == true")

        var typeDist: [URLType: Int] = [:]
        for item in pinned {
            let t = item.urlType
            typeDist[t, default: 0] += 1
        }

        let pairs = pinned.map { ($0.domain, 1) }
        let grouped = Dictionary(grouping: pairs) { $0.0 }
        let summed = grouped.mapValues { v in v.count }
        let sorted = summed.sorted { $0.value > $1.value }
        let top5 = sorted.prefix(5)
        let domainCounts = top5.map { (domain: $0.key, count: $0.value) }

        return PinnedURLSummary(
            totalCount: all.count,
            pinnedCount: pinned.count,
            typeDistribution: typeDist,
            topDomains: Array(domainCounts)
        )
    }

    // MARK: - BATCH IMPORT

    func importPresets(_ items: [PresetURLItem]) throws -> Int {
        let realm = try getRealm()
        var imported = 0

        try realm.write {
            for item in items {
                let exists = realm.objects(PinnedURLRealm.self).filter("url == %@", item.url).first
                if exists != nil { continue }

                let obj = PinnedURLRealm()
                obj.url = item.url
                obj.title = item.title
                obj.notes = item.description
                obj.domain = URL(string: item.url)?.host ?? ""
                obj.urlType = item.urlType
                obj.tags = item.tags
                obj.isPinned = true
                obj.accessCount = 0

                realm.add(obj)
                imported += 1
            }
        }

        return imported
    }
}

// MARK: - PinnedURL Manager

public class PinnedURLManager: PinnedURLManaging {

    public static let shared = PinnedURLManager()

    public let realmConfiguration: Realm.Configuration
    private let databaseActor: PinnedURLDatabaseActor

    private init() {
        let realmPath = Realm.Configuration.defaultConfiguration.fileURL?
            .deletingLastPathComponent()
            .appendingPathComponent("pinnedUrls.realm")

        self.realmConfiguration = Realm.Configuration(
            fileURL: realmPath,
            schemaVersion: 1,
            objectTypes: [PinnedURLRealm.self]
        )
        self.databaseActor = PinnedURLDatabaseActor(realmConfiguration: realmConfiguration)
    }

    // MARK: - Public Async API

    public func add(url: String, title: String? = nil, notes: String? = nil) async throws -> PinnedURLRealm {
        return try await WebBridgeError.wrap {
            try await databaseActor.add(url: url, title: title, notes: notes)
        }
    }

    public func unpin(id: String) async throws {
        try await WebBridgeError.wrap {
            try await databaseActor.unpin(id: id)
        }
    }

    public func delete(id: String) async throws {
        try await WebBridgeError.wrap {
            try await databaseActor.delete(id: id)
        }
    }

    public func recordAccess(id: String) async {
        do {
            try await databaseActor.recordAccess(id: id)
        } catch {
            WebBridgeLogger.shared.log(.warning, "PinnedURLManager.recordAccess failed: \(error)")
        }
    }

    public func getAllPinned() async throws -> [PinnedURLRealm] {
        return try await WebBridgeError.wrap {
            try await databaseActor.getAllPinned()
        }
    }

    public func getByType(_ type: URLType) async throws -> [PinnedURLRealm] {
        return try await WebBridgeError.wrap {
            try await databaseActor.getByType(type)
        }
    }

    public func search(_ query: String) async throws -> [PinnedURLRealm] {
        return try await WebBridgeError.wrap {
            try await databaseActor.search(query)
        }
    }

    public func getSummary() async throws -> PinnedURLSummary {
        return try await WebBridgeError.wrap {
            try await databaseActor.getSummary()
        }
    }

    @discardableResult
    public func importPresets(_ items: [PresetURLItem]) async throws -> Int {
        return try await WebBridgeError.wrap {
            try await databaseActor.importPresets(items)
        }
    }

    public func seedRecommendedPresetsIfNeeded() async throws -> Int {
        let recommended = PresetURLCatalog.recommendedItems
        guard !recommended.isEmpty else { return 0 }

        let existing = try? await getAllPinned()
        if let existing, !existing.isEmpty { return 0 }

        return try await importPresets(recommended)
    }

    // MARK: - Synchronous Compatibility Layer

    @available(*, deprecated, message: "Use async add(url:title:notes:) instead. Sync methods risk deadlock on main thread.")
    public func addSync(url: String, title: String? = nil, notes: String? = nil) -> PinnedURLRealm? {
        var result: PinnedURLRealm?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do { result = try await add(url: url, title: title, notes: notes) } catch { WebBridgeLogger.shared.log(.error, "addSync failed: \(error)") }
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async getAllPinned() instead. Sync methods risk deadlock on main thread.")
    public func getAllPinnedSync() -> [PinnedURLRealm]? {
        var result: [PinnedURLRealm]?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do { result = try await getAllPinned() } catch { WebBridgeLogger.shared.log(.error, "getAllPinnedSync failed: \(error)") }
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    @available(*, deprecated, message: "Use async delete(id:) instead. Sync methods risk deadlock on main thread.")
    public func deleteSync(id: String) throws {
        var caughtError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do { try await delete(id: id) } catch { caughtError = error }
            semaphore.signal()
        }
        semaphore.wait()
        if let err = caughtError { throw err }
    }

    @available(*, deprecated, message: "Use async unpin(id:) instead. Sync methods risk deadlock on main thread.")
    public func unpinSync(id: String) throws {
        var caughtError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do { try await unpin(id: id) } catch { caughtError = error }
            semaphore.signal()
        }
        semaphore.wait()
        if let err = caughtError { throw err }
    }
}
