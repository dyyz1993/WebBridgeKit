//
//  ResourceCacheStats.swift
//  WebBridgeKit
//
//  Split from WebResourceCacheManager.swift
//

import Foundation
import RealmSwift

extension WebResourceCacheManager {

    var cacheStats: WebCacheStatistics? {
        if Thread.isMainThread {
            #if DEBUG
            print("⚠️ [WebResourceCacheManager] Warning: Accessing cacheStats on main thread may cause hitches")
            #endif
        }
        let realm = getRealm()
        return realm?.object(ofType: WebCacheStatistics.self, forPrimaryKey: "global")
    }

    public func getCacheStats(cacheID: String) -> CacheSpaceStats? {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return nil
        }

        guard let url = getURL(for: cacheID) else {
            return nil
        }

        let manifest = loadManifest(for: cacheID)

        var totalSize: Int64 = 0
        var fileCount = 0

        if Thread.isMainThread {
            #if DEBUG
            print("⚠️ [WebResourceCacheManager] getCacheStats called on Main Thread. This may cause UI lag.")
            #endif
        }

        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                    fileCount += 1
                }
            }
        }

        let createdAt = (manifest?.createdAt) ?? (try? fileManager.attributesOfItem(atPath: cacheDirectory.path)[.creationDate] as? Date) ?? Date()
        let lastAccessedAt = cacheAccessTimes[cacheID] ?? Date()

        return CacheSpaceStats(
            cacheID: cacheID,
            url: url,
            totalSize: totalSize,
            fileCount: fileCount,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            manifest: manifest
        )
    }

    public func getAllCacheStats() -> [CacheSpaceStats] {
        mapLock.lock()
        let cacheIDs = Set(urlToCacheIDMap.values)
        mapLock.unlock()

        return cacheIDs.compactMap { getCacheStats(cacheID: $0) }
    }

    public func getGlobalStats() -> (totalSize: Int64, totalFiles: Int) {
        var totalSize: Int64 = 0
        var totalFiles = 0

        if let enumerator = fileManager.enumerator(at: cacheBaseDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                    totalFiles += 1
                }
            }
        }

        return (totalSize, totalFiles)
    }

    public func evictLeastRecentlyUsed(count: Int, policy: LRUEvictionPolicy = .leastRecentlyUsed) -> [String] {
        mapLock.lock()
        defer { mapLock.unlock() }

        let sortedCacheIDs = getSortedCacheIDs(by: policy)
        let toRemove = Array(sortedCacheIDs.prefix(count))

        for cacheID in toRemove {
            removeCacheSpace(cacheID: cacheID)
        }

        print("🧹 [WebResourceCacheManager] Evicted \(toRemove.count) cache spaces using policy: \(policy)")

        return toRemove
    }

    public func evictExceedingSize(maxSizeInBytes: Int64) -> [String] {
        var currentSize: Int64 = 0
        var cacheSizes: [(String, Int64)] = []

        for cacheID in urlToCacheIDMap.values {
            if let stats = getCacheStats(cacheID: cacheID) {
                cacheSizes.append((cacheID, stats.totalSize))
                currentSize += stats.totalSize
            }
        }

        cacheSizes.sort { $0.1 > $1.1 }

        var removed: [String] = []

        for (cacheID, size) in cacheSizes {
            if currentSize <= maxSizeInBytes {
                break
            }

            removeCacheSpace(cacheID: cacheID)
            removed.append(cacheID)
            currentSize -= size
        }

        print("🧹 [WebResourceCacheManager] Evicted \(removed.count) cache spaces to fit size limit")

        return removed
    }

    public func evictOlderThan(maxAge: TimeInterval) -> [String] {
        let allStats = getAllCacheStats()
        let now = Date()

        let toRemove = allStats.filter { stats in
            now.timeIntervalSince(stats.createdAt) > maxAge
        }.map { $0.cacheID }

        for cacheID in toRemove {
            removeCacheSpace(cacheID: cacheID)
        }

        print("🧹 [WebResourceCacheManager] Evicted \(toRemove.count) old cache spaces (older than \(maxAge)s)")

        return toRemove
    }

    public func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.mapLock.lock()
            let cacheIDs = Array(self.urlToCacheIDMap.values)
            self.urlToCacheIDMap.removeAll()
            self.cacheAccessTimes.removeAll()
            self.mapLock.unlock()

            for cacheID in cacheIDs {
                let cacheDirectory = self.cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
                try? self.fileManager.removeItem(at: cacheDirectory)
            }

            self.sizeLock.lock()
            self.totalCacheSize = 0
            self.sizeLock.unlock()

            self.saveCacheIndex()
            self.updateTotalCacheSize()

            print("🗑️ [WebResourceCacheManager] Cleared all cache spaces (async)")
        }
    }

    public func cleanupUnusedResources(olderThan interval: TimeInterval) {
        queue.async {
            self.mapLock.lock()
            let now = Date()
            let expiredIDs = self.cacheAccessTimes.filter { now.timeIntervalSince($1) > interval }.map { $0.key }
            self.mapLock.unlock()

            for cacheID in expiredIDs {
                self.removeCacheSpace(cacheID: cacheID)
            }

            if !expiredIDs.isEmpty {
                print("🧹 [WebResourceCacheManager] Cleaned up \(expiredIDs.count) expired cache spaces")
            }
        }
    }

    func getSortedCacheIDs(by policy: LRUEvictionPolicy) -> [String] {
        let allStats = getAllCacheStats()

        switch policy {
        case .leastRecentlyUsed:
            return allStats.sorted { $0.lastAccessedAt < $1.lastAccessedAt }.map { $0.cacheID }
        case .oldest:
            return allStats.sorted { $0.createdAt < $1.createdAt }.map { $0.cacheID }
        case .largest:
            return allStats.sorted { $0.totalSize > $1.totalSize }.map { $0.cacheID }
        case .leastFrequentlyUsed:
            return allStats.sorted { $0.lastAccessedAt < $1.lastAccessedAt }.map { $0.cacheID }
        }
    }
}
