//
//  WebCacheManager.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import CommonCrypto
import Foundation
import RealmSwift
import RxCocoa
import RxSwift
import WebKit

// Framework imports

/// 网站缓存管理器
public class WebCacheManager {

    public static let shared = WebCacheManager()

    private let dataStore = WKWebsiteDataStore.default()

    private init() {}

    // MARK: - 缓存统计

    /// 获取所有网站的缓存统计
    public func fetchSystemCacheStatistics() -> Observable<[WebCacheStatistics]> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            // WKWebsiteDataStore 操作必须在主线程执行
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    observer.onCompleted()
                    return
                }
                let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

                self.dataStore.fetchDataRecords(ofTypes: dataTypes) { [weak self] records in
                    guard let self = self else {
                        observer.onCompleted()
                        return
                    }
                    let stats = self.groupRecordsByDomain(records)

                    // 保存到 Realm (可以在后台线程执行)
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        guard let self = self else {
                            DispatchQueue.main.async {
                                observer.onCompleted()
                            }
                            return
                        }
                        self.saveSystemCacheStatistics(stats)

                        DispatchQueue.main.async {
                            observer.onNext(stats)
                            observer.onCompleted()
                        }
                    }
                }
            }

            return Disposables.create()
        }
    }

    /// 按域名分组统计
    private func groupRecordsByDomain(_ records: [WKWebsiteDataRecord]) -> [WebCacheStatistics] {
        let domainGroups = Dictionary(grouping: records) { $0.displayName }

        return domainGroups.map { (domain, records) in
            let stats = WebCacheStatistics()
            stats.domain = domain
            stats.lastUpdate = Date()

            // 计算总大小（估算）
            var totalSize: Int64 = 0
            var fileCount = 0

            for record in records {
                totalSize += self.estimateSize(for: record)
                fileCount += 1
            }

            stats.totalSize = totalSize
            stats.fileCount = fileCount

            return stats
        }.sorted { $0.totalSize > $1.totalSize }
    }

    /// 自动清理逻辑已在 WebPageHistoryManager 中优化：会自动忽略收藏和置顶项
    /// 清理过期或低频使用的缓存资源
    public func performAutoCleanup() {
        Log.info("Starting auto cleanup...", category: .cache)

        // 异步执行清理任务，避免阻塞主线程（特别是应用启动时）
        DispatchQueue.global(qos: .utility).async {
            // 1. 清理低频历史记录 (由 WebPageHistoryManager 处理)
            WebPageHistoryManager.shared.cleanupLowFrequencyItems(limit: 50)

            // 2. 清理过期的拦截资源缓存 (已删除 InterceptiveCacheManager)
            // InterceptiveCacheManager.shared.cleanupExpiredCache()

            // 3. 清理未使用的资源缓存 (超过 7 天未访问)
            WebResourceCacheManager.shared.cleanupUnusedResources(olderThan: 7 * 24 * 3600)

            Log.info("Auto cleanup completed in background", category: .cache)
        }
    }

    /// 清理所有缓存
    public func clearAll() {
        // 1. 清理 WKWebView 网站数据 (必须在主线程执行)
        DispatchQueue.main.async {
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            let dateFrom = Date(timeIntervalSince1970: 0)
            self.dataStore.removeData(ofTypes: dataTypes, modifiedSince: dateFrom) {
                Log.info("Cleared all WKWebView website data", category: .cache)
            }
        }

        // 2. 清理自定义缓存管理器 (这些通常是内部异步的)
        ManifestCacheManager.shared.clearAll()
        WebResourceCacheManager.shared.clearAll()
        // InterceptiveCacheManager.shared.clearAllCache()  // 已删除
        NotificationCenter.default.post(name: .clearAllCaches, object: nil)

        // 3. 清理 Realm 统计数据 (必须在后台线程执行，避免 Realm 跨线程访问)
        DispatchQueue.global(qos: .utility).async {
            if let realm = try? Realm() {
                try? realm.write {
                    realm.delete(realm.objects(WebCacheStatistics.self))
                }
                Log.info("Cleared Realm statistics", category: .cache)
            }
        }

        Log.info("All caches clearing triggered (WebView data on main, Realm on background)", category: .cache)
    }

    /// 清理特定域名的缓存
    public func clearCache(for domain: String) -> Observable<Void> {
        return Observable.create { observer in
            // WKWebsiteDataStore 操作必须在主线程执行
            DispatchQueue.main.async {
                let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

                self.dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                    let targetRecords = records.filter { $0.displayName == domain }

                    self.dataStore.removeData(ofTypes: dataTypes, for: targetRecords) {
                        // 从 Realm 中删除统计 (必须在后台线程执行，避免 Realm 跨线程访问)
                        DispatchQueue.global(qos: .utility).async {
                            // 在后台线程创建新的 Realm 实例
                            if let realm = try? Realm() {
                                try? realm.write {
                                    if let stat = realm.object(ofType: WebCacheStatistics.self, forPrimaryKey: domain) {
                                        realm.delete(stat)
                                    }
                                }
                            }

                            DispatchQueue.main.async {
                                observer.onNext(())
                                observer.onCompleted()
                            }
                        }
                    }
                }
            }

            return Disposables.create()
        }
    }

    /// 清理所有缓存
    public func clearAllCache() -> Observable<Void> {
        return Observable.create { observer in
            // WKWebsiteDataStore 操作必须在主线程执行
            DispatchQueue.main.async {
                let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
                let from = Date.distantPast

                WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: from) {
                    // 清空 Realm 中的统计 (必须在后台线程执行，避免 Realm 跨线程访问)
                    DispatchQueue.global(qos: .utility).async {
                        // 在后台线程创建新的 Realm 实例
                        if let realm = try? Realm() {
                            try? realm.write {
                                realm.delete(realm.objects(WebCacheStatistics.self))
                            }
                        }

                        DispatchQueue.main.async {
                            observer.onNext(())
                            observer.onCompleted()
                        }
                    }
                }
            }

            return Disposables.create()
        }
    }

    // MARK: - URL 缓存检查

    /// 检查 URL 是否已缓存
    public func isURLCached(_ url: URL) -> Bool {
        return URLCache.shared.cachedResponse(for: URLRequest(url: url)) != nil
    }

    /// 预加载 URL
    public func preloadURL(_ url: URL) -> Observable<Void> {
        return Observable.create { observer in
            let request = URLRequest(url: url)
            let task = URLSession.shared.dataTask(with: request) { _, _, _ in
                observer.onNext(())
                observer.onCompleted()
            }
            task.resume()

            return Disposables.create {
                task.cancel()
            }
        }
    }

    // MARK: - Realm 操作

    private func deleteSystemCacheStatistics(for domain: String) {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            if let stat = realm.object(ofType: WebCacheStatistics.self, forPrimaryKey: domain) {
                realm.delete(stat)
            }
        }
    }

    private func clearAllSystemCacheStatistics() {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            realm.delete(realm.objects(WebCacheStatistics.self))
        }
    }

    /// 获取缓存的域名列表
    public func getCachedDomains() -> [WebCacheStatistics] {
        var results: [WebCacheStatistics] = []
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            if let realm = try? Realm() {
                let stats = realm.objects(WebCacheStatistics.self).sorted(byKeyPath: "totalSize", ascending: false)
                // 必须在当前线程冻结对象或转换为数组，才能跨线程传递
                results = Array(stats.map { stat -> WebCacheStatistics in
                    let newStat = WebCacheStatistics()
                    newStat.domain = stat.domain
                    newStat.totalSize = stat.totalSize
                    newStat.fileCount = stat.fileCount
                    newStat.lastUpdate = stat.lastUpdate
                    return newStat
                })
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
        return results
    }

    /// 获取总缓存大小
    public func getTotalCacheSize() -> Int64 {
        var size: Int64 = 0
        // 使用同步方式获取，但必须确保线程安全
        // 建议在 UI 上显示时使用异步版本，这里保留同步版本供内部调用
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            if let realm = try? Realm() {
                size = realm.objects(WebCacheStatistics.self).sum(of: \WebCacheStatistics.totalSize)
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.0)
        return size
    }

    // MARK: - 压缩缓存管理 (WebCompressedCacheStore)

    /// Glob 模式删除压缩缓存
    /// - Parameter pattern: Glob 模式（如 `https://example.com/*.js`）
    /// - Returns: 删除的条目数量
    public func deleteCacheByGlob(pattern: String) -> Observable<Int> {
        return Observable.create { observer in
            do {
                let deletedCount = try WebCompressedCacheStore.shared.deleteByGlob(pattern: pattern)
                observer.onNext(deletedCount)
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }

    /// 获取压缩缓存的内存信息
    public func getCacheMemoryInfo() -> Observable<CacheMemoryInfo> {
        return Observable.create { observer in
            let memoryInfo = WebCompressedCacheStore.shared.getMemoryInfo()
            observer.onNext(memoryInfo)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    /// 获取详细的压缩缓存条目
    /// - Parameter filterPattern: 可选的 Glob 过滤模式
    /// - Returns: 缓存条目信息数组
    public func getDetailedCacheEntries(filterPattern: String? = nil) -> Observable<[CacheEntryInfo]> {
        return Observable.create { observer in
            var entries = WebCompressedCacheStore.shared.getAllEntries()

            // 如果有过滤模式，应用过滤
            if let pattern = filterPattern {
                entries = entries.filter { GlobPattern.matches(pattern, against: $0.url) }
            }

            observer.onNext(entries)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    /// 按域名分组获取压缩缓存条目
    /// - Returns: [域名: 缓存条目数组]
    public func getCacheEntriesGroupedByDomain() -> Observable<[String: [CacheEntryInfo]]> {
        return Observable.create { observer in
            let groupedEntries = WebCompressedCacheStore.shared.getEntriesGroupedByDomain()
            observer.onNext(groupedEntries)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    /// 检查资源是否已缓存（增强版，返回详细信息）
    /// - Parameter url: 资源 URL
    /// - Returns: (是否已缓存, 缓存条目信息)
    public func isResourceCached(url: URL) -> (cached: Bool, info: CacheEntryInfo?) {
        // 生成缓存键（使用 URL 的 SHA256 hash）
        let key = url.sha256

        if let entryInfo = WebCompressedCacheStore.shared.getEntryInfo(key: key) {
            return (true, entryInfo)
        }

        return (false, nil)
    }

    /// 预加载 URL 到压缩缓存
    /// - Parameter url: 要预加载的 URL
    /// - Returns: 进度 Observable
    public func preloadToCompressedCache(url: URL) -> Observable<Progress> {
        return Observable.create { observer in
            let progress = Progress(totalUnitCount: 100)

            // 创建 URL 会话
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration)

            let task = session.dataTask(with: url) { data, response, error in
                if let error = error {
                    observer.onError(error)
                    return
                }

                guard let data = data,
                      let response = response as? HTTPURLResponse else {
                    observer.onError(NSError(domain: "WebCacheManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }

                // 获取 MIME 类型
                let mimeType = response.mimeType ?? "application/octet-stream"

                // 获取 ETag
                let etag = response.value(forHTTPHeaderField: "ETag")

                // 获取最后修改时间
                var lastModified: Date?
                if let lastModifiedString = response.value(forHTTPHeaderField: "Last-Modified"),
                   let rfc1123 = DateFormatter.rfc1123.date(from: lastModifiedString) {
                    lastModified = rfc1123
                }

                // 保存到压缩缓存
                let key = url.sha256
                do {
                    try WebCompressedCacheStore.shared.save(
                        data: data,
                        forKey: key,
                        url: url.absoluteString,
                        mimeType: mimeType,
                        etag: etag,
                        lastModified: lastModified
                    )
                    progress.completedUnitCount = 100
                    observer.onNext(progress)
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
            }

            task.resume()
            progress.completedUnitCount = 50

            return Disposables.create {
                task.cancel()
            }
        }
    }

    /// 清空所有压缩缓存
    public func clearAllCompressedCache() -> Observable<Void> {
        return Observable.create { observer in
            WebCompressedCacheStore.shared.clearAll()
            observer.onNext(())
            observer.onCompleted()
            return Disposables.create()
        }
    }

    // MARK: - Helper Methods

    private func saveSystemCacheStatistics(_ stats: [WebCacheStatistics]) {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            realm.add(stats, update: .modified)
        }
    }

    private func estimateSize(for record: WKWebsiteDataRecord) -> Int64 {
        // 由于 WKWebsiteDataRecord 不直接提供大小，我们只能估算
        // 这里的估算逻辑比较简单，实际应用中可能需要更复杂的方法
        var size: Int64 = 0
        let dataTypes = record.dataTypes

        if dataTypes.contains(WKWebsiteDataTypeDiskCache) { size += 1024 * 1024 } // 1MB
        if dataTypes.contains(WKWebsiteDataTypeMemoryCache) { size += 512 * 1024 } // 512KB
        if dataTypes.contains(WKWebsiteDataTypeOfflineWebApplicationCache) { size += 2 * 1024 * 1024 } // 2MB
        if dataTypes.contains(WKWebsiteDataTypeLocalStorage) { size += 256 * 1024 } // 256KB
        if dataTypes.contains(WKWebsiteDataTypeCookies) { size += 4 * 1024 } // 4KB
        if dataTypes.contains(WKWebsiteDataTypeSessionStorage) { size += 128 * 1024 } // 128KB
        if dataTypes.contains(WKWebsiteDataTypeIndexedDBDatabases) { size += 512 * 1024 } // 512KB
        if dataTypes.contains(WKWebsiteDataTypeWebSQLDatabases) { size += 512 * 1024 } // 512KB

        return size
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let rfc1123: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - URL Extension

public extension URL {
    /// SHA256 哈希值（用作缓存键）
    var sha256: String {
        let str = self.absoluteString
        let data = Data(str.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
