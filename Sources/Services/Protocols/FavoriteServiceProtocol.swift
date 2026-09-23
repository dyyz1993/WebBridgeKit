//
//  FavoriteServiceProtocol.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// URL 收藏服务协议
/// 定义收藏数据操作的抽象接口，便于 Mock 和真实实现的切换
public protocol FavoriteServiceProtocol: AnyObject {

    // MARK: - 添加/更新

    @discardableResult
    func addFavorite(url: URL, title: String?, favicon: Data?) -> URLFavorite?

    func updateFavorite(_ favorite: URLFavorite)

    // MARK: - 删除

    func deleteFavorite(id: String)

    func deleteFavorite(url: URL)

    // MARK: - 查询

    func getAllFavorites() -> [URLFavorite]

    func findFavorite(url: URL) -> URLFavorite?

    func findFavorite(id: String) -> URLFavorite?

    func searchFavorites(keyword: String) -> [URLFavorite]

    func getTotalCount() -> Int

    // MARK: - 特殊操作

    @discardableResult
    func togglePin(id: String) -> Bool

    func updateCacheMode(id: String, enabled: Bool)

    func updateSortOrder(favorites: [URLFavorite])

    // MARK: - 异步写入（等提交完成再返回）

    // 同步写入族是 fire-and-forget Task（内部 Task 提交前就返回）；
    // 「写完立刻重读列表」的调用方必须用这一组，否则会读到未提交的旧数据
    // （表现为删除/置顶要点两次才生效）。

    func deleteFavoriteAsync(id: String) async

    @discardableResult
    func togglePinAsync(id: String) async -> Bool

    func updateCacheModeAsync(id: String, enabled: Bool) async
}
