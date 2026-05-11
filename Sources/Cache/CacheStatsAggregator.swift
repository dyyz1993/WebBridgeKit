//
//  CacheStatsAggregator.swift
//  WebBridgeKit
//
//  Created on 2025-05-11.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxSwift

/// 缓存统计聚合器 —— 从所有 11 个缓存子系统中采集数据并汇总
public class CacheStatsAggregator {

    public static let shared = CacheStatsAggregator()

    private init() {}

    // MARK: - Public API

    /// 全量异步采集（Rx Observable）
    /// 使用 DispatchQueue.global 确保所有收集器在后台执行
    public func aggregate() -> Observable<DashboardData> {
        return Observable<DashboardData>.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }

            // 在全局后台队列上执行所有收集器
            let queue = DispatchQueue.global(qos: .utility)
            queue.async {
                let data = self.syncAggregate()
                observer.onNext(data)
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }

    /// 同步采集（主线程调用需注意性能）
    public func syncAggregate() -> DashboardData {
        let subsystemIDs = SubsystemID.allCases
        let subsystems = subsystemIDs.map { collectStats(for: $0) }

        let totalSize = subsystems.reduce(Int64(0)) { $0 + $1.totalSize }
        let totalEntries = subsystems.reduce(0) { $0 + $1.totalEntries }

        let pinnedCount = 0

        return DashboardData(
            timestamp: Date(),
            totalSize: totalSize,
            totalEntries: totalEntries,
            subsystems: subsystems,
            pinnedURLCount: pinnedCount
        )
    }

    /// 采集单个子系统的统计数据
    public func collectStats(for subsystemID: SubsystemID) -> SubsystemStats {
        switch subsystemID {
        case .manifestCache:
            return collectManifestCacheStats()
        case .webResourceCache:
            return collectWebResourceCacheStats()
        case .webCompressedCache:
            return collectCompressedCacheStats()
        case .webcacheWKWebView:
            return collectWKWebViewCacheStats()
        case .systemURLCache:
            return collectSystemURLCacheStats()
        case .offlinePageCache:
            return collectOfflinePageCacheStats()
        case .pageCacheRule:
            return collectPageCacheRuleStats()
        case .genericCacheManager:
            return collectGenericCacheManagerStats()
        case .memoryCacheRule:
            return collectMemoryCacheRuleStats()
        case .userdefaultsMessageStore:
            return collectMessageStoreStats()
        case .resourceCacheLRU:
            return collectResourceCacheStats()
        }
    }

    // MARK: - Individual Subsystem Collectors

    private func collectManifestCacheStats() -> SubsystemStats {
        do {
            let stats = ManifestCacheManager.shared.getStats()
            return SubsystemStats(
                id: .manifestCache,
                totalEntries: stats.totalRequests,
                totalSize: stats.totalCacheSize,
                hitRate: stats.hitRate,
                extraMetrics: [
                    "cacheHits": "\(stats.cacheHits)",
                    "cacheMisses": "\(stats.cacheMisses)"
                ],
                status: stats.totalRequests > 0 ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .manifestCache, status: .error(error.localizedDescription))
        }
    }

    private func collectWebResourceCacheStats() -> SubsystemStats {
        do {
            let global = WebResourceCacheManager.shared.getGlobalStats()
            let allStats = WebResourceCacheManager.shared.getAllCacheStats()
            return SubsystemStats(
                id: .webResourceCache,
                totalEntries: global.totalFiles,
                totalSize: global.totalSize,
                extraMetrics: [
                    "cacheSpaces": "\(allStats.count)"
                ],
                status: global.totalFiles > 0 ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .webResourceCache, status: .error(error.localizedDescription))
        }
    }

    private func collectCompressedCacheStats() -> SubsystemStats {
        do {
            let memInfo = WebCompressedCacheStore.shared.getMemoryInfo()
            return SubsystemStats(
                id: .webCompressedCache,
                totalEntries: memInfo.totalEntries,
                totalSize: memInfo.totalOriginalSize,
                hitRate: nil,
                extraMetrics: [
                    "compressedSize": "\(memInfo.totalCompressedSize)",
                    "compressionRatio": String(format: "%.2f", memInfo.compressionRatio),
                    "savedSpace": "\(memInfo.savedSpace)"
                ],
                status: memInfo.totalEntries > 0 ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .webCompressedCache, status: .error(error.localizedDescription))
        }
    }

