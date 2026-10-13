//
//  HTMLAppOfflinePackageInstaller.swift
//  WebBridgeKit
//

import CryptoKit
import Foundation

public struct ResolvedHTMLAppWebManifest: Codable, Equatable, Sendable {
    public let appID: String
    /// Digest of the signed parent binding that authorized these presentation
    /// fields. Older stored records decode this as nil and are refreshed once.
    public let sourceSHA256: String?
    public let name: String
    public let shortName: String?
    public let startURL: URL
    public let scopeURL: URL
    public let display: String?
    public let themeColor: String?
    public let backgroundColor: String?
    public let iconURLs: [URL]
    public let drelOffline: DrelOfflinePackageDeclaration?
}

/// Durable presentation metadata derived from a digest-pinned Web App
/// Manifest. Security and launch decisions continue to use the signed parent
/// manifest; this store exists only so names, colors and icons remain
/// available while the device is offline.
public final class HTMLAppPresentationMetadataStore: @unchecked Sendable {
    private let storage: HTMLAppRuntimeStorage
    private let storageKey: String
    private let lock = NSLock()
    private var metadata: [String: ResolvedHTMLAppWebManifest]

    public init(
        storage: HTMLAppRuntimeStorage = HTMLAppUserDefaultsStorage(),
        storageKey: String = "com.webbridgekit.html-app-runtime.presentation-metadata"
    ) {
        self.storage = storage
        self.storageKey = storageKey
        if let data = storage.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: ResolvedHTMLAppWebManifest].self, from: data) {
            metadata = decoded
        } else {
            metadata = [:]
        }
    }

    public func metadata(for appID: String) -> ResolvedHTMLAppWebManifest? {
        lock.withLock { metadata[appID] }
    }

    public func allMetadata() -> [String: ResolvedHTMLAppWebManifest] {
        lock.withLock { metadata }
    }

    public func replaceAll(_ replacement: [String: ResolvedHTMLAppWebManifest]) throws {
        let data = try JSONEncoder().encode(replacement)
        lock.lock()
        defer { lock.unlock() }
        storage.set(data, forKey: storageKey)
        metadata = replacement
    }

    /// 更新单个应用的呈现元数据（离线包显式更新后刷新名称/颜色/图标），
    /// 与 replaceAll 一样即时持久化。
    public func set(_ metadata: ResolvedHTMLAppWebManifest, for appID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var updated = self.metadata
        updated[appID] = metadata
        if let data = try? JSONEncoder().encode(updated) {
            storage.set(data, forKey: storageKey)
        }
        self.metadata = updated
    }
}

public enum HTMLAppWebManifestAdapterError: Error, Equatable, LocalizedError {
    case parentManifestNotTrusted
    case missingBinding
    case manifestTooLarge
    case digestMismatch
    case redirectMismatch
    case malformedManifest
    case missingName
    case invalidStartURL
    case disallowedStartURL
    case invalidScope
    case startURLOutsideScope
    case invalidIcon(String)
    case disallowedIcon(String)
    case invalidOfflineDeclaration
    case offlineDeclarationMismatch

    public var errorDescription: String? {
        switch self {
        case .parentManifestNotTrusted: return "The parent app manifest is not eligible for trusted Web Manifest adaptation"
        case .missingBinding: return "The signed parent app manifest does not bind a Web App Manifest"
        case .manifestTooLarge: return "The Web App Manifest exceeds the configured size limit"
        case .digestMismatch: return "The Web App Manifest SHA-256 does not match its signed binding"
        case .redirectMismatch: return "The Web App Manifest request redirected away from its signed URL"
        case .malformedManifest: return "The Web App Manifest is not valid JSON"
        case .missingName: return "The Web App Manifest must provide name or short_name"
        case .invalidStartURL: return "The Web App Manifest start_url is invalid"
        case .disallowedStartURL: return "The Web App Manifest start_url is outside the trusted app origins"
        case .invalidScope: return "The Web App Manifest scope is invalid"
        case .startURLOutsideScope: return "The Web App Manifest start_url is outside its scope"
        case .invalidIcon(let value): return "The Web App Manifest icon URL is invalid: \(value)"
        case .disallowedIcon(let value): return "The Web App Manifest icon URL is outside the trusted app origins: \(value)"
        case .invalidOfflineDeclaration: return "The Web App Manifest drel_offline declaration is invalid"
        case .offlineDeclarationMismatch: return "The Web App Manifest drel_offline declaration does not match the signed parent manifest"
        }
    }
}

