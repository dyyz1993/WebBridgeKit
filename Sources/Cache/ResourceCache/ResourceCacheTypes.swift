//
//  ResourceCacheTypes.swift
//  WebBridgeKit
//
//  Split from WebResourceCacheManager.swift
//

import Foundation

extension WebResourceCacheManager {

    public struct CacheSpaceStats {
        public let cacheID: String
        public let url: URL
        public let totalSize: Int64
        public let fileCount: Int
        public let createdAt: Date
        public let lastAccessedAt: Date
        public let manifest: WebResourceManifest?

        public var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }

        public var age: TimeInterval {
            Date().timeIntervalSince(createdAt)
        }
    }

    public struct WebResourceManifest: Codable {
        public let url: String
        public let htmlContent: String
        public var resources: [String: ResourceInfo]
        public var version: String
        public let createdAt: Date
        public var lastAccessedAt: Date

        public init(
            url: String,
            htmlContent: String,
            resources: [String: ResourceInfo] = [:],
            version: String = UUID().uuidString,
            createdAt: Date = Date(),
            lastAccessedAt: Date = Date()
        ) {
            self.url = url
            self.htmlContent = htmlContent
            self.resources = resources
            self.version = version
            self.createdAt = createdAt
            self.lastAccessedAt = lastAccessedAt
        }
    }

    public struct ResourceInfo: Codable {
        public let relativePath: String
        public let originalURL: String
        public let mimeType: String
        public let fileSize: Int
        public let cachedAt: Date

        public init(relativePath: String, originalURL: String, mimeType: String, fileSize: Int, cachedAt: Date = Date()) {
            self.relativePath = relativePath
            self.originalURL = originalURL
            self.mimeType = mimeType
            self.fileSize = fileSize
            self.cachedAt = cachedAt
        }
    }

    public enum LRUEvictionPolicy {
        case leastRecentlyUsed
        case leastFrequentlyUsed
        case oldest
        case largest
    }

    public enum CacheError: Error, LocalizedError {
        case cacheSpaceNotFound(String)
        case invalidCacheID(String)
        case resourceNotFound(String)
        case diskError(Error)
        case manifestCorrupted(String)

        public var errorDescription: String? {
            switch self {
            case .cacheSpaceNotFound(let id):
                return "Cache space not found: \(id)"
            case .invalidCacheID(let id):
                return "Invalid cache ID: \(id)"
            case .resourceNotFound(let path):
                return "Resource not found: \(path)"
            case .diskError(let error):
                return "Disk error: \(error.localizedDescription)"
            case .manifestCorrupted(let id):
                return "Manifest corrupted for cache: \(id)"
            }
        }
    }
}
