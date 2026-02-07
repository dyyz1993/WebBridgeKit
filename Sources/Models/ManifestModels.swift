//
//  ManifestModels.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Manifest

/// 资源清单
public struct Manifest: Codable {
    /// 资源映射：相对路径 -> 真实 URL
    public var resources: [String: String]

    /// 页面版本（用于缓存失效），默认 "0.0.1"
    public var version: String?

    /// 是否持久化缓存
    public var persistent: Bool?

    /// 最后更新时间
    public var lastUpdated: Date?

    /// 应用标识符（用于缓存路径和清理）
    /// 如果不提供，将使用域名作为 AppID
    public var appid: String?

    /// 应用名称（用于显示）
    /// 如果不提供，将从 HTML title 提取
    public var name: String?

    /// 应用图标 URL（用于显示）
    /// 如果不提供，将生成默认圆形图标（使用名称首字母）
    public var icon: String?

    /// 是否置顶
    public var isPinned: Bool?

    /// 是否收藏
    public var isFavorite: Bool?

    /// 最后访问时间
    public var lastAccessed: Date?

    /// 访问频率计数
    public var accessCount: Int?

    public init(
        resources: [String: String] = [:],
        version: String? = nil,
        persistent: Bool? = false,
        lastUpdated: Date? = nil,
        appid: String? = nil,
        name: String? = nil,
        icon: String? = nil,
        isPinned: Bool? = false,
        isFavorite: Bool? = false,
        lastAccessed: Date? = nil,
        accessCount: Int? = 0
    ) {
        self.resources = resources
        self.version = version
        self.persistent = persistent
        self.lastUpdated = lastUpdated
        self.appid = appid
        self.name = name
        self.icon = icon
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
    }

    /// 获取版本号，如果没有则返回默认值
    public var resolvedVersion: String {
        return version ?? "0.0.1"
    }
}

// MARK: - ResourceData

/// 资源数据
public struct ResourceData {
    /// 相对路径
    public let relativePath: String

    /// 资源数据
    public let data: Data

    /// MIME 类型
    public let mimeType: String

    public init(relativePath: String, data: Data, mimeType: String) {
        self.relativePath = relativePath
        self.data = data
        self.mimeType = mimeType
    }
}

// MARK: - ManifestCacheError

/// Manifest 缓存错误
public enum ManifestCacheError: Error, LocalizedError {
    case managerDeallocated
    case resourceNotFound(String)
    case emptyData
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .managerDeallocated:
            return "Manager was deallocated"
        case .resourceNotFound(let path):
            return "Resource not found: \(path)"
        case .emptyData:
            return "Empty data received"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}

// MARK: - AppID Resolver

/// AppID 解析器
/// 负责从 manifest 或 URL 中解析出 AppID，用于缓存路径组织和清理
public struct AppIDResolver {

    /// 从 manifest 和 URL 解析 AppID
    /// - Parameters:
    ///   - appid: manifest 中提供的 appid（可选）
    ///   - url: 页面 URL
    /// - Returns: 解析出的 AppID
    public static func resolveAppID(from appid: String?, url: URL) -> String {
        // 1. 优先使用 manifest 中配置的 appid
        if let configuredAppID = appid, !configuredAppID.isEmpty {
            return validateAndSanitizeAppID(configuredAppID)
        }

        // 2. 回退到从 URL 提取域名作为 appid
        return extractAppID(from: url)
    }

    /// 从 URL 中提取 AppID（使用域名）
    /// - Parameter url: 页面 URL
    /// - Returns: 提取的 AppID
    public static func extractAppID(from url: URL) -> String {
        guard let host = url.host else {
            return "unknown"
        }

        // 规范化域名：转换为小写，替换特殊字符为下划线
        // example.com -> example_com
        // localhost:8080 -> localhost_8080
        // 192.168.1.1 -> 192_168_1_1
        return host
            .lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    /// 验证并清理 AppID（防止目录遍历攻击等安全问题）
    /// - Parameter appid: 原始 AppID
    /// - Returns: 清理后的安全 AppID
    public static func validateAndSanitizeAppID(_ appid: String) -> String {
        // 只保留字母、数字、点、下划线、连字符
        // 并将点替换为下划线（用于文件系统安全）
        let sanitized = appid
            .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        // 防止空字符串
        return sanitized.isEmpty ? "invalid" : sanitized
    }

    /// 从 URL 和 Manifest 中解析 AppID
    /// - Parameters:
    ///   - url: 页面 URL
    ///   - manifest: 清单文件（可选）
    /// - Returns: 规范化的 AppID
    public static func resolveAppID(from url: URL, manifest: Manifest? = nil) -> String {
        if let appid = manifest?.appid, !appid.isEmpty {
            return validateAndSanitizeAppID(appid)
        }
        
        // 回退逻辑：使用 host + path，并进行规范化，以支持同一域名下的不同页面
        let host = url.host ?? "unknown"
        let path = url.path.replacingOccurrences(of: "/", with: "_")
        let identifier = host + path
        return validateAndSanitizeAppID(identifier)
    }

    /// 提取 HTML 中的 title 标签内容
    /// - Parameter html: HTML 内容
    /// - Returns: title 文本，如果未找到则返回 nil
    public static func extractTitle(from html: String) -> String? {
        // 匹配 <title>...</title> 标签
        let pattern = "<title\\s*>(.*?)<\\/title\\s*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }

        var title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        // 移除 HTML 实体解码（简单处理）
        title = title.replacingOccurrences(of: "&amp;", with: "&")
        title = title.replacingOccurrences(of: "&lt;", with: "<")
        title = title.replacingOccurrences(of: "&gt;", with: ">")
        title = title.replacingOccurrences(of: "&quot;", with: "\"")
        title = title.replacingOccurrences(of: "&#39;", with: "'")

        return title.isEmpty ? nil : title
    }
}

// MARK: - App Icon Generator

/// 应用图标生成器
/// 用于生成默认的圆形文本图标
public class AppIconGenerator {
    public enum Error: Swift.Error, LocalizedError {
        case invalidText
        case imageGenerationFailed

