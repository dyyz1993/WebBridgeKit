//
//  ManifestDownloader.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

// MARK: - WebManifest

/// Web 资源清单（扩展版本）
public struct WebManifest: Codable {
    /// 版本号
    public let version: String

    /// 更新时间
    public let updatedAt: Date

    /// 描述信息
    public let description: String

    /// 是否持久化缓存
    public let persistent: Bool

    /// 资源映射：相对路径 -> 资源信息
    public let resources: [String: ResourceInfo]

    /// 可选：启动页面
    public let startURL: String?

    /// 可选：显示模式
    public let display: String?

    /// 可选：主题色
    public let themeColor: String?

    public init(
        version: String,
        updatedAt: Date,
        description: String,
        persistent: Bool = false,
        resources: [String: ResourceInfo],
        startURL: String? = nil,
        display: String? = nil,
        themeColor: String? = nil
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.description = description
        self.persistent = persistent
        self.resources = resources
        self.startURL = startURL
        self.display = display
        self.themeColor = themeColor
    }

    // 自定义解码以处理日期格式
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decode(String.self, forKey: .version)

        // 尝试多种日期格式
        if let timestamp = try? container.decode(Double.self, forKey: .updatedAt) {
            updatedAt = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                updatedAt = date
            } else {
                updatedAt = Date()
            }
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }

        description = try container.decode(String.self, forKey: .description)
        persistent = try container.decodeIfPresent(Bool.self, forKey: .persistent) ?? false
        resources = try container.decode([String: ResourceInfo].self, forKey: .resources)
        startURL = try container.decodeIfPresent(String.self, forKey: .startURL)
        display = try container.decodeIfPresent(String.self, forKey: .display)
        themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case updatedAt
        case description
        case persistent
        case resources
        case startURL
        case display
        case themeColor
    }
}

// MARK: - ResourceInfo

/// 资源信息
public struct ResourceInfo: Codable {
    /// 资源 URL
    public let url: URL

    /// 资源类型
    public let type: ResourceType

    /// MIME 类型
    public let mimeType: String?

    /// 资源大小（字节）
    public let size: Int?

    /// 可选：校验和（用于验证）
    public let integrity: String?

    /// 可选：是否必需
    public let required: Bool

    public init(
        url: URL,
        type: ResourceType,
        mimeType: String? = nil,
        size: Int? = nil,
        integrity: String? = nil,
        required: Bool = false
    ) {
        self.url = url
        self.type = type
        self.mimeType = mimeType
        self.size = size
        self.integrity = integrity
        self.required = required
    }

    // 自定义解码以处理字符串 URL
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let urlString = try? container.decode(String.self, forKey: .url) {
            guard let url = URL(string: urlString) else {
                throw ManifestDownloaderError.invalidResourceURL(urlString)
            }
            self.url = url
        } else {
            url = try container.decode(URL.self, forKey: .url)
        }

        // 处理类型字符串或枚举
        if let typeString = try? container.decode(String.self, forKey: .type) {
            type = ResourceType(rawValue: typeString) ?? .other
        } else {
            type = try container.decode(ResourceType.self, forKey: .type)
        }

        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        integrity = try container.decodeIfPresent(String.self, forKey: .integrity)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case type
        case mimeType
        case size
        case integrity
        case required
    }
}

// MARK: - ResourceType

/// 资源类型
public enum ResourceType: String, Codable {
    case image
    case stylesheet
    case script
    case font
    case document
    case audio
    case video
    case data
    case other
}

// MARK: - ManifestDownloaderError

/// Manifest 下载错误
public enum ManifestDownloaderError: Error, LocalizedError {
    case invalidURL(String)
    case networkError(Error)
    case invalidJSON(Error)
    case missingRequiredField(String)
    case emptyResponse
    case invalidResourceURL(String)
    case validationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid manifest URL: \(url)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidJSON(let error):
            return "Invalid JSON format: \(error.localizedDescription)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .emptyResponse:
            return "Empty response from server"
        case .invalidResourceURL(let url):
            return "Invalid resource URL: \(url)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        }
    }
}

