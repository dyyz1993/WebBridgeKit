//
//  HTMLAppOfflinePackageModels.swift
//  WebBridgeKit
//
//  Public protocol objects for signed, strongly offline HTML app packages.
//

import Foundation

public struct HTMLAppOfflinePackageManifest: Codable, Equatable, Sendable {
    public static let supportedSchemaVersion = "1"

    public let schemaVersion: String
    public let appID: String
    public let version: String
    public let entrypoint: String
    public let files: [HTMLAppOfflinePackageFile]

    public init(
        schemaVersion: String = HTMLAppOfflinePackageManifest.supportedSchemaVersion,
        appID: String,
        version: String,
        entrypoint: String,
        files: [HTMLAppOfflinePackageFile]
    ) {
        self.schemaVersion = schemaVersion
        self.appID = appID
        self.version = version
        self.entrypoint = entrypoint
        self.files = files
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appID = "appId"
        case version, entrypoint, files
    }
}

public struct HTMLAppOfflinePackageFile: Codable, Equatable, Sendable {
    public let path: String
    public let url: String
    public let sha256: String
    public let size: Int64
    public let mimeType: String

    public init(path: String, url: String, sha256: String, size: Int64, mimeType: String) {
        self.path = path
        self.url = url
        self.sha256 = sha256
        self.size = size
        self.mimeType = mimeType
    }
}

public struct InstalledHTMLAppPackage: Codable, Equatable, Sendable {
    public let appID: String
    public let version: String
    public let entrypoint: String
    public let directoryName: String
    public let resourceManifestSHA256: String
    public let installedAt: Date

    public init(
        appID: String,
        version: String,
        entrypoint: String,
        directoryName: String,
        resourceManifestSHA256: String,
        installedAt: Date
    ) {
        self.appID = appID
        self.version = version
        self.entrypoint = entrypoint
        self.directoryName = directoryName
        self.resourceManifestSHA256 = resourceManifestSHA256
        self.installedAt = installedAt
    }
}

public enum HTMLAppPackageProgress: Equatable, Sendable {
    case downloadingManifest
    case validatingManifest
    case downloadingFile(current: Int, total: Int, path: String)
    case validatingFile(current: Int, total: Int, path: String)
    case activating
    case completed
    case usingPreviousVersion
}

public struct HTMLAppOfflinePackageLimits: Equatable, Sendable {
    public var maximumManifestBytes: Int
    public var maximumFileCount: Int
    public var maximumFileBytes: Int64
    public var maximumPackageBytes: Int64

    public init(
        maximumManifestBytes: Int = 1_048_576,
        maximumFileCount: Int = 2_000,
        maximumFileBytes: Int64 = 50 * 1_024 * 1_024,
        maximumPackageBytes: Int64 = 250 * 1_024 * 1_024
    ) {
        self.maximumManifestBytes = maximumManifestBytes
        self.maximumFileCount = maximumFileCount
        self.maximumFileBytes = maximumFileBytes
        self.maximumPackageBytes = maximumPackageBytes
    }
}

public struct HTMLAppPackageTransportResponse: Sendable {
    public let data: Data
    public let finalURL: URL

    public init(data: Data, finalURL: URL) {
        self.data = data
        self.finalURL = finalURL
    }
}

public protocol HTMLAppPackageTransport: Sendable {
    func data(from url: URL, maximumBytes: Int) async throws -> HTMLAppPackageTransportResponse
}

public enum HTMLAppOfflinePackageError: Error, Equatable, LocalizedError {
    case parentManifestNotEligible
    case invalidResourceManifestDigest
    case resourceManifestTooLarge
    case resourceManifestDigestMismatch
    case invalidResourceManifest
    case unsupportedSchemaVersion(String)
    case identityMismatch
    case emptyPackage
    case tooManyFiles
    case invalidPath(String)
    case duplicatePath(String)
    case pathConflict(String)
    case missingEntrypoint
    case invalidURL(String)
    case disallowedOrigin(String)
    case invalidFileDigest(String)
    case invalidFileSize(String)
    case fileTooLarge(String)
    case packageTooLarge
    case fileSizeMismatch(String)
    case fileDigestMismatch(String)
    case transportFailed(String)
    case persistenceFailed
    case noInstalledPackage

    public var errorDescription: String? {
        switch self {
        case .parentManifestNotEligible: return "The signed parent manifest is not eligible for strong offline installation"
        case .invalidResourceManifestDigest: return "The parent resource manifest digest is invalid"
        case .resourceManifestTooLarge: return "The resource manifest exceeds the configured size limit"
        case .resourceManifestDigestMismatch: return "The resource manifest SHA-256 does not match the signed parent manifest"
        case .invalidResourceManifest: return "The resource manifest is invalid"
        case .unsupportedSchemaVersion(let value): return "Unsupported offline package schema: \(value)"
        case .identityMismatch: return "The offline package appId or version does not match its parent manifest"
        case .emptyPackage: return "The offline package contains no files"
        case .tooManyFiles: return "The offline package contains too many files"
        case .invalidPath(let path): return "Unsafe offline package path: \(path)"
        case .duplicatePath(let path): return "Duplicate offline package path: \(path)"
        case .pathConflict(let path): return "Offline package file/directory path conflict: \(path)"
        case .missingEntrypoint: return "The offline package entrypoint is missing"
        case .invalidURL(let value): return "Invalid offline package URL: \(value)"
        case .disallowedOrigin(let value): return "Offline package URL has a disallowed origin: \(value)"
        case .invalidFileDigest(let path): return "Invalid SHA-256 for offline package file: \(path)"
        case .invalidFileSize(let path): return "Invalid size for offline package file: \(path)"
        case .fileTooLarge(let path): return "Offline package file exceeds the configured size limit: \(path)"
        case .packageTooLarge: return "The offline package exceeds the configured total size limit"
        case .fileSizeMismatch(let path): return "Offline package file size mismatch: \(path)"
        case .fileDigestMismatch(let path): return "Offline package file SHA-256 mismatch: \(path)"
        case .transportFailed(let value): return "Offline package download failed: \(value)"
        case .persistenceFailed: return "Unable to persist the offline package"
        case .noInstalledPackage: return "No complete offline package is installed"
        }
    }
}