/// Resolves standards-compatible Web App Manifest metadata only after the
/// signed parent manifest has pinned the exact URL and bytes. The parent's
/// appId and security policy remain authoritative.
public final class HTMLAppWebManifestAdapter: @unchecked Sendable {
    private let transport: HTMLAppPackageTransport
    private let maximumBytes: Int

    public init(
        transport: HTMLAppPackageTransport = URLSessionHTMLAppPackageTransport(),
        maximumBytes: Int = 262_144
    ) {
        self.transport = transport
        self.maximumBytes = maximumBytes
    }

    public func load(forTrustedParent parent: HTMLAppManifest) async throws -> ResolvedHTMLAppWebManifest {
        guard parent.validate(requiringSignature: true).isValid else {
            throw HTMLAppWebManifestAdapterError.parentManifestNotTrusted
        }
        guard let binding = parent.webManifest,
              let manifestURL = URL(string: binding.url) else {
            throw HTMLAppWebManifestAdapterError.missingBinding
        }

        let response = try await transport.data(from: manifestURL, maximumBytes: maximumBytes)
        return try resolve(
            response.data,
            finalURL: response.finalURL,
            forTrustedParent: parent
        )
    }

    /// Resolves bytes already fetched by an onboarding transport. This keeps
    /// gateway validation and direct adapter use on the exact same digest,
    /// redirect, scope, origin and `drel_offline` rules.
    public func resolve(
        _ data: Data,
        finalURL: URL,
        forTrustedParent parent: HTMLAppManifest
    ) throws -> ResolvedHTMLAppWebManifest {
        guard parent.validate(requiringSignature: true).isValid else {
            throw HTMLAppWebManifestAdapterError.parentManifestNotTrusted
        }
        guard let binding = parent.webManifest,
              let manifestURL = URL(string: binding.url) else {
            throw HTMLAppWebManifestAdapterError.missingBinding
        }
        guard data.count <= maximumBytes else {
            throw HTMLAppWebManifestAdapterError.manifestTooLarge
        }
        guard finalURL == manifestURL else {
            throw HTMLAppWebManifestAdapterError.redirectMismatch
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == binding.sha256 else {
            throw HTMLAppWebManifestAdapterError.digestMismatch
        }
        guard let webManifest = try? JSONDecoder().decode(HTMLAppWebManifest.self, from: data) else {
            throw HTMLAppWebManifestAdapterError.malformedManifest
        }

        let resolvedName = [webManifest.name, webManifest.shortName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let resolvedName else { throw HTMLAppWebManifestAdapterError.missingName }

        let startValue = webManifest.startURL ?? parent.startURL
        guard let startURL = URL(string: startValue, relativeTo: manifestURL)?.absoluteURL else {
            throw HTMLAppWebManifestAdapterError.invalidStartURL
        }
        guard parent.allows(documentURL: startURL) else {
            throw HTMLAppWebManifestAdapterError.disallowedStartURL
        }

        let defaultScope = startURL.deletingLastPathComponent().appendingPathComponent("")
        guard let scopeURL = webManifest.scope
            .flatMap({ URL(string: $0, relativeTo: manifestURL)?.absoluteURL }) ?? Optional(defaultScope),
              parent.allows(documentURL: scopeURL) else {
            throw HTMLAppWebManifestAdapterError.invalidScope
        }
        guard Self.contains(startURL, in: scopeURL) else {
            throw HTMLAppWebManifestAdapterError.startURLOutsideScope
        }

        let iconURLs = try webManifest.icons.map { icon -> URL in
            guard let url = URL(string: icon.src, relativeTo: manifestURL)?.absoluteURL else {
                throw HTMLAppWebManifestAdapterError.invalidIcon(icon.src)
            }
            guard parent.allows(documentURL: url) else {
                throw HTMLAppWebManifestAdapterError.disallowedIcon(url.absoluteString)
            }
            return url
        }

        let resolvedOffline = try webManifest.drelOffline.map { declaration -> DrelOfflinePackageDeclaration in
            guard let resourceURL = URL(
                string: declaration.resourceManifestURL,
                relativeTo: manifestURL
            )?.absoluteURL,
            parent.allows(documentURL: resourceURL),
            !declaration.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            HTMLAppCachePolicy.isValidSHA256(declaration.resourceManifestSHA256) else {
                throw HTMLAppWebManifestAdapterError.invalidOfflineDeclaration
            }
            return DrelOfflinePackageDeclaration(
                version: declaration.version,
                resourceManifestURL: resourceURL.absoluteString,
                resourceManifestSHA256: declaration.resourceManifestSHA256
            )
        }
        if let resolvedOffline, resolvedOffline != parent.drelOffline {
            throw HTMLAppWebManifestAdapterError.offlineDeclarationMismatch
        }

        return ResolvedHTMLAppWebManifest(
            appID: parent.appID,
            sourceSHA256: parent.webManifest?.sha256.lowercased(),
            name: resolvedName,
            shortName: webManifest.shortName,
            startURL: startURL,
            scopeURL: scopeURL,
            display: webManifest.display,
            themeColor: webManifest.themeColor,
            backgroundColor: webManifest.backgroundColor,
            iconURLs: iconURLs,
            drelOffline: resolvedOffline
        )
    }

    private static func contains(_ documentURL: URL, in scopeURL: URL) -> Bool {
        guard HTMLAppOrigin.canonicalOrigin(forDocumentURL: documentURL)
            == HTMLAppOrigin.canonicalOrigin(forDocumentURL: scopeURL) else { return false }
        let scopePath = scopeURL.path.hasSuffix("/") ? scopeURL.path : scopeURL.path + "/"
        return documentURL.path == scopeURL.path || documentURL.path.hasPrefix(scopePath)
    }
}

public final class URLSessionHTMLAppPackageTransport: NSObject, HTMLAppPackageTransport, @unchecked Sendable {
    private struct PendingDownload {
        let maximumBytes: Int64
        let continuation: CheckedContinuation<HTMLAppPackageTransportResponse, Error>
    }

    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private let lock = NSLock()
    private var pending: [Int: PendingDownload] = [:]

    public override init() {
        super.init()
    }

    public func data(from url: URL, maximumBytes: Int) async throws -> HTMLAppPackageTransportResponse {
        guard maximumBytes >= 0 else { throw HTMLAppOfflinePackageError.resourceManifestTooLarge }
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url)
            lock.withLock {
                pending[task.taskIdentifier] = PendingDownload(
                    maximumBytes: Int64(maximumBytes),
                    continuation: continuation
                )
            }
            task.resume()
        }
    }

