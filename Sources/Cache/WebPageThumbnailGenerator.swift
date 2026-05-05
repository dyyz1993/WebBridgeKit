//
//  WebPageThumbnailGenerator.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit
import WebKit

// Framework imports

/// 页面缩略图生成器
/// 单例模式，负责截图、压缩和内存管理
public class WebPageThumbnailGenerator {

    static let shared = WebPageThumbnailGenerator()

    private init() {}

    // MARK: - Configuration

    /// 缩略图尺寸
    let thumbnailSize = CGSize(width: 300, height: 400)

    /// 最大内存占用（MB）
    let maxMemoryMB: Int = 50

    /// JPEG压缩质量
    let compressionQuality: CGFloat = 0.7

    // MARK: - Public Methods

    /// 为WebView生成缩略图
    /// - Parameters:
    ///   - webView: 要截图的WebView
    ///   - url: 页面URL
    ///   - completion: 完成回调，返回缩略图数据
    func generateThumbnail(for webView: WKWebView, url: URL, completion: @escaping (Data?) -> Void) {
        // 检查内存使用情况
        checkMemoryUsage()

        DispatchQueue.main.async {
            // 使用UIView的截图方法
            let renderer = UIGraphicsImageRenderer(size: webView.bounds.size)
            let image = renderer.image { context in
                webView.layer.render(in: context.cgContext)
            }

            // 压缩图片
            let thumbnail = self.resizeAndCompress(image: image)

            // 转换为JPEG数据
            let data = thumbnail.jpegData(compressionQuality: self.compressionQuality)

            WebBridgeLogger.shared.log(.debug, "📸 Generated thumbnail: \(thumbnail.size), \(data?.count ?? 0) bytes")

            completion(data)
        }
    }

    /// 在页面加载完成后延迟截图
    /// - Parameters:
    ///   - webView: WebView
    ///   - url: 页面URL
    ///   - delay: 延迟时间（秒），默认2秒
    ///   - completion: 完成回调
    func generateThumbnailAfterLoad(
        for webView: WKWebView,
        url: URL,
        delay: TimeInterval = 2.0,
        completion: @escaping (Data?) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.generateThumbnail(for: webView, url: url, completion: completion)
        }
    }

    // MARK: - Private Methods

    /// 调整图片大小并压缩
    private func resizeAndCompress(image: UIImage) -> UIImage {
        // 计算缩放比例，保持宽高比
        let widthRatio = thumbnailSize.width / image.size.width
        let heightRatio = thumbnailSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        // 渲染缩略图
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 检查并清理内存
    private func checkMemoryUsage() {
        let memoryMB = getMemoryUsage()

        if memoryMB > maxMemoryMB {
            WebBridgeLogger.shared.log(.warning, category: .cache, message: "⚠️ Memory usage high: \(memoryMB)MB, cleaning old thumbnails")

            // 清理旧的缩略图（保留最近100个）
            Task {
                try? await WebPageHistoryManager.shared.cleanOldThumbnails(keepLatest: 100)
            }
        }
    }

    /// 获取当前内存使用量（MB）
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / 1024 / 1024
        }
        return 0
    }
}
