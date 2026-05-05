//
//  ResourceDownloader.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// Framework imports

/// 资源下载结果
public struct ResourceDownloadResult {
    let originalURL: URL
    let localPath: String
    let size: Int64
}

/// 资源下载器
/// 支持并发下载、进度回调、去重处理
public class ResourceDownloader {

    private var downloadedResources: Set<String> = []
    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // 设置 User-Agent 模拟浏览器
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        self.urlSession = URLSession(configuration: config)
    }

    /// 下载资源
    /// - Parameters:
    ///   - resources: 资源URL列表
    ///   - baseURL: 基础URL
    ///   - directory: 保存目录
    ///   - progress: 进度回调 (0.0 - 1.0)
    /// - Returns: 下载结果映射 [原始URL: 本地路径]
    func downloadResources(
        _ resources: [ResourceURL],
        to directory: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> [URL: String] {
        var results: [URL: String] = [:]
        let totalCount = resources.count
        var completedCount = 0

        // 使用TaskGroup并发下载
        try await withThrowingTaskGroup(of: (URL, String, Int64).self) { group in
            for resource in resources {
                // 跳过已下载的
                if downloadedResources.contains(resource.originalURL.absoluteString) {
                    completedCount += 1
                    progress(Double(completedCount) / Double(totalCount))
                    continue
                }

                group.addTask {
                    let (localPath, size) = try await self.downloadSingleResource(resource, to: directory)
                    return (resource.originalURL, localPath, size)
                }
            }

            // 收集结果
            for try await (url, path, _) in group {
                results[url] = path
                downloadedResources.insert(url.absoluteString)
                completedCount += 1
                progress(Double(completedCount) / Double(totalCount))
            }
        }

        return results
    }

    /// 下载单个资源
    private func downloadSingleResource(
        _ resource: ResourceURL,
        to directory: URL
    ) async throws -> (String, Int64) {
        // 确定子目录
        let subdir = getSubdirectory(for: resource.type)
        let targetDir = directory.appendingPathComponent(subdir)

        // 创建目录
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        // 生成本地文件名
        let filename = generateFilename(for: resource.originalURL)
        let localPath = targetDir.appendingPathComponent(filename)

        // 检查文件是否已存在
        if FileManager.default.fileExists(atPath: localPath.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: localPath.path)
            let size = attributes[FileAttributeKey.size] as? Int64 ?? 0
            return (subdir + "/" + filename, size)
        }

        // 下载资源
        let (data, response) = try await urlSession.data(from: resource.originalURL)

        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.invalidResponse
        }

        // 处理图片压缩
        let finalData: Data
        if resource.type == .image {
            finalData = compressImageIfNeeded(data)
        } else {
            finalData = data
        }

        // 写入文件
        try finalData.write(to: localPath)

        WebBridgeLogger.shared.log(.debug, "✅ Downloaded: \(resource.originalURL.lastPathComponent) -> \(subdir)/\(filename)")

        return (subdir + "/" + filename, Int64(finalData.count))
    }

    /// 下载HTML内容
    func downloadHTML(from url: URL) async throws -> String {
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw DownloadError.invalidEncoding
        }

        return html
    }

    // MARK: - Helper

    private func getSubdirectory(for type: HTMLResourceType) -> String {
        switch type {
        case .css:
            return "css"
        case .js:
            return "js"
        case .image:
            return "images"
        case .font:
            return "fonts"
        case .media:
            return "media"
        case .favicon:
            return "images"
        case .other:
            return "other"
        }
    }

    private func generateFilename(for url: URL) -> String {
        // 如果URL有明确的文件名，直接使用
        if !url.pathExtension.isEmpty {
            return url.lastPathComponent
        }

        // 否则生成哈希文件名
        let hash = url.absoluteString.hashValue
        return "resource_\(abs(hash)).dat"
    }

    private func compressImageIfNeeded(_ data: Data) -> Data {
        // ⚠️ UIKit 组件（如 UIImage）必须在主线程使用
        // 这里直接返回原始数据，避免在后台线程使用 UIImage
        // 如果需要压缩功能，应该使用 ImageIO 框架（支持后台线程）
        return data
    }

    enum DownloadError: Error {
        case invalidResponse
        case invalidEncoding
    }
}
