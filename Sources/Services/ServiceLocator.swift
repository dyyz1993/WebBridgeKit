//
//  ServiceLocator.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// 服务定位器
/// 负责管理和提供应用中的所有服务实例
/// 支持 Mock 模式和生产模式的切换
public class ServiceLocator {

    /// 共享实例
    public static let shared = ServiceLocator()

    // MARK: - 服务类型

    /// 服务模式枚举
    public enum ServiceMode {
        case production    // 生产模式：使用真实的 Realm 实现
        case mock          // Mock 模式：使用内存中的 Mock 实现
    }

    // MARK: - 服务实例

    /// 历史记录服务
    private var _historyService: HistoryServiceProtocol?
    /// 收藏服务
    private var _favoriteService: FavoriteServiceProtocol?
    /// 置顶 URL 管理器
    private var _pinnedURLManager: PinnedURLManaging?
    /// URL 收藏管理器
    private var _urlFavoriteManager: URLManaging?
    /// Manifest 缓存管理器
    private var _manifestStore: ManifestCacheManaging?
    /// Web 缓存管理器
    private var _cacheManager: WebCacheManaging?
    /// 消息引擎
    private var _messageEngine: (any MessageEngineProtocol)?

    /// 当前服务模式
    public private(set) var currentMode: ServiceMode = .production

    // MARK: - 初始化

    private init() {
        // 使用生产模式以支持测试URL注入
        // AppDelegate 会在启动时注入测试URL到历史记录
        #if DEBUG
        setupProductionServices()  // 使用生产服务以支持测试URL
        #else
        setupProductionServices()
        #endif
    }

    // MARK: - 服务配置

    /// 设置生产环境服务（使用真实数据）
    public func setupProductionServices() {
        _historyService = RealmHistoryService.shared
        _favoriteService = RealmFavoriteService.shared
        currentMode = .production

        WebBridgeLogger.shared.log(.info, "🔧 ServiceLocator: Production services configured")
    }

    /// 设置 Mock 服务并添加示例数据（用于开发/演示）
    public func setupMockServicesWithSampleData(useInMemoryRealm: Bool = true) {
        setupMockServices(useInMemoryRealm: useInMemoryRealm)

        // 添加示例数据
        if let historyService = _historyService as? MockHistoryService {
            historyService.addMockData(urls: [
                "https://www.apple.com",
                "https://www.github.com",
                "https://www.stackoverflow.com",
                "https://www.reddit.com",
                "https://www.google.com"
            ])
            // 验证数据是否添加成功
            let count = historyService.getTotalCount()
            print("🔍 [ServiceLocator] Mock history count: \(count)")
        }

        if let favoriteService = _favoriteService as? MockFavoriteService {
            favoriteService.addMockData(urls: [
                "https://www.apple.com",
                "https://www.google.com",
                "https://www.microsoft.com"
            ])
            // 验证数据是否添加成功
            let count = favoriteService.getTotalCount()
            print("🔍 [ServiceLocator] Mock favorite count: \(count)")
        }

        WebBridgeLogger.shared.log(.info, "🎨 ServiceLocator: Mock services with sample data configured")
    }

    /// 设置 Mock 服务（使用内存数据，用于测试/开发）
    public func setupMockServices(useInMemoryRealm: Bool = false) {
        _historyService = MockHistoryService(useInMemoryRealm: useInMemoryRealm)
        _favoriteService = MockFavoriteService(useInMemoryRealm: useInMemoryRealm)
        currentMode = .mock

        WebBridgeLogger.shared.log(.info, "🧪 ServiceLocator: Mock services configured (useInMemoryRealm: \(useInMemoryRealm))")
    }

    /// 注册自定义服务实现
    /// - Parameters:
    ///   - historyService: 自定义历史记录服务
    ///   - favoriteService: 自定义收藏服务
    public func registerCustomServices(
        historyService: HistoryServiceProtocol? = nil,
        favoriteService: FavoriteServiceProtocol? = nil
    ) {
        if let historyService = historyService {
            _historyService = historyService
        }

        if let favoriteService = favoriteService {
            _favoriteService = favoriteService
        }

        WebBridgeLogger.shared.log(.info, "🔧 ServiceLocator: Custom services registered")
    }

    /// 注册管理器实现（可选覆盖，不传则保持默认 .shared 单例）
    public func register(
        pinnedURLManager: PinnedURLManaging? = nil,
        urlFavoriteManager: URLManaging? = nil,
        manifestStore: ManifestCacheManaging? = nil,
        cacheManager: WebCacheManaging? = nil,
        messageEngine: (any MessageEngineProtocol)? = nil
    ) {
        if let m = pinnedURLManager { _pinnedURLManager = m }
        if let m = urlFavoriteManager { _urlFavoriteManager = m }
        if let m = manifestStore { _manifestStore = m }
        if let m = cacheManager { _cacheManager = m }
        if let m = messageEngine { _messageEngine = m }

        WebBridgeLogger.shared.log(.info, "🔧 ServiceLocator: Manager services registered")
    }

    // MARK: - 服务访问

    /// 获取历史记录服务
    public var historyService: HistoryServiceProtocol {
        return _historyService ?? RealmHistoryService.shared
    }

    /// 获取收藏服务
    public var favoriteService: FavoriteServiceProtocol {
        return _favoriteService ?? RealmFavoriteService.shared
    }

    /// 获取置顶 URL 管理器
    public var pinnedURLManager: PinnedURLManaging {
        return _pinnedURLManager ?? PinnedURLManager.shared
    }

    /// 获取 URL 收藏管理器
    public var urlFavoriteManager: URLManaging {
        return _urlFavoriteManager ?? URLFavoriteManager.shared
    }

    /// 获取 Manifest 缓存管理器
    public var manifestStore: ManifestCacheManaging {
        return _manifestStore ?? ManifestStore.shared
    }

    /// 获取 Web 缓存管理器
    public var cacheManager: WebCacheManaging {
        return _cacheManager ?? WebCacheManager.shared
    }

    /// 获取消息引擎
    public var messageEngine: any MessageEngineProtocol {
        return _messageEngine ?? MessageEngine.shared
    }

    // MARK: - 重置

    /// 重置所有服务到生产模式
    public func reset() {
        setupProductionServices()
    }

    /// 清除所有服务（用于测试清理）
    public func clearServices() {
        _historyService = nil
        _favoriteService = nil
        _pinnedURLManager = nil
        _urlFavoriteManager = nil
        _manifestStore = nil
        _cacheManager = nil
        _messageEngine = nil

        WebBridgeLogger.shared.log(.info, "🧹 ServiceLocator: All services cleared")
    }
}

// MARK: - 便捷访问扩展

public extension ServiceLocator {

    /// 快捷访问历史记录服务
    static var history: HistoryServiceProtocol {
        return shared.historyService
    }

    /// 快捷访问收藏服务
    static var favorite: FavoriteServiceProtocol {
        return shared.favoriteService
    }

    /// 快捷访问置顶 URL 管理器
    static var pinnedURLs: PinnedURLManaging {
        return shared.pinnedURLManager
    }

    /// 快捷访问 URL 收藏管理器
    static var urlFavorites: URLManaging {
        return shared.urlFavoriteManager
    }

    /// 快捷访问 Manifest 缓存管理器
    static var manifest: ManifestCacheManaging {
        return shared.manifestStore
    }

    /// 快捷访问 Web 缓存管理器
    static var cache: WebCacheManaging {
        return shared.cacheManager
    }

    /// 快捷访问消息引擎
    static var messages: any MessageEngineProtocol {
        return shared.messageEngine
    }
}
