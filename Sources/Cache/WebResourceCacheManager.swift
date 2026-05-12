//
//  WebResourceCacheManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// Web资源缓存管理器
/// 实现按 URL 隔离的缓存空间管理
/// 为每个 URL 分配唯一的 cache-id（UUID），创建独立的缓存目录
///
/// Implementation split into extensions:
/// - ResourceCacheTypes.swift — nested types (CacheSpaceStats, WebResourceManifest, etc.)
/// - ResourceCacheSpace.swift — cache space CRUD and helpers
/// - ResourceStore.swift — resource store/retrieve and manifest I/O
/// - ResourceCacheStats.swift — statistics, eviction, cleanup
public class WebResourceCacheManager {

    // MARK: - Singleton

    public static let shared = WebResourceCacheManager()

    // MARK: - Properties

    let realmConfiguration: Realm.Configuration

    public var configuration: Realm.Configuration {
        return realmConfiguration
    }
    let cacheBaseDirectory: URL
    let cacheIndexFile: URL
    let fileManager = FileManager.default

    var urlToCacheIDMap: [String: String] = [:]
    var cacheAccessTimes: [String: Date] = [:]

    let mapLock = NSLock()
    let accessLock = NSLock()
    let queue = DispatchQueue(label: "com.webbridgekit.resource-cache-manager", qos: .utility)

    var totalCacheSize: Int64 = 0
    let sizeLock = NSLock()

    // MARK: - Initialization

    private init() {
        self.realmConfiguration = Realm.Configuration(
            fileURL: Realm.Configuration.defaultConfiguration.fileURL?.deletingLastPathComponent().appendingPathComponent("resourceCache.realm"),
            schemaVersion: 1,
            objectTypes: [CacheEntryRealm.self, WebCacheStatistics.self]
        )

        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheBaseDirectory = paths[0].appendingPathComponent("WebResourceCache", isDirectory: true)
        self.cacheIndexFile = cacheBaseDirectory.appendingPathComponent("cache-index.plist")

        setupCacheDirectory()
        setupStats()

        if !ProcessInfo.processInfo.arguments.contains("-UITesting") {
            queue.async { [weak self] in
                guard let self = self else { return }
                self.loadCacheIndex()
                self.updateTotalCacheSize()

                print("✅ [WebResourceCacheManager] Initialization tasks completed in background")
            }
        } else {
            queue.async { [weak self] in
                self?.loadCacheIndex()
            }
            print("🧪 [WebResourceCacheManager] UI Testing mode: Skipped heavy size calculation")
        }

        print("✅ [WebResourceCacheManager] Initialized (background loading started)")
    }
}
