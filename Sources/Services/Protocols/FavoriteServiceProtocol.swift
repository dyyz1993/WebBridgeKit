//
//  FavoriteServiceProtocol.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// URL 收藏服务协议
/// 定义收藏数据操作的抽象接口，便于 Mock 和真实实现的切换
public protocol FavoriteServiceProtocol: AnyObject {

    // MARK: - 添加/更新

    /// 添加收藏
    /// - Parameters:
    ///   - url: 页面URL
    ///   - title: 页面标题（可选）
    ///   - favicon: 页面图标（可选）
    /// - Returns: 创建的收藏对象，如果已存在则返回 nil
    @discardableResult
    func addFavorite(url: URL, title: String?, favicon: Data?) -> URLFavorite?

    /// 更新收藏
    /// - Parameter favorite: 要更新的收藏对象
    func updateFavorite(_ favorite: URLFavorite)

    // MARK: - 删除

    /// 删除收藏
    /// - Parameter id: 收藏ID
    func deleteFavorite(id: String)

    /// 删除收藏（根据URL）
    /// - Parameter url: 页面URL
    func deleteFavorite(url: URL)

    // MARK: - 查询

    /// 获取所有收藏（按置顶和排序）
    /// - Returns: 收藏结果集
    func getAllFavorites() -> Results<URLFavorite>

    /// 根据URL查找收藏
    /// - Parameter url: 页面URL
    /// - Returns: 匹配的收藏对象，如果没有则返回 nil
    func findFavorite(url: URL) -> URLFavorite?

    /// 根据ID查找收藏
    /// - Parameter id: 收藏ID
    /// - Returns: 匹配的收藏对象，如果没有则返回 nil
    func findFavorite(id: String) -> URLFavorite?

    /// 搜索收藏（标题或URL包含关键词）
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的收藏结果集
    func searchFavorites(keyword: String) -> Results<URLFavorite>

    /// 获取收藏总数
    /// - Returns: 总数
    func getTotalCount() -> Int

    // MARK: - 特殊操作

    /// 切换置顶状态
    /// - Parameter id: 收藏ID
    /// - Returns: 切换后的置顶状态
    @discardableResult
    func togglePin(id: String) -> Bool

    /// 更新缓存模式
    /// - Parameters:
    ///   - id: 收藏ID
    ///   - enabled: 是否启用缓存
    func updateCacheMode(id: String, enabled: Bool)

    /// 更新排序顺序
    /// - Parameter favorites: 要排序的收藏数组
    func updateSortOrder(favorites: [URLFavorite])
}
