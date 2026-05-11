//
//  CompressedCacheMethods.swift
//  WebBridgeKit
//
//  压缩缓存相关操作方法
//

import Foundation

extension WebCacheDebugHandler {

    // MARK: - 压缩缓存方法 (保留)

    func getCacheInfo(completion: @escaping (Any) -> Void) {
        let memoryInfo = WebCompressedCacheStore.shared.getMemoryInfo()
        let entries = WebCompressedCacheStore.shared.getAllEntries()

        let domainStats = Dictionary(grouping: entries) { $0.domain }
            .mapValues { entries in
                let totalOriginalSize = entries.reduce(0) { $0 + $1.originalSize }
                let totalCompressedSize = entries.reduce(0) { $0 + $1.compressedSize }
                return [
                    "count": entries.count,
                    "originalSize": totalOriginalSize,
                    "compressedSize": totalCompressedSize,
                    "savedSpace": totalOriginalSize - totalCompressedSize
                ]
            }

        let result: [String: Any] = [
            "success": true,
            "data": [
                "totalEntries": memoryInfo.totalEntries,
                "totalOriginalSize": memoryInfo.totalOriginalSize,
                "totalCompressedSize": memoryInfo.totalCompressedSize,
                "compressionRatio": memoryInfo.compressionRatio,
                "savedSpace": memoryInfo.savedSpace,
                "formattedTotalOriginalSize": memoryInfo.formattedTotalOriginalSize,
                "formattedTotalCompressedSize": memoryInfo.formattedTotalCompressedSize,
                "formattedSavedSpace": memoryInfo.formattedSavedSpace,
                "formattedCompressionRatio": memoryInfo.formattedCompressionRatio,
                "domainStats": domainStats
            ]
        ]

        resolve(result, completion: completion)
    }

    func getMemoryInfo(completion: @escaping (Any) -> Void) {
        let memoryInfo = WebCompressedCacheStore.shared.getMemoryInfo()

        let result: [String: Any] = [
            "success": true,
            "data": [
                "totalEntries": memoryInfo.totalEntries,
                "totalOriginalSize": memoryInfo.totalOriginalSize,
                "totalCompressedSize": memoryInfo.totalCompressedSize,
                "compressionRatio": memoryInfo.compressionRatio,
                "savedSpace": memoryInfo.savedSpace,
                "formattedTotalOriginalSize": memoryInfo.formattedTotalOriginalSize,
                "formattedTotalCompressedSize": memoryInfo.formattedTotalCompressedSize,
                "formattedSavedSpace": memoryInfo.formattedSavedSpace,
                "formattedCompressionRatio": memoryInfo.formattedCompressionRatio
            ]
        ]

        resolve(result, completion: completion)
    }

    func getEntries(filter: String?, completion: @escaping (Any) -> Void) {
        var entries = WebCompressedCacheStore.shared.getAllEntries()

        if let pattern = filter {
            entries = entries.filter { GlobPattern.matches(pattern, against: $0.url) }
        }

        let result: [String: Any] = [
            "success": true,
            "data": [
                "count": entries.count,
                "entries": entries.map { $0.toDictionary() }
            ]
        ]

        resolve(result, completion: completion)
    }

    func getEntriesGroupedByDomain(completion: @escaping (Any) -> Void) {
        let groupedEntries = WebCompressedCacheStore.shared.getEntriesGroupedByDomain()

        let result: [String: Any] = [
            "success": true,
            "data": [
                "domains": groupedEntries.mapValues { entries in
                    entries.map { $0.toDictionary() }
                }
            ]
        ]

        resolve(result, completion: completion)
    }

    func checkIsCached(url: URL, completion: @escaping (Any) -> Void) {
        let key = url.sha256
        let isCached = WebCompressedCacheStore.shared.exists(key: key)
        let info = WebCompressedCacheStore.shared.getEntryInfo(key: key)

        var result: [String: Any] = [
            "success": true,
            "url": url.absoluteString,
            "cached": isCached
        ]

        if let info = info {
            result["info"] = info.toDictionary()
        }

        resolve(result, completion: completion)
    }

    func deleteByPattern(pattern: String, completion: @escaping (Any) -> Void) {
        do {
            let deletedCount = try WebCompressedCacheStore.shared.deleteByGlob(pattern: pattern)

            let result: [String: Any] = [
                "success": true,
                "deletedCount": deletedCount,
                "pattern": pattern
            ]

            resolve(result, completion: completion)
        } catch {
            reject(error: "Delete failed: \(error.localizedDescription)", completion: completion)
        }
    }

    func deleteByKey(key: String, completion: @escaping (Any) -> Void) {
        let success = WebCompressedCacheStore.shared.delete(key: key)

        let result: [String: Any] = [
            "success": success,
            "key": key
        ]

        if success {
            resolve(result, completion: completion)
        } else {
            reject(error: "Cache entry not found", completion: completion)
        }
    }

    func clearAll(completion: @escaping (Any) -> Void) {
        WebCompressedCacheStore.shared.clearAll()

        let result: [String: Any] = [
            "success": true,
            "message": "All cache cleared"
        ]

        resolve(result, completion: completion)
    }

    func getConfig(completion: @escaping (Any) -> Void) {
        let config = WebCompressedCacheStore.shared.config

        let result: [String: Any] = [
            "success": true,
            "config": [
                "enableCompression": config.enableCompression,
                "compressionThreshold": config.compressionThreshold,
                "compressionLevel": config.compressionLevel,
                "maxCacheSize": config.maxCacheSize,
                "maxFileSize": config.maxFileSize,
                "formattedMaxCacheSize": ByteCountFormatter.string(fromByteCount: config.maxCacheSize, countStyle: .file),
                "formattedMaxFileSize": ByteCountFormatter.string(fromByteCount: Int64(config.maxFileSize), countStyle: .file)
            ]
        ]

        resolve(result, completion: completion)
    }

    func setConfig(configParams: [String: Any], completion: @escaping (Any) -> Void) {
        var config = WebCompressedCacheStore.shared.config

        if let enableCompression = configParams["enableCompression"] as? Bool {
            config.enableCompression = enableCompression
        }

        if let compressionThreshold = configParams["compressionThreshold"] as? Int {
            config.compressionThreshold = compressionThreshold
        }

        if let compressionLevel = configParams["compressionLevel"] as? Int {
            config.compressionLevel = min(9, max(0, compressionLevel))
        }

        if let maxCacheSize = configParams["maxCacheSize"] as? Int64 {
            config.maxCacheSize = maxCacheSize
        }

        if let maxFileSize = configParams["maxFileSize"] as? Int {
            config.maxFileSize = maxFileSize
        }

        WebCompressedCacheStore.shared.config = config

        let result: [String: Any] = [
            "success": true,
            "message": "Config updated",
            "config": [
                "enableCompression": config.enableCompression,
                "compressionThreshold": config.compressionThreshold,
                "compressionLevel": config.compressionLevel,
                "maxCacheSize": config.maxCacheSize,
                "maxFileSize": config.maxFileSize
            ]
        ]

        resolve(result, completion: completion)
    }
}
