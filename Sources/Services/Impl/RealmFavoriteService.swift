//
//  RealmFavoriteService.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// Realm 收藏服务
/// 包装 URLFavoriteManager，实现 FavoriteServiceProtocol 协议
/// 这是在生产环境中使用的真实实现
public class RealmFavoriteService: FavoriteServiceProtocol {

    public static let shared = RealmFavoriteService()

    /// 底层的收藏管理器
    private let manager: URLFavoriteManager

    /// 指定初始化方法
    /// - Parameter manager: 收藏管理器，默认使用单例
    public init(manager: URLFavoriteManager = .shared) {
        self.manager = manager
    }

    // MARK: - 添加/更新

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.addFavorite(url:title:favicon:) async instead.")
    @discardableResult
    public func addFavorite(url: URL, title: String?, favicon: Data?) -> URLFavorite? {
        return manager.addFavorite(url: url, title: title, favicon: favicon)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.updateFavorite(_:) async instead.")
    public func updateFavorite(_ favorite: URLFavorite) {
        manager.updateFavorite(favorite)
    }

    // MARK: - 删除

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.deleteFavorite(id:) async instead.")
    public func deleteFavorite(id: String) {
        manager.deleteFavorite(id: id)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.deleteFavorite(url:) async instead.")
    public func deleteFavorite(url: URL) {
        manager.deleteFavorite(url: url)
    }

    // MARK: - 查询

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.getAllFavorites() async instead.")
    public func getAllFavorites() -> [URLFavorite] {
        return manager.getAllFavorites()
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.findFavorite(url:) async instead.")
    public func findFavorite(url: URL) -> URLFavorite? {
        return manager.findFavorite(url: url)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.findFavorite(id:) async instead.")
    public func findFavorite(id: String) -> URLFavorite? {
        return manager.findFavorite(id: id)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.searchFavorites(keyword:) async instead.")
    public func searchFavorites(keyword: String) -> [URLFavorite] {
        return manager.searchFavorites(keyword: keyword)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.getTotalCount() async instead.")
    public func getTotalCount() -> Int {
        return manager.getTotalCount()
    }

    // MARK: - 特殊操作

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.togglePin(id:) async instead.")
    @discardableResult
    public func togglePin(id: String) -> Bool {
        return manager.togglePin(id: id)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.updateCacheMode(id:enabled:) async instead.")
    public func updateCacheMode(id: String, enabled: Bool) {
        manager.updateCacheMode(id: id, enabled: enabled)
    }

    @available(*, deprecated, message: "Use URLFavoriteManager.shared.updateSortOrder(favorites:) async instead.")
    public func updateSortOrder(favorites: [URLFavorite]) {
        manager.updateSortOrder(favorites: favorites)
    }
}
