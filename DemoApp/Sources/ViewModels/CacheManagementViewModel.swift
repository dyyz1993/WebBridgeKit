//
//  CacheManagementViewModel.swift
//  DemoApp
//
//  Created by Claude on 2025-02-04.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import WebBridgeKit

/// 缓存管理 ViewModel
class CacheManagementViewModel: ViewModel {

    // MARK: - Input & Output

    struct Input {
        let refresh: Driver<Void>
        let deleteApp: Driver<String>
        let deleteAll: Driver<Void>
    }

    struct Output {
        let cacheApps: Driver<[CacheAppInfo]>
        let isEmpty: Driver<Bool>
        let totalCacheSize: Driver<String>
        let appCount: Driver<String>
        let loading: Driver<Bool>
        let deleteSuccess: Driver<Void>
        let deleteAllSuccess: Driver<Void>
    }

    // MARK: - Properties

    private let cacheAppsRelay = BehaviorRelay<[CacheAppInfo]>(value: [])
    private let isEmptyRelay = BehaviorRelay<Bool>(value: true)
    private let totalCacheSizeRelay = BehaviorRelay<String>(value: "0 B")
    private let appCountRelay = BehaviorRelay<String>(value: "0 个应用")
    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let deleteSuccessRelay = PublishRelay<Void>()
    private let deleteAllSuccessRelay = PublishRelay<Void>()

    private let manifestStore: ManifestStore
    private let resourceCache: ResourceCache

    // MARK: - Initialization

