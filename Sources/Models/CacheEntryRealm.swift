//
//  CacheEntryRealm.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// 压缩缓存条目模型
/// 用于追踪每个缓存资源的元数据
public class CacheEntryRealm: Object {

    // MARK: - Properties

    /// 缓存键（通常是 URL 的 hash）
    @objc dynamic public var key: String = ""

    /// 原始 URL
    @objc dynamic public var url: String = ""

    /// MIME 类型
    @objc dynamic public var mimeType: String = ""

    /// 原始数据大小（字节）
    @objc dynamic public var originalSize: Int64 = 0

    /// 压缩后大小（字节）
    @objc dynamic public var compressedSize: Int64 = 0

    /// 是否已压缩
    @objc dynamic public var isCompressed: Bool = false

    /// 压缩比 (0.0 - 1.0)
    @objc dynamic public var compressionRatio: Double = 0.0

    /// 创建时间
    @objc dynamic public var createdAt: Date = Date()

    /// 最后访问时间
    @objc dynamic public var lastAccessedAt: Date = Date()

    /// 访问次数
    @objc dynamic public var accessCount: Int = 0

    /// 本地文件路径
    @objc dynamic public var filePath: String = ""

    /// ETag (用于验证资源是否变化)
    @objc dynamic public var etag: String?

    /// 最后修改时间
    @objc dynamic public var lastModified: Date?

    /// HTTP 响应头（JSON 字符串）
    @objc dynamic public var responseHeaders: String?

    // MARK: - Realm Configuration

    override public class func primaryKey() -> String? {
        return "key"
    }

    override public class func indexedProperties() -> [String] {
        return ["url", "createdAt", "lastAccessedAt", "isCompressed"]
    }

    // MARK: - Computed Properties

    /// 域名（从 URL 中提取）
    public var domain: String {
        guard let urlObject = URL(string: url) else { return "unknown" }
        return urlObject.host ?? "unknown"
    }

    /// 资源扩展名
    public var fileExtension: String {
        guard let urlObject = URL(string: url) else { return "" }
        return urlObject.pathExtension
    }

    /// 资源类型分类
    public var resourceType: ResourceType {
        switch fileExtension.lowercased() {
        case "js", "mjs":
            return .script
        case "css":
            return .stylesheet
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "ico":
            return .image
        case "woff", "woff2", "ttf", "otf", "eot":
            return .font
        case "mp4", "webm", "ogg", "mov":
            return .video
        case "mp3", "wav", "aac", "flac":
            return .audio
        case "html", "htm":
            return .html
        case "json":
            return .json
        default:
            return .other
        }
    }

    /// 格式化的原始大小
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    /// 格式化的压缩后大小
    public var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    /// 格式化的压缩比（百分比）
    public var formattedCompressionRatio: String {
        let percentage = compressionRatio * 100
        return String(format: "%.1f%%", percentage)
    }

    /// 节省的空间
    public var savedSpace: Int64 {
        return originalSize - compressedSize
    }

    /// 格式化的节省空间
    public var formattedSavedSpace: String {
        ByteCountFormatter.string(fromByteCount: savedSpace, countStyle: .file)
    }

    // MARK: - Resource Type Enum

    public enum ResourceType: String {
        case html
        case script
        case stylesheet
        case image
        case font
        case video
        case audio
        case json
        case other

        /// 图标名称
        public var iconName: String {
            switch self {
            case .html: return "doc.text"
            case .script: return "doc.text.image"
            case .stylesheet: return "paintbrush"
            case .image: return "photo"
            case .font: return "textformat"
            case .video: return "video"
            case .audio: return "speaker.wave.2"
            case .json: return "doc.text"
            case .other: return "doc"
            }
        }

        /// 显示名称
        public var displayName: String {
            switch self {
            case .html: return "HTML"
            case .script: return "JavaScript"
            case .stylesheet: return "CSS"
            case .image: return "图片"
            case .font: return "字体"
            case .video: return "视频"
            case .audio: return "音频"
            case .json: return "JSON"
            case .other: return "其他"
            }
        }
    }

    // MARK: - Update Methods

    /// 更新访问信息
    public func updateAccess() {
        lastAccessedAt = Date()
        accessCount += 1
    }

