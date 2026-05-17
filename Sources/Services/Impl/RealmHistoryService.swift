//
//  RealmHistoryService.swift
//  WebBridgeKit
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift

/// Realm 历史记录服务
/// 包装 WebPageHistoryManager，实现 HistoryServiceProtocol 协议
/// 这是在生产环境中使用的真实实现
public class RealmHistoryService: HistoryServiceProtocol {

    public static let shared = RealmHistoryService()

    /// 底层的历史记录管理器
    private let manager: WebPageHistoryManager

    /// 指定初始化方法
    /// - Parameter manager: 历史记录管理器，默认使用单例
    public init(manager: WebPageHistoryManager = .shared) {
        self.manager = manager
    }

    // MARK: - 添加/更新

    @available(*, deprecated, message: "Prefer async callers. See WebPageHistoryManager async methods.")
    public func addOrUpdateHistory(url: URL, title: String?, favicon: Data?) {
        manager.addOrUpdateHistory(url: url, title: title, favicon: favicon)
    }

    // MARK: - 删除

    @available(*, deprecated, message: "Prefer async callers. See WebPageHistoryManager async methods.")
    public func deleteHistory(id: String) {
        manager.deleteHistory(id: id)
    }

    @available(*, deprecated, message: "Prefer async callers. See WebPageHistoryManager async methods.")
    public func clearAllHistory() {
        manager.clearAllHistory()
    }

    // MARK: - 查询

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.getAllHistories() async instead.")
    public func getAllHistories() -> [WebPageHistory] {
        return manager.getAllHistories()
    }

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.getCachedHistories() async instead.")
    public func getCachedHistories() -> [WebPageHistory] {
        return manager.getCachedHistories()
    }

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.findHistory(url:) async instead.")
    public func findHistory(url: URL) -> WebPageHistory? {
        return manager.findHistory(url: url)
    }

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.findHistory(id:) async instead.")
    public func findHistory(id: String) -> WebPageHistory? {
        return manager.findHistory(id: id)
    }

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.searchHistories(keyword:) async instead.")
    public func searchHistories(keyword: String) -> [WebPageHistory] {
        return manager.searchHistories(keyword: keyword)
    }

    // MARK: - 统计

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.getTotalCount() async instead.")
    public func getTotalCount() -> Int {
        return manager.getTotalCount()
    }

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.getTodayVisitCount() async instead.")
    public func getTodayVisitCount() -> Int {
        return manager.getTodayVisitCount()
    }

    @available(*, deprecated, message: "Use WebPageHistoryManager.shared.getMostVisited(limit:) async instead.")
    public func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
        return manager.getMostVisited(limit: limit)
    }
}