        public var errorDescription: String? {
            switch self {
            case .invalidText:
                return "Invalid text for icon generation"
            case .imageGenerationFailed:
                return "Failed to generate icon image"
            }
        }
    }

    /// 生成圆形文本图标
    /// - Parameters:
    ///   - text: 要显示的文本（通常为首字母）
    ///   - size: 图标大小
    ///   - backgroundColor: 背景颜色
    ///   - textColor: 文本颜色
    /// - Returns: 生成的 UIImage
    public static func generateCircularIcon(
        text: String,
        size: CGSize = CGSize(width: 64, height: 64),
        backgroundColor: UIColor = .systemBlue,
        textColor: UIColor = .white
    ) throws -> UIImage {
        // 验证文本
        let displayText = extractFirstCharacter(from: text)
        guard !displayText.isEmpty else {
            throw Error.invalidText
        }

        // 创建图形上下文
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // 绘制圆形背景
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(ovalIn: rect)
            backgroundColor.setFill()
            path.fill()

            // 配置文本属性
            let fontSize = min(size.width, size.height) * 0.5
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: textColor
            ]

            // 计算文本位置（居中）
            let textSize = (displayText as NSString).size(withAttributes: attributes)
            let textPoint = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )

            // 绘制文本
            (displayText as NSString).draw(at: textPoint, withAttributes: attributes)
        }

        return image
    }

    /// 从文本中提取第一个字符（用于图标显示）
    /// - Parameter text: 原始文本
    /// - Returns: 第一个字符（大写）
    private static func extractFirstCharacter(from text: String) -> String {
        guard let firstChar = text.first else { return "" }

        // 处理中文、英文等字符
        return String(firstChar).uppercased()
    }

    /// 从应用名称生成图标
    /// - Parameters:
    ///   - appName: 应用名称
    ///   - size: 图标大小
    /// - Returns: 生成的 UIImage
    public static func generateIcon(
        from appName: String?,
        size: CGSize = CGSize(width: 64, height: 64)
    ) -> UIImage? {
        guard let appName = appName, !appName.isEmpty else {
            return generateDefaultIcon(size: size)
        }

        do {
            // 根据首字母生成不同颜色的图标
            let firstCharString = extractFirstCharacter(from: appName)
            guard let firstChar = firstCharString.first else {
                return generateDefaultIcon(size: size)
            }
            let color = colorForCharacter(firstChar)
            return try generateCircularIcon(
                text: firstCharString,
                size: size,
                backgroundColor: color
            )
        } catch {
            return generateDefaultIcon(size: size)
        }
    }

    /// 根据字符生成颜色（确保相同字符始终产生相同颜色）
    /// - Parameter char: 字符
    /// - Returns: UIColor
    private static func colorForCharacter(_ char: Character) -> UIColor {
        // 预定义的一组鲜艳颜色（iOS 14.0+ 兼容）
        let colors: [UIColor] = [
            .systemBlue, .systemPurple, .systemPink, .systemRed,
            .systemOrange, .systemYellow, .systemGreen, .systemTeal
        ]

        // 使用字符的 ASCII 码值选择颜色
        let index = abs(char.hashValue) % colors.count
        return colors[index]
    }

    /// 生成默认图标（问号）
    /// - Parameter size: 图标大小
    /// - Returns: 默认 UIImage
    public static func generateDefaultIcon(size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        return try! generateCircularIcon(
            text: "?",
            size: size,
            backgroundColor: .systemGray
        )
    }

    /// 为应用生成图标数据（用于缓存）
    /// - Parameters:
    ///   - appName: 应用名称
    ///   - size: 图标大小
    /// - Returns: PNG 数据
    public static func generateIconData(
        from appName: String?,
        size: CGSize = CGSize(width: 64, height: 64)
    ) -> Data? {
        guard let icon = generateIcon(from: appName, size: size) else {
            return nil
        }
        return icon.pngData()
    }
}
