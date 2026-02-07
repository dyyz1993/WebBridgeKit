//
//  CacheModels.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-01.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

// MARK: - CachedResource

/// 缓存的资源
public struct CachedResource {
    public let url: URL
    public let data: Data
    public let mimeType: String
    public let cachedAt: Date

    public init(url: URL, data: Data, mimeType: String, cachedAt: Date) {
        self.url = url
        self.data = data
        self.mimeType = mimeType
        self.cachedAt = cachedAt
    }

    /// 缓存年龄（秒）
    public var age: TimeInterval {
        return Date().timeIntervalSince(cachedAt)
    }

    /// 是否过期
    public func isExpired(maxAge: TimeInterval) -> Bool {
        return age > maxAge
    }

    /// 格式化的缓存大小
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

// MARK: - CacheMetadata

/// 缓存元数据
public struct CacheMetadata {
    public let url: URL
    public let localPath: String
    public let mimeType: String
    public let cachedAt: Date

    public init(url: URL, localPath: String, mimeType: String, cachedAt: Date) {
        self.url = url
        self.localPath = localPath
        self.mimeType = mimeType
        self.cachedAt = cachedAt
    }
}

// MARK: - CacheRequestInfo

/// 缓存请求信息
public struct CacheRequestInfo {
    public let url: URL
    public let isMainFrame: Bool
    public let httpMethod: String
    public let hasCache: Bool
    public let cacheAge: TimeInterval?

    public init(url: URL, isMainFrame: Bool, httpMethod: String, hasCache: Bool, cacheAge: TimeInterval? = nil) {
        self.url = url
        self.isMainFrame = isMainFrame
        self.httpMethod = httpMethod
        self.hasCache = hasCache
        self.cacheAge = cacheAge
    }
}

// MARK: - CacheStats

/// 缓存统计信息
public struct CacheStats {
    public let totalRequests: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let hitRate: Double
    public let totalCacheSize: Int64

    public init(totalRequests: Int, cacheHits: Int, cacheMisses: Int, totalCacheSize: Int64) {
        self.totalRequests = totalRequests
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
        self.hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
        self.totalCacheSize = totalCacheSize
    }

    /// 格式化的命中率
    public var formattedHitRate: String {
        return String(format: "%.1f%%", hitRate * 100)
    }

    /// 格式化的缓存大小
    public var formattedCacheSize: String {
        return ByteCountFormatter.string(fromByteCount: totalCacheSize, countStyle: .file)
    }
}
