//
//  DashboardModels.swift
//  WebBridgeKit
//
//  Created on 2025-05-11.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

// MARK: - 缓存子系统 ID 枚举（对应 11 个管理器）

public enum SubsystemID: String, CaseIterable, Codable {
    case manifestCache = "manifest_cache"
    case webResourceCache = "web_resource_cache"
    case webCompressedCache = "web_compressed_cache"
    case webcacheWKWebView = "webcache_wkwebview"
    case systemURLCache = "system_url_cache"
    case offlinePageCache = "offline_page_cache"
    case pageCacheRule = "page_cache_rule"
    case genericCacheManager = "generic_cache_manager"
    case memoryCacheRule = "memory_cache_rule"
    case userdefaultsMessageStore = "userdefaults_message_store"
    case resourceCacheLRU = "resource_cache_lru"

    public var name: String {
        switch self {
        case .manifestCache: return "Manifest Cache"
        case .webResourceCache: return "Web Resource Cache"
        case .webCompressedCache: return "Compressed Cache"
        case .webcacheWKWebView: return "WKWebView Cache"
        case .systemURLCache: return "System URL Cache"
        case .offlinePageCache: return "Offline Page Cache"
        case .pageCacheRule: return "Page Cache Rules"
        case .genericCacheManager: return "Generic Cache Manager"
        case .memoryCacheRule: return "Memory Cache Rules"
        case .userdefaultsMessageStore: return "Message Store"
        case .resourceCacheLRU: return "Resource Cache (LRU)"
        }
    }

    public var nameZh: String {
        switch self {
        case .manifestCache: return "Manifest 缓存"
        case .webResourceCache: return "Web 资源缓存"
        case .webCompressedCache: return "压缩缓存"
        case .webcacheWKWebView: return "WKWebView 缓存"
        case .systemURLCache: return "系统 HTTP 缓存"
        case .offlinePageCache: return "离线页面缓存"
        case .pageCacheRule: return "页面缓存规则"
        case .genericCacheManager: return "通用缓存管理器"
        case .memoryCacheRule: return "内存缓存规则"
        case .userdefaultsMessageStore: return "消息存储"
        case .resourceCacheLRU: return "资源缓存 (LRU)"
        }
    }

    public var iconName: String {
        switch self {
        case .manifestCache: return "file-json"
        case .webResourceCache: return "hard-drive"
        case .webCompressedCache: return "archive"
        case .webcacheWKWebView: return "globe"
        case .systemURLCache: return "server"
        case .offlinePageCache: return "download-cloud"
        case .pageCacheRule: return "list-checks"
        case .genericCacheManager: return "database"
        case .memoryCacheRule: return "brain"
        case .userdefaultsMessageStore: return "message-square"
        case .resourceCacheLRU: return "layers"
        }
    }
}

// MARK: - 子系统状态

public enum SubsystemStatus: Equatable {
    case active
    case empty
    case error(String)
    case unknown

    public var displayText: String {
        switch self {
        case .active: return "运行中"
        case .empty: return "空闲"
        case .error(let msg): return "错误: \(msg)"
        case .unknown: return "未知"
        }
    }

    public var statusColorName: String {
        switch self {
        case .active: return "success"
        case .empty: return "textSecondary"
        case .error: return "error"
        case .unknown: return "textTertiary"
        }
    }
}

// MARK: - 单个子系统统计数据

public struct SubsystemStats: Equatable {
    public let id: SubsystemID
    public let totalEntries: Int
    public let totalSize: Int64
    public let hitRate: Double?
    public let extraMetrics: [String: String]
    public let status: SubsystemStatus
    public let lastUpdated: Date

    public init(
        id: SubsystemID,
        totalEntries: Int = 0,
        totalSize: Int64 = 0,
        hitRate: Double? = nil,
        extraMetrics: [String: String] = [:],
        status: SubsystemStatus = .unknown,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.totalEntries = totalEntries
        self.totalSize = totalSize
        self.hitRate = hitRate
        self.extraMetrics = extraMetrics
        self.status = status
        self.lastUpdated = lastUpdated
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var formattedHitRate: String? {
        guard let hr = hitRate else { return nil }
        return String(format: "%.1f%%", hr * 100)
    }

    public var hasData: Bool { totalEntries > 0 || totalSize > 0 }
}

// MARK: - Dashboard 聚合数据

public struct DashboardData: Equatable {
    public let timestamp: Date
    public let totalSize: Int64
    public let totalEntries: Int
    public let subsystems: [SubsystemStats]
    public let pinnedURLCount: Int

    public init(
        timestamp: Date = Date(),
        totalSize: Int64 = 0,
        totalEntries: Int = 0,
        subsystems: [SubsystemStats] = [],
        pinnedURLCount: Int = 0
    ) {
        self.timestamp = timestamp
        self.totalSize = totalSize
        self.totalEntries = totalEntries
        self.subsystems = subsystems
        self.pinnedURLCount = pinnedURLCount
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var activeSubsystemCount: Int {
        subsystems.filter { $0.hasData }.count
    }

    public var subsystemsWithHitRate: [SubsystemStats] {
        subsystems.filter { $0.hitRate != nil }
    }

    public var averageHitRate: Double? {
        let hits = subsystemsWithHitRate
        guard !hits.isEmpty else { return nil }
        return hits.compactMap { $0.hitRate }.reduce(0, +) / Double(hits.count)
    }

    public var sizeDistribution: [(name: String, size: Int64, percentage: Double)] {
        let active = subsystems.filter { $0.totalSize > 0 }
        guard !active.isEmpty else { return [] }
        let total = totalSize
        return active.compactMap { s -> (name: String, size: Int64, percentage: Double)? in
            guard total > 0 else { return nil }
            return (s.id.nameZh, s.totalSize, Double(s.totalSize) / Double(total) * 100)
        }.sorted { $0.percentage > $1.percentage }
    }

    public var byStatus: (active: [SubsystemStats], empty: [SubsystemStats], error: [SubsystemStats]) {
        var active: [SubsystemStats] = []
        var empty: [SubsystemStats] = []
        var error: [SubsystemStats] = []
        for s in subsystems {
            switch s.status {
            case .active: active.append(s)
            case .empty: empty.append(s)
            case .error: error.append(s)
            case .unknown:
                if s.hasData { active.append(s) } else { empty.append(s) }
            }
        }
        return (active, empty, error)
    }
}

// MARK: - PinnedURL 摘要

public struct PinnedURLSummary: Equatable {
    public let totalCount: Int
    public let pinnedCount: Int
    public let typeDistribution: [URLType: Int]
    public let topDomains: [(domain: String, count: Int)]

    public init(
        totalCount: Int = 0,
        pinnedCount: Int = 0,
        typeDistribution: [URLType: Int] = [:],
        topDomains: [(domain: String, count: Int)] = []
    ) {
        self.totalCount = totalCount
        self.pinnedCount = pinnedCount
        self.typeDistribution = typeDistribution
        self.topDomains = topDomains
    }

    public static func == (lhs: PinnedURLSummary, rhs: PinnedURLSummary) -> Bool {
        lhs.totalCount == rhs.totalCount &&
        lhs.pinnedCount == rhs.pinnedCount &&
        lhs.typeDistribution == rhs.typeDistribution &&
        lhs.topDomains.count == rhs.topDomains.count &&
            !zip(lhs.topDomains, rhs.topDomains).contains { $0 != $1 }
    }
}
