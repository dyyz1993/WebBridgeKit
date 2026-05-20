//
//  CacheVersionStatus.swift
//  WebBridgeKit
//
//  Offline app version tracking for update management.
//

import Foundation

/// 版本更新状态
public enum CacheUpdateState: String, Codable, Sendable {
    /// 当前已是最新版本
    case upToDate
    /// 有新版本可用（用户可手动更新）
    case updateAvailable
    /// 正在下载更新
    case updating
    /// 更新下载失败，当前版本仍可用
    case updateFailed
    /// 从未缓存，需要首次下载
    case notCached
    /// 离线状态，无法检查更新
    case offline
}

/// 离线应用版本状态
/// 用于 UI 展示"有更新"徽章、版本号等
public struct CacheVersionStatus: Codable, Sendable {
    /// 缓存 ID (appid 或域名)
    public let cacheID: String

    /// 应用名称
    public let name: String?

    /// 应用图标 URL
    public let iconURL: String?

    /// 当前本地缓存的版本
    public let currentVersion: String?

    /// 服务端最新版本（nil = 未检查或离线）
    public let latestVersion: String?

    /// 更新状态
    public let updateState: CacheUpdateState

    /// 当前缓存大小（字节）
    public let cacheSize: Int64

    /// 最后访问时间
    public let lastAccessed: Date?

    /// 最后检查更新时间
    public let lastChecked: Date?

    /// 是否可以离线访问
    public var isOfflineAvailable: Bool {
        return currentVersion != nil && cacheSize > 0
    }

    /// 是否有更新可用
    public var hasUpdate: Bool {
        return updateState == .updateAvailable
    }

    /// 版本描述文本（供 UI 显示）
    public var versionDescription: String {
        switch updateState {
        case .upToDate:
            return "v\(currentVersion ?? "?") · 已是最新"
        case .updateAvailable:
            return "v\(currentVersion ?? "?") → v\(latestVersion ?? "?")"
        case .updating:
            return "正在更新..."
        case .updateFailed:
            return "v\(currentVersion ?? "?") · 更新失败"
        case .notCached:
            return "未缓存"
        case .offline:
            return "v\(currentVersion ?? "?") · 离线"
        }
    }

    public init(
        cacheID: String,
        name: String? = nil,
        iconURL: String? = nil,
        currentVersion: String? = nil,
        latestVersion: String? = nil,
        updateState: CacheUpdateState,
        cacheSize: Int64 = 0,
        lastAccessed: Date? = nil,
        lastChecked: Date? = nil
    ) {
        self.cacheID = cacheID
        self.name = name
        self.iconURL = iconURL
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.updateState = updateState
        self.cacheSize = cacheSize
        self.lastAccessed = lastAccessed
        self.lastChecked = lastChecked
    }
}