    /// 创建或更新缓存条目
    /// - Parameters:
    ///   - key: 缓存键
    ///   - url: URL
    ///   - data: 原始数据
    ///   - compressedData: 压缩后的数据（如果未压缩则为 nil）
    ///   - mimeType: MIME 类型
    ///   - filePath: 文件路径
    ///   - etag: ETag（可选）
    ///   - lastModified: 最后修改时间（可选）
    ///   - responseHeaders: 响应头（可选）
    /// - Returns: CacheEntryRealm 实例
    public static func createOrUpdate(
        key: String,
        url: String,
        data: Data,
        compressedData: Data?,
        mimeType: String,
        filePath: String,
        etag: String? = nil,
        lastModified: Date? = nil,
        responseHeaders: [String: String]? = nil
    ) -> CacheEntryRealm {
        let entry = CacheEntryRealm()
        entry.key = key
        entry.url = url
        entry.mimeType = mimeType
        entry.originalSize = Int64(data.count)
        entry.filePath = filePath

        if let compressed = compressedData {
            entry.isCompressed = true
            entry.compressedSize = Int64(compressed.count)
            entry.compressionRatio = Double(compressed.count) / Double(data.count)
        } else {
            entry.isCompressed = false
            entry.compressedSize = entry.originalSize
            entry.compressionRatio = 1.0
        }

        entry.createdAt = Date()
        entry.lastAccessedAt = Date()
        entry.accessCount = 1
        entry.etag = etag
        entry.lastModified = lastModified

        // 将响应头字典转换为 JSON 字符串
        if let headers = responseHeaders,
           let jsonData = try? JSONSerialization.data(withJSONObject: headers, options: []) {
            entry.responseHeaders = String(data: jsonData, encoding: .utf8)
        }

        return entry
    }
}

// MARK: - Cache Memory Info

/// 缓存内存信息汇总
public struct CacheMemoryInfo {
    public let totalEntries: Int
    public let totalOriginalSize: Int64
    public let totalCompressedSize: Int64
    public let compressionRatio: Double
    public let savedSpace: Int64

    /// 格式化的总原始大小
    public var formattedTotalOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: totalOriginalSize, countStyle: .file)
    }

    /// 格式化的总压缩后大小
    public var formattedTotalCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: totalCompressedSize, countStyle: .file)
    }

    /// 格式化的节省空间
    public var formattedSavedSpace: String {
        ByteCountFormatter.string(fromByteCount: savedSpace, countStyle: .file)
    }

    /// 格式化的压缩比（百分比）
    public var formattedCompressionRatio: String {
        let percentage = compressionRatio * 100
        return String(format: "%.1f%%", percentage)
    }

    /// 从 Realm 条目数组计算内存信息
    public static func from(entries: [CacheEntryRealm]) -> CacheMemoryInfo {
        let totalEntries = entries.count
        let totalOriginalSize = entries.reduce(0) { $0 + $1.originalSize }
        let totalCompressedSize = entries.reduce(0) { $0 + $1.compressedSize }
        let compressionRatio = totalOriginalSize > 0 ? Double(totalCompressedSize) / Double(totalOriginalSize) : 1.0
        let savedSpace = totalOriginalSize - totalCompressedSize

        return CacheMemoryInfo(
            totalEntries: totalEntries,
            totalOriginalSize: totalOriginalSize,
            totalCompressedSize: totalCompressedSize,
            compressionRatio: compressionRatio,
            savedSpace: savedSpace
        )
    }
}

// MARK: - Cache Entry Info (Public Struct)

/// 缓存条目信息（公开结构体，用于 Bridge API 返回）
public struct CacheEntryInfo {
    public let key: String
    public let url: String
    public let originalSize: Int64
    public let compressedSize: Int64
    public let compressionRatio: Double
    public let createdAt: Date
    public let lastAccessedAt: Date
    public let accessCount: Int
    public let mimeType: String
    public let domain: String
    public let resourceType: String
    public let isCompressed: Bool

    /// 格式化的原始大小
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    /// 格式化的压缩后大小
    public var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    /// 节省的空间
    public var savedSpace: Int64 {
        return originalSize - compressedSize
    }

    /// 格式化的节省空间
    public var formattedSavedSpace: String {
        ByteCountFormatter.string(fromByteCount: savedSpace, countStyle: .file)
    }

    /// 格式化的压缩比（百分比）
    public var formattedCompressionRatio: String {
        let percentage = compressionRatio * 100
        return String(format: "%.1f%%", percentage)
    }

    /// 从 Realm 对象转换
    public init(from realmEntry: CacheEntryRealm) {
        self.key = realmEntry.key
        self.url = realmEntry.url
        self.originalSize = realmEntry.originalSize
        self.compressedSize = realmEntry.compressedSize
        self.compressionRatio = realmEntry.compressionRatio
        self.createdAt = realmEntry.createdAt
        self.lastAccessedAt = realmEntry.lastAccessedAt
        self.accessCount = realmEntry.accessCount
        self.mimeType = realmEntry.mimeType
        self.domain = realmEntry.domain
        self.resourceType = realmEntry.resourceType.rawValue
        self.isCompressed = realmEntry.isCompressed
    }

    /// 转换为字典（用于 Bridge API）
    public func toDictionary() -> [String: Any] {
        return [
            "key": key,
            "url": url,
            "originalSize": originalSize,
            "compressedSize": compressedSize,
            "compressionRatio": compressionRatio,
            "savedSpace": originalSize - compressedSize,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
            "lastAccessedAt": ISO8601DateFormatter().string(from: lastAccessedAt),
            "accessCount": accessCount,
            "mimeType": mimeType,
            "domain": domain,
            "resourceType": resourceType,
            "isCompressed": isCompressed,
            "formattedOriginalSize": ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file),
            "formattedCompressedSize": ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file),
            "formattedSavedSpace": ByteCountFormatter.string(fromByteCount: originalSize - compressedSize, countStyle: .file)
        ]
    }
}