    init(
        manifestStore: ManifestStore = ManifestStore.shared,
        resourceCache: ResourceCache = ResourceCache.shared
    ) {
        self.manifestStore = manifestStore
        self.resourceCache = resourceCache
        super.init()
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 刷新数据
        input.refresh
            .do(onNext: { [weak self] in
                self?.loadingRelay.accept(true)
                self?.loadCacheData()
            })
            .drive()
            .disposed(by: rx)

        // 删除单个应用
        input.deleteApp
            .do(onNext: { [weak self] appID in
                self?.deleteCache(for: appID)
            })
            .drive()
            .disposed(by: rx)

        // 删除全部
        input.deleteAll
            .do(onNext: { [weak self] in
                self?.deleteAllCache()
            })
            .drive()
            .disposed(by: rx)

        // 初始加载数据
        loadCacheData()

        // 监听缓存更新通知
        NotificationCenter.default.rx.notification(NSNotification.Name("ManifestCacheDidUpdate"))
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.loadCacheData()
            })
            .disposed(by: rx)

        return Output(
            cacheApps: cacheAppsRelay.asDriver(onErrorJustReturn: []),
            isEmpty: isEmptyRelay.asDriver(onErrorJustReturn: true),
            totalCacheSize: totalCacheSizeRelay.asDriver(onErrorJustReturn: "0 B"),
            appCount: appCountRelay.asDriver(onErrorJustReturn: "0 个应用"),
            loading: loadingRelay.asDriver(onErrorJustReturn: false),
            deleteSuccess: deleteSuccessRelay.asDriver(onErrorJustReturn: ()),
            deleteAllSuccess: deleteAllSuccessRelay.asDriver(onErrorJustReturn: ())
        )
    }

    // MARK: - Private Methods

    private func loadCacheData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var appInfoMap: [String: CacheAppInfo] = [:]
            var totalSize: Int64 = 0

            // 获取所有缓存的页面 key
            let allPageKeys = self.manifestStore.getAllPageKeys()

            for pageKey in allPageKeys {
                // 获取 manifest
                guard let manifest = self.manifestStore.getManifest(for: pageKey) else {
                    continue
                }

                // 解析 AppID
                let appID = manifest.appid ?? self.extractAppID(from: pageKey)
                let sanitizedAppID = AppIDResolver.validateAndSanitizeAppID(appID)

                // 计算缓存大小
                let cacheSize = self.calculateCacheSize(for: pageKey)
                totalSize += cacheSize

                // 聚合同一 AppID 的缓存
                if var existing = appInfoMap[sanitizedAppID] {
                    // 合并 pageKeys 和缓存大小
                    var updatedKeys = existing.pageKeys
                    updatedKeys.append(pageKey)
                    updatedKeys = Array(Set(updatedKeys)) // 去重

                    appInfoMap[sanitizedAppID] = CacheAppInfo(
                        appID: sanitizedAppID,
                        name: manifest.name ?? existing.name,
                        version: manifest.resolvedVersion,
                        cacheSize: existing.cacheSize + cacheSize,
                        icon: self.loadIconData(from: manifest.icon, name: manifest.name ?? existing.name, pageKey: pageKey) ?? existing.icon,
                        pageKeys: updatedKeys
                    )
                } else {
                    // 创建新的 AppInfo
                    appInfoMap[sanitizedAppID] = CacheAppInfo(
                        appID: sanitizedAppID,
                        name: manifest.name,
                        version: manifest.resolvedVersion,
                        cacheSize: cacheSize,
                        icon: self.loadIconData(from: manifest.icon, name: manifest.name, pageKey: pageKey),
                        pageKeys: [pageKey]
                    )
                }
            }

            // 更新 UI（在主线程）
            DispatchQueue.main.async {
                let sortedApps = appInfoMap.values.sorted { $0.cacheSize > $1.cacheSize }
                self.cacheAppsRelay.accept(sortedApps)
                self.isEmptyRelay.accept(sortedApps.isEmpty)
                
                // ✅ 重新计算总大小，确保准确
                let totalBytes = sortedApps.reduce(0) { $0 + $1.cacheSize }
                self.totalCacheSizeRelay.accept(self.formatBytes(totalBytes))
                
                self.appCountRelay.accept("\(sortedApps.count) 个应用")
                self.loadingRelay.accept(false)
            }
        }
    }

    private func deleteCache(for appID: String) {
        // 清理 manifest 缓存，完成后刷新数据
        ManifestCacheManager.shared.removeCacheByAppID(appID) { [weak self] in
            // 删除完成后在主线程重新加载数据
            self?.loadCacheData()
            self?.deleteSuccessRelay.accept(())
        }
    }

    private func deleteAllCache() {
        // 清理所有缓存，完成后刷新数据
        ManifestCacheManager.shared.clearAll { [weak self] in
            // 删除完成后在主线程重新加载数据
            self?.loadCacheData()
            self?.deleteAllSuccessRelay.accept(())
        }
    }

    private func calculateCacheSize(for pageKey: String) -> Int64 {
        var totalSize: Int64 = 0
        
        // 1. HTML 内存/元数据大小 (从 ManifestStore 获取)
        if let html = manifestStore.getHTML(for: pageKey) {
            totalSize += Int64(html.utf8.count)
        }
        
        // 2. 懒加载资源大小 (ManifestCache/Resources/{pageKey}/)
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let resourceDir = cachesDir.appendingPathComponent("ManifestCache/Resources").appendingPathComponent(pageKey)
        totalSize += getDirectorySize(at: resourceDir)
        
        // 3. 持久化缓存大小 (WebBridgeKit/PersistentCache/{pageKey}/)
        let persistentDir = cachesDir.appendingPathComponent("WebBridgeKit/PersistentCache").appendingPathComponent(pageKey)
        totalSize += getDirectorySize(at: persistentDir)
        
        return totalSize
    }
    
    private func getDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                size += Int64(fileSize)
            }
        }
        
        return size
    }

    private func extractAppID(from pageKey: String) -> String {
        // 从 pageKey 中提取 AppID
        // pageKey 可能格式为 "lazy_123" 或 "appid_pagename"
        if pageKey.contains("_") {
            let components = pageKey.split(separator: "_", maxSplits: 1)
            return String(components[0])
        }
        return pageKey
    }

    private func loadIconData(from urlString: String?, name: String?, pageKey: String) -> Data? {
        // 1. 如果有 URL，尝试从缓存读取
        if let urlString = urlString, !urlString.isEmpty {
            // 检查是否是相对路径 (不包含 ://)
            if !urlString.contains("://") {
                // 相对路径，尝试从 ResourceCache 读取
                if let resource = resourceCache.get(urlString, for: pageKey) {
                    return resource.data
                }
            } else if let url = URL(string: urlString) {
                // 绝对路径，尝试从 ResourceCache 读取（资源下载器通常会使用 URL 的路径部分作为 key）
                // 先尝试完整 URL，再尝试路径部分
                if let resource = resourceCache.get(urlString, for: pageKey) {
                    return resource.data
                }
                
                let path = url.path
                if let resource = resourceCache.get(path, for: pageKey) {
                    return resource.data
                }
            }
        }
        
        // 2. 如果没有 URL 或加载失败，生成基于名称的默认图标
        return AppIconGenerator.generateIconData(from: name)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