    private func finish(taskID: Int, result: Result<HTMLAppPackageTransportResponse, Error>) {
        let continuation = lock.withLock { pending.removeValue(forKey: taskID)?.continuation }
        continuation?.resume(with: result)
    }
}

extension URLSessionHTMLAppPackageTransport: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let maximum = lock.withLock { pending[downloadTask.taskIdentifier]?.maximumBytes }
        if let maximum,
           totalBytesWritten > maximum || (totalBytesExpectedToWrite > maximum && totalBytesExpectedToWrite > 0) {
            downloadTask.cancel()
            finish(taskID: downloadTask.taskIdentifier, result: .failure(HTMLAppOfflinePackageError.resourceManifestTooLarge))
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            let maximum = lock.withLock { pending[downloadTask.taskIdentifier]?.maximumBytes } ?? 0
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? Int64.max
            guard size <= maximum else {
                finish(taskID: downloadTask.taskIdentifier, result: .failure(HTMLAppOfflinePackageError.resourceManifestTooLarge))
                return
            }
            guard let response = downloadTask.response,
                  let finalURL = response.url else {
                throw HTMLAppOfflinePackageError.transportFailed("missing response")
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw HTMLAppOfflinePackageError.transportFailed("HTTP \(http.statusCode)")
            }
            let data = try Data(contentsOf: location, options: .mappedIfSafe)
            finish(taskID: downloadTask.taskIdentifier, result: .success(.init(data: data, finalURL: finalURL)))
        } catch {
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let exists = lock.withLock { pending[task.taskIdentifier] != nil }
        if exists {
            finish(
                taskID: task.taskIdentifier,
                result: .failure(HTMLAppOfflinePackageError.transportFailed(error.localizedDescription))
            )
        }
    }
}

public final class HTMLAppOfflinePackageLocator: @unchecked Sendable {
    private let packagesRoot: URL
    private let fileManager: FileManager