// MARK: - ManifestDownloader

/// Manifest 下载器
public class ManifestDownloader {

    // MARK: - Singleton

    public static let shared = ManifestDownloader()

    // MARK: - Properties

    /// 缓存已下载的 manifest
    private var manifestCache: [String: CachedManifest] = [:]

    /// 缓存过期时间（秒）
    private var cacheExpiration: TimeInterval = 300 // 5 分钟

    /// URLSession
    private let session: URLSession

    /// JSON 解码器
    private let decoder: JSONDecoder

    /// 日期格式化器
    private let dateFormatter: ISO8601DateFormatter

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
    }

    // MARK: - Public Methods

    /// 下载 manifest
    /// - Parameters:
    ///   - url: manifest.json 的 URL
    ///   - useCache: 是否使用缓存
    ///   - completion: 完成回调
    public func download(
        from url: URL,
        useCache: Bool = true,
        completion: @escaping (Result<WebManifest, ManifestDownloaderError>) -> Void
    ) {
        // 检查缓存
        let cacheKey = url.absoluteString
        if useCache, let cached = manifestCache[cacheKey], !cached.isExpired {
            completion(.success(cached.manifest))
            return
        }

        // 创建下载任务
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            // 处理网络错误
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            // 验证响应
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.emptyResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                completion(.failure(.networkError(
                    NSError(domain: "HTTP", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    ])
                )))
                return
            }

            // 验证数据
            guard let data = data, !data.isEmpty else {
                completion(.failure(.emptyResponse))
                return
            }

            // 解析 JSON
            do {
                let manifest = try self.parseAndValidate(data: data)

                // 缓存结果
                self.manifestCache[cacheKey] = CachedManifest(
                    manifest: manifest,
                    timestamp: Date(),
                    expiration: self.cacheExpiration
                )

                completion(.success(manifest))
            } catch let error as ManifestDownloaderError {
                // 已经是 ManifestDownloaderError，直接传递
                completion(.failure(error))
            } catch let error as DecodingError {
                // 解码错误，转换为 ManifestDownloaderError
                completion(.failure(.invalidJSON(error)))
            } catch {
                // 其他错误，包装为 ManifestDownloaderError
                completion(.failure(.invalidJSON(error)))
            }
        }

        task.resume()
    }

    /// 检查更新
    /// - Parameters:
    ///   - current: 当前 manifest
    ///   - newURL: 新 manifest URL
    ///   - completion: 完成回调（是否有更新, 新 manifest）
    public func checkUpdate(
        current: WebManifest,
        newURL: URL,
        completion: @escaping (Bool, WebManifest?) -> Void
    ) {
        download(from: newURL) { result in
            switch result {
            case .success(let newManifest):
                let hasUpdate = self.compareVersions(current: current, new: newManifest)
                completion(hasUpdate, newManifest)

            case .failure:
                // 网络错误时认为无更新，使用现有版本
                completion(false, nil)
            }
        }
    }

    /// 批量下载 manifest
    /// - Parameters:
    ///   - urls: manifest URL 列表
    ///   - completion: 完成回调
    public func batchDownload(
        urls: [URL],
        completion: @escaping ([URL: Result<WebManifest, ManifestDownloaderError>]) -> Void
    ) {
        let group = DispatchGroup()
        var results: [URL: Result<WebManifest, ManifestDownloaderError>] = [:]
        let queue = DispatchQueue(label: "com.webbridgekit.manifestdownloader", attributes: .concurrent)

        for url in urls {
            group.enter()
            download(from: url) { result in
                queue.async(flags: .barrier) {
                    results[url] = result
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    /// 清除缓存
    public func clearCache() {
        manifestCache.removeAll()
    }

    /// 清除特定缓存
    /// - Parameter url: manifest URL
    public func clearCache(for url: URL) {
        manifestCache.removeValue(forKey: url.absoluteString)
    }

    /// 设置缓存过期时间
    /// - Parameter seconds: 过期时间（秒）
    public func setCacheExpiration(_ seconds: TimeInterval) {
        cacheExpiration = seconds
    }

    // MARK: - Private Methods

    /// 解析并验证 manifest
    private func parseAndValidate(data: Data) throws -> WebManifest {
        // Validate data is not empty
        guard !data.isEmpty else {
            throw ManifestDownloaderError.invalidJSON(
                NSError(domain: "ManifestDownloader", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Empty manifest data"
                ])
            )
        }

        do {
            // Attempt to decode the manifest
            let manifest = try decoder.decode(WebManifest.self, from: data)

            // Validate the manifest using proper error handling
            try validate(manifest)

            return manifest
        } catch let error as DecodingError {
            // Convert decoding errors to ManifestDownloaderError
            throw parseDecodingError(error)
        } catch let error as ManifestDownloaderError {
            // Re-throw ManifestDownloaderError as-is
            throw error
        } catch {
            // Wrap any other errors
            throw ManifestDownloaderError.invalidJSON(error)
        }
    }

    /// 验证 manifest with detailed error reporting
    private func validate(_ manifest: WebManifest) throws {
        var errors: [String] = []

        // 验证版本号
        if manifest.version.isEmpty {
            errors.append("version cannot be empty")
        }

        // 验证版本兼容性
        if !ManifestVersion.isSupported(manifest.version) {
            errors.append("Unsupported manifest version: \(manifest.version)")
        }

        // 验证描述
        if manifest.description.isEmpty {
            errors.append("description cannot be empty")
        }

        // 验证资源
        if manifest.resources.isEmpty {
            errors.append("resources cannot be empty")
        }

        // 验证每个资源
        for (path, resource) in manifest.resources {
            // Validate resource path for security
            if path.contains("..") {
                errors.append("Path traversal detected in resource: \(path)")
            }

            if path.hasPrefix("/") {
                errors.append("Absolute paths not allowed in resource: \(path)")
            }

            // Validate resource URL
            if resource.url.absoluteString.isEmpty {
                errors.append("Invalid URL for resource: \(path)")
            }

            // Verify URL scheme is allowed
            if let scheme = resource.url.scheme?.lowercased() {
                let allowedSchemes = ["http", "https", "data"]
                if !allowedSchemes.contains(scheme) {
                    errors.append("Disallowed URL scheme '\(scheme)' for resource: \(path)")
                }
            }

            // 验证必需资源
            if resource.required && resource.type == .other {
                errors.append("Required resource \(path) has unknown type")
            }

            // Validate resource type
            if resource.type == .other {
                // Log as warning, not error
                continue
            }
        }

        if !errors.isEmpty {
            throw ManifestDownloaderError.validationFailed(errors)
        }
    }

    /// 比较版本
    private func compareVersions(current: WebManifest, new: WebManifest) -> Bool {
        // 优先比较版本号
        if current.version != new.version {
            return current.version < new.version
        }

        // 比较更新时间
        return new.updatedAt > current.updatedAt
    }

    /// 解析解码错误
    private func parseDecodingError(_ error: DecodingError) -> ManifestDownloaderError {
        switch error {
        case .typeMismatch(let type, let context):
            return .invalidJSON(NSError(
                domain: "ManifestDecoder",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                ]
            ))
        case .valueNotFound(let type, let context):
            return .missingRequiredField("\(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .keyNotFound(let key, let context):
            return .missingRequiredField("\(key.stringValue) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        default:
            return .invalidJSON(error)
        }
    }
}

// MARK: - CachedManifest

/// 缓存的 manifest
private struct CachedManifest {
    /// manifest 数据
    let manifest: WebManifest

    /// 缓存时间戳
    let timestamp: Date

    /// 过期时间（秒）
    let expiration: TimeInterval

    /// 是否已过期
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expiration
    }
}
