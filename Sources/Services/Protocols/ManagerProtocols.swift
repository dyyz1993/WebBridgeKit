//
//  ManagerProtocols.swift
//  WebBridgeKit
//
//  Created on 2025-02-10.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//
//  这些协议用于抽象管理器类，支持依赖注入和单元测试

import Foundation
import RxSwift

// MARK: - 浏览器管理协议

/// 浏览器管理协议
/// 用于管理浏览器页面的打开、关闭和导航
public protocol WebBrowserManaging {
    /// 打开浏览器（统一入口）
    /// - Parameters:
    ///   - url: 要加载的 URL
    ///   - params: 浏览器配置参数（可选）
    ///   - forceRefresh: 是否强制刷新（绕过缓存）
    ///   - sourceViewController: 来源 ViewController（可选）
    ///   - animated: 是否使用动画
    ///   - completion: 完成回调（可选）
    func openBrowser(url: URL, params: WebBrowserParams?, forceRefresh: Bool, from sourceViewController: UIViewController?, animated: Bool, completion: ((Result<Void, Error>) -> Void)?)

    /// 关闭当前浏览器
    /// - Parameters:
    ///   - animated: 是否使用动画
    ///   - reason: 关闭原因
    func closeBrowser(animated: Bool, reason: WebBrowserParams.CloseReason)
}

// MARK: - Manifest 缓存管理协议

/// Manifest 缓存管理协议
/// 用于管理 HTML 和 Manifest 的存储
public protocol ManifestCacheManaging {
    /// 保存 HTML 内容
    /// - Parameters:
    ///   - html: HTML 内容
    ///   - key: 缓存键
    func saveHTML(_ html: String, for key: String)

    /// 获取 HTML 内容
    /// - Parameter key: 缓存键
    /// - Returns: HTML 内容，如果不存在则返回 nil
    func getHTML(for key: String) -> String?

    /// 移除 HTML 缓存
    /// - Parameter key: 缓存键
    func removeHTML(for key: String)

    /// 保存 Manifest 对象
    /// - Parameters:
    ///   - manifest: Manifest 对象
    ///   - key: 缓存键
    func saveManifest(_ manifest: Manifest, for key: String)

    /// 获取 Manifest 对象
    /// - Parameter key: 缓存键
    /// - Returns: Manifest 对象，如果不存在则返回 nil
    func getManifest(for key: String) -> Manifest?

    /// 移除 Manifest 缓存
    /// - Parameter key: 缓存键
    func removeManifest(for key: String)

    /// 清空所有缓存
    func clearAll()

    /// 获取所有已缓存的页面键
    /// - Returns: 所有页面标识符数组
    func getAllPageKeys() -> [String]
}

// MARK: - 历史记录管理协议

/// 历史记录管理协议
/// 用于管理网页访问历史
public protocol WebPageHistoryManaging {
    /// 添加或更新历史记录
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - title: 页面标题（可选）
    ///   - favicon: 页面图标（可选）
    func addOrUpdateHistory(url: URL, title: String?, favicon: Data?) async throws

    /// 获取所有历史记录
    /// - Returns: 历史记录数组
    func getAllHistories() async throws -> [WebPageHistory]

    /// 根据 URL 查找历史记录
    /// - Parameter url: 页面 URL
    /// - Returns: 历史记录对象，如果不存在则返回 nil
    func findHistory(url: URL) async throws -> WebPageHistory?

    /// 删除历史记录
    /// - Parameter id: 历史记录 ID
    func deleteHistory(id: String) async throws

    /// 清空所有历史（保留收藏和置顶项）
    func clearAllHistory() async throws

    /// 清理低频访问项
    /// - Parameter limit: 保留的最大数量
    func cleanupLowFrequencyItems(limit: Int) async throws

    /// 获取已缓存的历史记录
    /// - Returns: 已缓存的历史记录数组
    func getCachedHistories() async throws -> [WebPageHistory]

    /// 根据 ID 查找历史记录
    /// - Parameter id: 历史记录 ID
    /// - Returns: 历史记录对象，如果不存在则返回 nil
    func findHistory(id: String) async throws -> WebPageHistory?

    /// 搜索历史记录
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的历史记录数组
    func searchHistories(keyword: String) async throws -> [WebPageHistory]

    /// 获取历史记录总数
    /// - Returns: 总数
    func getTotalCount() async throws -> Int

    /// 获取今日访问数
    /// - Returns: 访问数
    func getTodayVisitCount() async throws -> Int

    /// 获取最常访问的页面
    /// - Parameter limit: 返回的最大数量
    /// - Returns: 历史记录数组
    func getMostVisited(limit: Int) async throws -> [WebPageHistory]
}

// MARK: - 缓存管理协议

/// 缓存管理协议
/// 用于管理 WebView 和资源缓存
public protocol WebCacheManaging {
    /// 获取所有网站的缓存统计
    /// - Returns: Observable 序列，返回缓存统计数组
    func fetchSystemCacheStatistics() -> Observable<[WebCacheStatistics]>

    /// 清理所有缓存
    func clearAll()

    /// 清理特定域名的缓存
    /// - Parameter domain: 域名
    /// - Returns: Observable 序列
    func clearCache(for domain: String) -> Observable<Void>

    /// 清理所有缓存（Observable 版本）
    /// - Returns: Observable 序列
    func clearAllCache() -> Observable<Void>

    /// 执行自动清理
    func performAutoCleanup()

    /// 获取缓存的域名列表
    /// - Returns: 缓存统计数组
    func getCachedDomains() -> [WebCacheStatistics]

    /// 获取总缓存大小
    /// - Returns: 缓存大小（字节）
    func getTotalCacheSize() -> Int64

    /// 检查 URL 是否已缓存
    /// - Parameter url: URL
    /// - Returns: 是否已缓存
    func isURLCached(_ url: URL) -> Bool

    /// 预加载 URL
    /// - Parameter url: 要预加载的 URL
    /// - Returns: Observable 序列
    func preloadURL(_ url: URL) -> Observable<Void>

    /// 删除 Glob 模式的压缩缓存
    /// - Parameter pattern: Glob 模式
    /// - Returns: Observable 序列，返回删除的条目数量
    func deleteCacheByGlob(pattern: String) -> Observable<Int>

    /// 获取压缩缓存的内存信息
    /// - Returns: Observable 序列，返回内存信息
    func getCacheMemoryInfo() -> Observable<CacheMemoryInfo>

    /// 获取详细的压缩缓存条目
    /// - Parameter filterPattern: 可选的 Glob 过滤模式
    /// - Returns: Observable 序列，返回缓存条目信息数组
    func getDetailedCacheEntries(filterPattern: String?) -> Observable<[CacheEntryInfo]>

    /// 按域名分组获取压缩缓存条目
    /// - Returns: Observable 序列，返回 [域名: 缓存条目数组] 字典
    func getCacheEntriesGroupedByDomain() -> Observable<[String: [CacheEntryInfo]]>

    /// 检查资源是否已缓存（增强版）
    /// - Parameter url: 资源 URL
    /// - Returns: (是否已缓存, 缓存条目信息)
    func isResourceCached(url: URL) -> (cached: Bool, info: CacheEntryInfo?)

    /// 预加载 URL 到压缩缓存
    /// - Parameter url: 要预加载的 URL
    /// - Returns: Observable 序列，返回进度
    func preloadToCompressedCache(url: URL) -> Observable<Progress>

    /// 清空所有压缩缓存
    /// - Returns: Observable 序列
    func clearAllCompressedCache() -> Observable<Void>
}
