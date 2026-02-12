//
//  HistoryServiceProtocol.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// 历史记录服务协议
/// 定义历史记录数据操作的抽象接口，便于 Mock 和真实实现的切换
public protocol HistoryServiceProtocol: AnyObject {

    // MARK: - 添加/更新

    /// 添加或更新历史记录
    /// - Parameters:
    ///   - url: 页面URL
    ///   - title: 页面标题（可选）
    ///   - favicon: 页面图标（可选）
    func addOrUpdateHistory(url: URL, title: String?, favicon: Data?)

    // MARK: - 删除

    /// 删除历史记录
    /// - Parameter id: 历史记录ID
    func deleteHistory(id: String)

    /// 清空所有历史
    func clearAllHistory()

    // MARK: - 查询

    /// 获取所有历史记录（按最后访问时间降序）
    /// 返回独立副本数组，避免跨线程访问问题
    /// - Returns: 历史记录数组
    func getAllHistories() -> [WebPageHistory]

    /// 获取已缓存的历史记录
    /// 返回独立副本数组，避免跨线程访问问题
    /// - Returns: 已缓存的历史记录数组
    func getCachedHistories() -> [WebPageHistory]

    /// 根据URL查找历史记录
    /// - Parameter url: 页面URL
    /// - Returns: 匹配的历史记录，如果没有则返回 nil
    func findHistory(url: URL) -> WebPageHistory?

    /// 根据ID查找历史记录
    /// - Parameter id: 历史记录ID
    /// - Returns: 匹配的历史记录，如果没有则返回 nil
    func findHistory(id: String) -> WebPageHistory?

    /// 搜索历史记录（标题或URL包含关键词）
    /// 返回独立副本数组，避免跨线程访问问题
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的历史记录数组
    func searchHistories(keyword: String) -> [WebPageHistory]

    // MARK: - 统计

    /// 获取历史记录总数
    /// - Returns: 总数
    func getTotalCount() -> Int

    /// 获取今日访问数
    /// - Returns: 今日访问的页面数量
    func getTodayVisitCount() -> Int

    /// 获取最常访问的页面
    /// - Parameter limit: 返回数量限制
    /// - Returns: 最常访问的历史记录数组
    func getMostVisited(limit: Int) -> [WebPageHistory]
}