    /// Default on-disk root for downloaded offline packages
    /// (`Application Support/WebBridgeKit/Packages`). Storage accounting
    /// surfaces read this without instantiating a locator.
    public static var defaultPackagesRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("WebBridgeKit/Packages", isDirectory: true)
    }

    public init(packagesRoot: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let packagesRoot {
            self.packagesRoot = packagesRoot
        } else {
            self.packagesRoot = Self.defaultPackagesRoot
        }
    }

    public func installedPackage(appID: String) throws -> InstalledHTMLAppPackage? {
        let appRoot = packagesRoot.appendingPathComponent(Self.stableID(appID), isDirectory: true)
        let pointer = appRoot.appendingPathComponent("current.json")
        guard fileManager.fileExists(atPath: pointer.path) else { return nil }
        do {
            let installed = try JSONDecoder().decode(InstalledHTMLAppPackage.self, from: Data(contentsOf: pointer))
            guard installed.appID == appID else { return nil }
            let packageRoot = appRoot.appendingPathComponent("versions/\(installed.directoryName)", isDirectory: true)
            let entrypoint = packageRoot.appendingPathComponent(installed.entrypoint)
            guard fileManager.fileExists(atPath: packageRoot.appendingPathComponent("package.json").path),
                  fileManager.fileExists(atPath: entrypoint.path) else { return nil }
            return installed
        } catch {
            throw HTMLAppOfflinePackageError.persistenceFailed
        }
    }

    public func entrypointURL(for package: InstalledHTMLAppPackage) throws -> URL {
        guard let current = try installedPackage(appID: package.appID), current == package else {
            throw HTMLAppOfflinePackageError.noInstalledPackage
        }
        return packageRoot(for: package).appendingPathComponent(package.entrypoint)
    }

    /// Returns the byte size of the active, validated package. The value is
    /// derived from its files instead of untrusted manifest metadata so UI can
    /// report the actual disk footprint after an atomic install.
    public func packageSize(for package: InstalledHTMLAppPackage) throws -> Int64 {
        guard let current = try installedPackage(appID: package.appID), current == package else {
            throw HTMLAppOfflinePackageError.noInstalledPackage
        }

        let root = packageRoot(for: package)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw HTMLAppOfflinePackageError.persistenceFailed
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values: URLResourceValues
            do {
                values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            } catch {
                throw HTMLAppOfflinePackageError.persistenceFailed
            }
            guard values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            let (next, overflow) = total.addingReportingOverflow(size)
            guard !overflow else { throw HTMLAppOfflinePackageError.persistenceFailed }
            total = next
        }
        return total
    }

    public func resourceURL(appID: String, path: String) throws -> URL {
        guard HTMLAppOfflinePackageInstaller.isSafeRelativePath(path),
              let package = try installedPackage(appID: appID) else {
            throw HTMLAppOfflinePackageError.noInstalledPackage
        }
        return packageRoot(for: package).appendingPathComponent(path)
    }

    /// Removes every locally retained version for one app. This is an explicit
    /// user-driven storage action: after it succeeds there is no `current`
    /// pointer, so launch resolution falls back to the network instead of
    /// serving an older package by accident.
    @discardableResult
    public func removeInstalledPackage(appID: String) throws -> Bool {
        let appRoot = packagesRoot.appendingPathComponent(Self.stableID(appID), isDirectory: true)
        guard fileManager.fileExists(atPath: appRoot.path) else { return false }
        do {
            try fileManager.removeItem(at: appRoot)
            return true
        } catch {
            throw HTMLAppOfflinePackageError.persistenceFailed
        }
    }

    private func packageRoot(for package: InstalledHTMLAppPackage) -> URL {
        packagesRoot
            .appendingPathComponent(Self.stableID(package.appID), isDirectory: true)
            .appendingPathComponent("versions/\(package.directoryName)", isDirectory: true)
    }

    private static func stableID(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public actor HTMLAppOfflinePackageInstaller {
    private let transport: HTMLAppPackageTransport
    private let packagesRoot: URL
    private let fileManager: FileManager
    private let limits: HTMLAppOfflinePackageLimits
    private let allowsLocalHTTP: Bool
    private let now: @Sendable () -> Date
    private let locator: HTMLAppOfflinePackageLocator

    public init(
        transport: HTMLAppPackageTransport = URLSessionHTMLAppPackageTransport(),
        packagesRoot: URL? = nil,
        fileManager: FileManager = .default,
        limits: HTMLAppOfflinePackageLimits = HTMLAppOfflinePackageLimits(),
        allowsLocalHTTP: Bool = false,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.fileManager = fileManager
        self.limits = limits
        self.allowsLocalHTTP = allowsLocalHTTP
        self.now = now
        if let packagesRoot {
            self.packagesRoot = packagesRoot
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.packagesRoot = appSupport.appendingPathComponent("WebBridgeKit/Packages", isDirectory: true)
        }
        self.locator = HTMLAppOfflinePackageLocator(packagesRoot: self.packagesRoot, fileManager: fileManager)
    }

    public func install(
        appManifest: HTMLAppManifest,
        progress: @Sendable (HTMLAppPackageProgress) -> Void = { _ in }
    ) async throws -> InstalledHTMLAppPackage {
        let previous = try? installedPackage(appID: appManifest.appID)
        do {
            let resourceManifestURL = try validateParentManifest(appManifest)
            progress(.downloadingManifest)
            let manifestResponse = try await transport.data(
                from: resourceManifestURL,
                maximumBytes: limits.maximumManifestBytes
            )
            try validateOrigin(manifestResponse.finalURL, against: appManifest)
            guard manifestResponse.data.count <= limits.maximumManifestBytes else {
                throw HTMLAppOfflinePackageError.resourceManifestTooLarge
            }
            guard Self.sha256(manifestResponse.data) == appManifest.effectiveOfflineCache.resourceManifestSHA256 else {
                throw HTMLAppOfflinePackageError.resourceManifestDigestMismatch
            }

            progress(.validatingManifest)
            let packageManifest: HTMLAppOfflinePackageManifest
            do {
                packageManifest = try JSONDecoder().decode(HTMLAppOfflinePackageManifest.self, from: manifestResponse.data)
            } catch {
                throw HTMLAppOfflinePackageError.invalidResourceManifest
            }
            try validate(packageManifest, against: appManifest)

            let appRoot = packagesRoot.appendingPathComponent(Self.stableID(appManifest.appID), isDirectory: true)
            let versionsRoot = appRoot.appendingPathComponent("versions", isDirectory: true)
            try createProtectedDirectory(packagesRoot)
            try createProtectedDirectory(appRoot)
            try createProtectedDirectory(versionsRoot)

            let staging = appRoot.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
            try createProtectedDirectory(staging)
            do {
                for (index, file) in packageManifest.files.enumerated() {
                    guard let remoteURL = URL(string: file.url) else {
                        throw HTMLAppOfflinePackageError.invalidURL(file.url)
                    }
                    progress(.downloadingFile(current: index + 1, total: packageManifest.files.count, path: file.path))
                    let response = try await transport.data(from: remoteURL, maximumBytes: Int(file.size))
                    try validateOrigin(response.finalURL, against: appManifest)
                    progress(.validatingFile(current: index + 1, total: packageManifest.files.count, path: file.path))
                    guard Int64(response.data.count) == file.size else {
                        throw HTMLAppOfflinePackageError.fileSizeMismatch(file.path)
                    }
                    guard Self.sha256(response.data) == file.sha256 else {
                        throw HTMLAppOfflinePackageError.fileDigestMismatch(file.path)
                    }
                    let destination = staging.appendingPathComponent(file.path, isDirectory: false)
                    try fileManager.createDirectory(
                        at: destination.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try response.data.write(to: destination, options: .atomic)
                }

                let directoryName = "\(Self.stableID(packageManifest.version))-\(String(Self.sha256(manifestResponse.data).prefix(16)))"
                let installed = InstalledHTMLAppPackage(
                    appID: packageManifest.appID,
                    version: packageManifest.version,
                    entrypoint: packageManifest.entrypoint,
                    directoryName: directoryName,
                    resourceManifestSHA256: Self.sha256(manifestResponse.data),
                    installedAt: now()
                )
                try writeMetadata(installed, to: staging.appendingPathComponent("package.json"))

                progress(.activating)
                let versionDirectory = versionsRoot.appendingPathComponent(directoryName, isDirectory: true)
                if fileManager.fileExists(atPath: versionDirectory.path) {
                    try fileManager.removeItem(at: staging)
                } else {
                    try fileManager.moveItem(at: staging, to: versionDirectory)
                }
                try writeMetadata(installed, to: appRoot.appendingPathComponent("current.json"))
                try? excludeFromBackup(appRoot)
                progress(.completed)
                return installed
            } catch {
                try? fileManager.removeItem(at: staging)
                throw error
            }
        } catch {
            if previous != nil {
                progress(.usingPreviousVersion)
            }
            throw error
        }
    }

    public func installedPackage(appID: String) throws -> InstalledHTMLAppPackage? {
        try locator.installedPackage(appID: appID)
    }

    public func entrypointURL(for package: InstalledHTMLAppPackage) throws -> URL {
        try locator.entrypointURL(for: package)
    }

    @discardableResult
    public func removeInstalledPackage(appID: String) throws -> Bool {
        try locator.removeInstalledPackage(appID: appID)
    }

    public func resourceURL(appID: String, path: String) throws -> URL {
        try locator.resourceURL(appID: appID, path: path)
    }

    private func validateParentManifest(_ manifest: HTMLAppManifest) throws -> URL {
        let cache = manifest.effectiveOfflineCache
        guard manifest.validate(requiringSignature: !allowsLocalHTTP).isValid,
              cache.strategy == .manifest,
              cache.persistent,
              let digest = cache.resourceManifestSHA256,
              HTMLAppCachePolicy.isValidSHA256(digest),
              let value = cache.resourceManifestURL,
              let url = URL(string: value) else {
            throw HTMLAppOfflinePackageError.parentManifestNotEligible
        }
        try validateOrigin(url, against: manifest)
        return url
    }

    private func validate(_ package: HTMLAppOfflinePackageManifest, against parent: HTMLAppManifest) throws {
        guard package.schemaVersion == HTMLAppOfflinePackageManifest.supportedSchemaVersion else {
            throw HTMLAppOfflinePackageError.unsupportedSchemaVersion(package.schemaVersion)
        }
        guard package.appID == parent.appID, package.version == parent.effectiveOfflineCache.version else {
            throw HTMLAppOfflinePackageError.identityMismatch
        }
        guard !package.files.isEmpty else { throw HTMLAppOfflinePackageError.emptyPackage }
        guard package.files.count <= limits.maximumFileCount else { throw HTMLAppOfflinePackageError.tooManyFiles }
        guard Self.isSafeRelativePath(package.entrypoint) else {
            throw HTMLAppOfflinePackageError.invalidPath(package.entrypoint)
        }

        var paths = Set<String>()
        var totalBytes: Int64 = 0
        for file in package.files {
            guard Self.isSafeRelativePath(file.path) else {
                throw HTMLAppOfflinePackageError.invalidPath(file.path)
            }
            guard paths.insert(file.path).inserted else {
                throw HTMLAppOfflinePackageError.duplicatePath(file.path)
            }
            for existing in paths where existing != file.path {
                if existing.hasPrefix(file.path + "/") || file.path.hasPrefix(existing + "/") {
                    throw HTMLAppOfflinePackageError.pathConflict(file.path)
                }
            }
            guard let url = URL(string: file.url) else { throw HTMLAppOfflinePackageError.invalidURL(file.url) }
            try validateOrigin(url, against: parent)
            guard HTMLAppCachePolicy.isValidSHA256(file.sha256) else {
                throw HTMLAppOfflinePackageError.invalidFileDigest(file.path)
            }
            guard file.size >= 0 else { throw HTMLAppOfflinePackageError.invalidFileSize(file.path) }
            guard file.size <= limits.maximumFileBytes, file.size <= Int64(Int.max) else {
                throw HTMLAppOfflinePackageError.fileTooLarge(file.path)
            }
            let (newTotal, overflow) = totalBytes.addingReportingOverflow(file.size)
            guard !overflow, newTotal <= limits.maximumPackageBytes else {
                throw HTMLAppOfflinePackageError.packageTooLarge
            }
            totalBytes = newTotal
        }
        guard paths.contains(package.entrypoint) else { throw HTMLAppOfflinePackageError.missingEntrypoint }
    }

    private func validateOrigin(_ url: URL, against manifest: HTMLAppManifest) throws {
        if allowsLocalHTTP,
           url.scheme?.lowercased() == "http",
           ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "") {
            return
        }
        guard url.scheme?.lowercased() == "https", manifest.allows(documentURL: url) else {
            throw HTMLAppOfflinePackageError.disallowedOrigin(url.absoluteString)
        }
    }

    private func createProtectedDirectory(_ url: URL) throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            // Some injected test FileManager/root combinations do not expose
            // URL resource metadata. Protection/persistence remains mandatory;
            // backup exclusion is best effort per filesystem.
            try? excludeFromBackup(url)
        } catch {
            throw HTMLAppOfflinePackageError.persistenceFailed
        }
    }

    private func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }

    private func writeMetadata<T: Encodable>(_ value: T, to url: URL) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            throw HTMLAppOfflinePackageError.persistenceFailed
        }
    }

    private static func stableID(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasSuffix("/"),
              !path.contains("\\"),
              !path.contains("\0") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return !parts.isEmpty && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}
