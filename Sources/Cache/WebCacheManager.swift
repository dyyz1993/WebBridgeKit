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
class WebCacheManager {

    static let shared = WebCacheManager()

    private let dataStore = WKWebsiteDataStore.default()

    private init() {}

    // MARK: - 缓存统计

    /// 获取所有网站的缓存统计
    func fetchCacheStatistics() -> Observable<[WebCacheStatistics]> {
        return Observable.create { observer in
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

            self.dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                let stats = self.groupRecordsByDomain(records)

                // 保存到 Realm
                self.saveCacheStatistics(stats)

                observer.onNext(stats)
                observer.onCompleted()
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

    /// 估算缓存大小
    private func estimateSize(for record: WKWebsiteDataRecord) -> Int64 {
        // WKWebsiteDataRecord 不直接提供大小信息
        // 使用固定估算值（可以后续优化）
        return 1024 * 1024 // 假设每个记录 1MB
    }

    /// 保存缓存统计到 Realm
    private func saveCacheStatistics(_ stats: [WebCacheStatistics]) {
        guard let realm = try? Realm() else { return }

        try? realm.write {
            for stat in stats {
                realm.add(stat, update: .modified)
            }
        }
    }

    // MARK: - 缓存清理

    /// 清理指定域名的缓存
    func clearCache(for domain: String) -> Observable<Void> {
        return Observable.create { observer in
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

            self.dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                let targetRecords = records.filter { $0.displayName == domain }

                self.dataStore.removeData(ofTypes: dataTypes, for: targetRecords) {
                    // 从 Realm 中删除统计
                    self.deleteCacheStatistics(for: domain)

                    observer.onNext(())
                    observer.onCompleted()
                }
            }

            return Disposables.create()
        }
    }

    /// 清理所有缓存
    func clearAllCache() -> Observable<Void> {
        return Observable.create { observer in
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            let from = Date.distantPast

            WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: from) {
                // 清空 Realm 中的统计
                self.clearAllCacheStatistics()

                observer.onNext(())
                observer.onCompleted()
            }

            return Disposables.create()
        }
    }

    // MARK: - URL 缓存检查

    /// 检查 URL 是否已缓存
    func isURLCached(_ url: URL) -> Bool {
        return URLCache.shared.cachedResponse(for: URLRequest(url: url)) != nil
    }

    /// 预加载 URL
    func preloadURL(_ url: URL) -> Observable<Void> {
        return Observable.create { observer in
            let request = URLRequest(url: url)
            let task = URLSession.shared.dataTask(with: request) { _, response, _ in
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

    private func deleteCacheStatistics(for domain: String) {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            if let stat = realm.object(ofType: WebCacheStatistics.self, forPrimaryKey: domain) {
                realm.delete(stat)
            }
        }
    }

    private func clearAllCacheStatistics() {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            realm.delete(realm.objects(WebCacheStatistics.self))
        }
    }

    /// 获取缓存的域名列表
    func getCachedDomains() -> Results<WebCacheStatistics>? {
        guard let realm = try? Realm() else { return nil }
        return realm.objects(WebCacheStatistics.self)
            .sorted(byKeyPath: "totalSize", ascending: false)
    }

    /// 获取总缓存大小
    func getTotalCacheSize() -> Int64 {
        guard let realm = try? Realm() else { return 0 }
        return realm.objects(WebCacheStatistics.self)
            .sum(of: \WebCacheStatistics.totalSize)
    }

    // MARK: - 压缩缓存管理 (WebCompressedCacheStore)

    /// Glob 模式删除压缩缓存
    /// - Parameter pattern: Glob 模式（如 `https://example.com/*.js`）
    /// - Returns: 删除的条目数量
    func deleteCacheByGlob(pattern: String) -> Observable<Int> {
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
    func getCacheMemoryInfo() -> Observable<CacheMemoryInfo> {
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
    func getDetailedCacheEntries(filterPattern: String? = nil) -> Observable<[CacheEntryInfo]> {
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
    func getCacheEntriesGroupedByDomain() -> Observable<[String: [CacheEntryInfo]]> {
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
    func isResourceCached(url: URL) -> (cached: Bool, info: CacheEntryInfo?) {
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
    func preloadToCompressedCache(url: URL) -> Observable<Progress> {
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
    func clearAllCompressedCache() -> Observable<Void> {
        return Observable.create { observer in
            WebCompressedCacheStore.shared.clearAll()
            observer.onNext(())
            observer.onCompleted()
            return Disposables.create()
        }
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
        guard let data = self.absoluteString.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