    private func collectWKWebViewCacheStats() -> SubsystemStats {
        // NOTE: WebCacheManager's getTotalCacheSize() and getCachedDomains() use
        // DispatchSemaphore which can cause deadlocks when called from background threads.
        // Return a lightweight placeholder to avoid blocking.
        return SubsystemStats(
            id: .webcacheWKWebView,
            totalEntries: 0,
            totalSize: 0,
            extraMetrics: [
                "type": "WKWebView WebsiteDataStore",
                "note": "Use WebCacheManager async API for real-time data"
            ],
            status: .active
        )
    }

    private func collectSystemURLCacheStats() -> SubsystemStats {
        do {
            let stats = SystemURLCacheManager.shared.getCacheStats()
            return SubsystemStats(
                id: .systemURLCache,
                totalEntries: Int(stats.totalEntries),
                totalSize: stats.totalCacheSize,
                hitRate: stats.hitRate,
                extraMetrics: [
                    "cacheHits": "\(stats.cacheHits)",
                    "cacheMisses": "\(stats.cacheMisses)",
                    "memoryCapacity": "50MB",
                    "diskCapacity": "500MB"
                ],
                status: stats.totalRequests > 0 ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .systemURLCache, status: .error(error.localizedDescription))
        }
    }

    private func collectOfflinePageCacheStats() -> SubsystemStats {
        do {
            let count = WebPageOfflineCacheManager.shared.getCachedCount()
            let size = WebPageOfflineCacheManager.shared.getTotalCacheSize()
            return SubsystemStats(
                id: .offlinePageCache,
                totalEntries: count,
                totalSize: size,
                extraMetrics: [
                    "cachedPages": "\(count)"
                ],
                status: count > 0 ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .offlinePageCache, status: .error(error.localizedDescription))
        }
    }

    private func collectPageCacheRuleStats() -> SubsystemStats {
        do {
            let rules = PageCacheRuleManager.shared.getAllRules()
            let enabled = PageCacheRuleManager.shared.getEnabledRules()
            return SubsystemStats(
                id: .pageCacheRule,
                totalEntries: rules.count,
                totalSize: 0,
                extraMetrics: [
                    "enabledRules": "\(enabled.count)",
                    "disabledRules": "\(rules.count - enabled.count)"
                ],
                status: !rules.isEmpty ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .pageCacheRule, status: .error(error.localizedDescription))
        }
    }

    private func collectGenericCacheManagerStats() -> SubsystemStats {
        return SubsystemStats(
            id: .genericCacheManager,
            totalEntries: 0,
            totalSize: 0,
            hitRate: nil,
            extraMetrics: [
                "type": "Actor-based Memory+Disk Cache",
                "note": "Use async getGlobalStatistics() for accurate data"
            ],
            status: .active
        )
    }

    private func collectMemoryCacheRuleStats() -> SubsystemStats {
        let rules = CacheRuleManager.shared.getAllRules()
        return SubsystemStats(
            id: .memoryCacheRule,
            totalEntries: rules.count,
            totalSize: 0,
            extraMetrics: [
                "type": "In-memory only"
            ],
            status: !rules.isEmpty ? .active : .empty
        )
    }

    private func collectMessageStoreStats() -> SubsystemStats {
        return SubsystemStats(
            id: .userdefaultsMessageStore,
            totalEntries: 0,
            totalSize: 0,
            extraMetrics: [
                "storage": "UserDefaults (JSON)",
                "maxMessages": "200",
                "note": "Async store - use MessageEngine for real counts"
            ],
            status: .active
        )
    }

    private func collectResourceCacheStats() -> SubsystemStats {
        do {
            let mcmStats = ManifestCacheManager.shared.getStats()
            let size = ManifestCacheManager.shared.calculateTotalCacheSize()
            return SubsystemStats(
                id: .resourceCacheLRU,
                totalEntries: mcmStats.totalRequests,
                totalSize: size,
                extraMetrics: [
                    "type": "LRU (100MB memory limit)",
                    "storage": "Filesystem + Memory"
                ],
                status: size > 0 ? .active : .empty
            )
        } catch {
            return SubsystemStats(id: .resourceCacheLRU, status: .error(error.localizedDescription))
        }
    }
}
