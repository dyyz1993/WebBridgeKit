//
//  ManifestLoaderTypes.swift
//  WebBridgeKit
//
//  Nested types for PersistentManifestLoader (split from main file).
//

import Foundation

// MARK: - LoaderError

extension PersistentManifestLoader {

    public enum LoaderError: Error, LocalizedError {
        case manifestNotFound
        case invalidManifestFormat
        case persistentModeDisabled
        case htmlDownloadFailed(Error)
        case resourceDownloadFailed(String, Error)
        case cacheDirectoryCreationFailed
        case webViewNotAvailable

        public var errorDescription: String? {
            switch self {
            case .manifestNotFound:
                return "Manifest file not found"
            case .invalidManifestFormat:
                return "Invalid manifest format"
            case .persistentModeDisabled:
                return "Persistent mode is not enabled for this page"
            case .htmlDownloadFailed(let error):
                return "Failed to download HTML: \(error.localizedDescription)"
            case .resourceDownloadFailed(let resource, let error):
                return "Failed to download resource '\(resource)': \(error.localizedDescription)"
            case .cacheDirectoryCreationFailed:
                return "Failed to create cache directory"
            case .webViewNotAvailable:
                return "WebView is not available"
            }
        }
    }
}

// MARK: - WebManifest

extension PersistentManifestLoader {

    /// Web Manifest 结构
    public struct WebManifest: Codable {
        /// 是否启用持久化缓存
        public let persistent: Bool

        /// 资源映射：相对路径 -> 真实 URL
        public let resources: [String: String]

        /// 版本号（默认 "0.0.1"）
        public let version: String?

        /// 应用标识符（可选，用于缓存路径和清理）
        /// 如果不提供，将使用域名作为 AppID
        public let appid: String?

        /// 应用名称（可选，用于显示）
        /// 如果不提供，将从 HTML title 提取
        public let name: String?

        /// 应用图标 URL（可选，用于显示）
        /// 如果不提供，将生成默认圆形图标
        public let icon: String?

        /// 最后更新时间（可选，用于兼容性）
        public let updatedAt: String?

        /// 描述信息（可选，用于兼容性）
        public let description: String?

        public init(
            persistent: Bool,
            resources: [String: String],
            version: String? = nil,
            appid: String? = nil,
            name: String? = nil,
            icon: String? = nil,
            updatedAt: String? = nil,
            description: String? = nil
        ) {
            self.persistent = persistent
            self.resources = resources
            self.version = version
            self.appid = appid
            self.name = name
            self.icon = icon
            self.updatedAt = updatedAt
            self.description = description
        }

        /// 获取版本号，如果没有则返回默认值
        public var resolvedVersion: String {
            return version ?? "0.0.1"
        }
    }
}

// MARK: - LoadingState

extension PersistentManifestLoader {

    /// 加载状态
    public enum LoadingState {
        case idle
        case fetchingManifest
        case downloadingResources(current: Int, total: Int)
        case preparingHTML
        case loadingWebView
        case completed
        case failed(Error)
    }
}
