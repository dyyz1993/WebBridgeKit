//
//  ManifestLoaderTypes.swift
//  WebBridgeKit
//
//  Nested types for PersistentManifestLoader (split from main file).
//

import Foundation

// MARK: - LoaderError

extension PersistentManifestLoader {

    public enum LoaderError: Error, LocalizedError {
        case manifestNotFound
        case invalidManifestFormat
        case persistentModeDisabled
        case htmlDownloadFailed(Error)
        case resourceDownloadFailed(String, Error)
        case cacheDirectoryCreationFailed
        case webViewNotAvailable

        public var errorDescription: String? {
            switch self {
            case .manifestNotFound:
                return "Manifest file not found"
            case .invalidManifestFormat:
                return "Invalid manifest format"
            case .persistentModeDisabled:
                return "Persistent mode is not enabled for this page"
            case .htmlDownloadFailed(let error):
                return "Failed to download HTML: \(error.localizedDescription)"
            case .resourceDownloadFailed(let resource, let error):
                return "Failed to download resource '\(resource)': \(error.localizedDescription)"
            case .cacheDirectoryCreationFailed:
                return "Failed to create cache directory"
            case .webViewNotAvailable:
                return "WebView is not available"
            }
        }
    }
}

// MARK: - WebManifest

extension PersistentManifestLoader {

    public struct WebManifest: Codable {
        public let persistent: Bool
        public let resources: [String: String]
        public let version: String?
        public let appid: String?
        public let name: String?
        public let icon: String?
        public let updatedAt: String?
        public let description: String?

        private enum CodingKeys: String, CodingKey {
            case persistent, resources, version, appid, name, icon, updatedAt, description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            persistent = try container.decodeIfPresent(Bool.self, forKey: .persistent) ?? false
            version = try container.decodeIfPresent(String.self, forKey: .version)
            appid = try container.decodeIfPresent(String.self, forKey: .appid)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            resources = try Self.decodeResources(from: container)
        }

        private static func decodeResources(from container: KeyedDecodingContainer<CodingKeys>) throws -> [String: String] {
            if let flat = try? container.decode([String: String].self, forKey: .resources) {
                return flat
            }
            if let nested = try? container.decode([String: [String: AnyCodableValue]].self, forKey: .resources) {
                var flat: [String: String] = [:]
                for (_, entries) in nested {
                    for (path, value) in entries {
                        if let obj = value.objectValue, let url = obj["url"]?.stringValue {
                            flat[path] = url
                        } else if let str = value.stringValue {
                            flat[path] = str
                        }
                    }
                }
                return flat
            }
            return [:]
        }

        public init(
            persistent: Bool,
            resources: [String: String],
            version: String? = nil,
            appid: String? = nil,
            name: String? = nil,
            icon: String? = nil,
            updatedAt: String? = nil,
            description: String? = nil
        ) {
            self.persistent = persistent
            self.resources = resources
            self.version = version
            self.appid = appid
            self.name = name
            self.icon = icon
            self.updatedAt = updatedAt
            self.description = description
        }

        public var resolvedVersion: String {
            return version ?? "0.0.1"
        }
    }
}

private struct AnyCodableValue: Codable {
    let stringValue: String?
    let objectValue: [String: AnyCodableValue]?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            stringValue = str
            objectValue = nil
        } else if let obj = try? container.decode([String: AnyCodableValue].self) {
            stringValue = nil
            objectValue = obj
        } else {
            stringValue = nil
            objectValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = stringValue {
            try container.encode(str)
        } else if let obj = objectValue {
            try container.encode(obj)
        }
    }
}

// MARK: - LoadingState

extension PersistentManifestLoader {

    /// 加载状态
    public enum LoadingState {
        case idle
        case fetchingManifest
        case downloadingResources(current: Int, total: Int)
        case preparingHTML
        case loadingWebView
        case completed
        case failed(Error)
    }
}
