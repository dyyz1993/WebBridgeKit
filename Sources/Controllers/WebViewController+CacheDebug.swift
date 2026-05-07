//
//  WebViewController+CacheDebug.swift
//  WebBridgeKit
//

import UIKit
import WebKit

// MARK: - Cache Debug Methods
extension WebViewController {

    /// 设置缓存调试按钮
    func setupCacheDebugButton() {
        let debugButton = UIBarButtonItem(
            title: "🔍 Cache",
            style: .plain,
            target: self,
            action: #selector(showCacheDebugInfo)
        )
        navigationItem.rightBarButtonItem = debugButton
        print("✅ [BarkWebVC] Cache debug button added")
    }

    /// 显示缓存调试信息
    @objc private func showCacheDebugInfo() {
        // 获取当前页面 URL
        let currentURL = webView.url?.absoluteString ?? "No URL loaded"

        // 收集缓存信息
        var debugInfo = """
        🔍 WebBridgeKit Cache Debug Info
        =================================

        📍 Current Page URL:
        \(currentURL)

        🌐 System URLCache Info:
        """

        // 获取系统 URLCache 信息
        let urlCache = URLCache.shared
        let currentMemoryUsage = urlCache.currentMemoryUsage
        let currentDiskUsage = urlCache.currentDiskUsage
        debugInfo += """
        - Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(currentMemoryUsage), countStyle: .memory))
        - Disk Usage: \(ByteCountFormatter.string(fromByteCount: Int64(currentDiskUsage), countStyle: .file))
        - Memory Capacity: \(ByteCountFormatter.string(fromByteCount: Int64(urlCache.memoryCapacity), countStyle: .memory))
        - Disk Capacity: \(ByteCountFormatter.string(fromByteCount: Int64(urlCache.diskCapacity), countStyle: .file))

        📦 Compressed Cache Info:
        """

        // 获取压缩缓存信息
        let compressedCacheInfo = WebCompressedCacheStore.shared.getMemoryInfo()
        debugInfo += """
        - Total Entries: \(compressedCacheInfo.totalEntries)
        - Original Size: \(compressedCacheInfo.formattedTotalOriginalSize)
        - Compressed Size: \(compressedCacheInfo.formattedTotalCompressedSize)
        - Compression Ratio: \(compressedCacheInfo.formattedCompressionRatio)
        - Saved Space: \(compressedCacheInfo.formattedSavedSpace)

        📋 Cached Resources Summary:
        """

        // 获取缓存条目统计
        let entries = WebCompressedCacheStore.shared.getAllEntries()
        let domainGroups = Dictionary(grouping: entries) { $0.domain }
        debugInfo += "\n- Total Cached Resources: \(entries.count)"
        debugInfo += "\n- Cached Domains: \(domainGroups.count)"

        // 显示前 5 个域名
        let topDomains = domainGroups.sorted { $0.value.count > $1.value.count }.prefix(5)
        for (domain, resources) in topDomains {
            debugInfo += "\n  • \(domain): \(resources.count) resources"
        }

        debugInfo += """

        📄 Page Cache Info:
        """

        // 获取页面缓存信息
        let cachedPages = WebPageOfflineCacheManager.shared.getCachedPages()
        debugInfo += "\n- Cached Pages: \(cachedPages.count)"

        // 显示前 3 个已缓存页面
        let topPages = cachedPages.prefix(3)
        for page in topPages {
            debugInfo += "\n  • \(page.title): \(ByteCountFormatter.string(fromByteCount: page.totalSize, countStyle: .file))"
        }

        debugInfo += """

        📂 Cache Directory Path:
        """

        // 获取缓存目录路径
        let cachePath = WebCompressedCacheStore.shared.getCacheDirectory()
        debugInfo += "\n\(cachePath.path)"

        // 打印到控制台
        print(debugInfo)

        // 显示 Alert
        let alert = UIAlertController(
            title: "Cache Debug Info",
            message: debugInfo,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: "Copy to Clipboard",
            style: .default
        ) { [weak self] _ in
            UIPasteboard.general.string = debugInfo
            self?.showToast(message: "Debug info copied to clipboard")
        })

        alert.addAction(UIAlertAction(
            title: "Clear All Cache",
            style: .destructive
        ) { [weak self] _ in
            self?.clearAllCache()
        })

        alert.addAction(UIAlertAction(
            title: "Close",
            style: .cancel
        ))

        // 对于 iPad 支持
        if let popoverController = alert.popoverPresentationController {
            if let barButton = navigationItem.rightBarButtonItem {
                popoverController.barButtonItem = barButton
            }
        }

        present(alert, animated: true)
    }

    /// 清除所有缓存
    private func clearAllCache() {
        // 清除压缩缓存
        WebCompressedCacheStore.shared.clearAll()

        // 清除系统 URLCache
        URLCache.shared.removeAllCachedResponses()

        // 清除 WKWebsiteDataStore
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let from = Date.distantPast
        _ = dataStore.removeData(ofTypes: dataTypes, modifiedSince: from) { [weak self] in
            Task { @MainActor [weak self] in
                self?.showToast(message: "All cache cleared successfully")
                print(" All cache cleared")
            }
        }
    }

    /// 显示 Toast 提示
    func showToast(message: String) {
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        present(alert, animated: true)

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            alert.dismiss(animated: true)
        }
    }
}
