//
//  HTMLAppOfflinePackageInstaller.swift
//  WebBridgeKit
//

import CryptoKit
import Foundation

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

    public init(packagesRoot: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let packagesRoot {
            self.packagesRoot = packagesRoot
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.packagesRoot = appSupport.appendingPathComponent("WebBridgeKit/Packages", isDirectory: true)
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

    public func resourceURL(appID: String, path: String) throws -> URL {
        guard HTMLAppOfflinePackageInstaller.isSafeRelativePath(path),
              let package = try installedPackage(appID: appID) else {
            throw HTMLAppOfflinePackageError.noInstalledPackage
        }
        return packageRoot(for: package).appendingPathComponent(path)
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
        now: @escaping @Sendable () -> Date = Date.init
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
            guard Self.sha256(manifestResponse.data) == appManifest.cache.resourceManifestSHA256 else {
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

    public func resourceURL(appID: String, path: String) throws -> URL {
        try locator.resourceURL(appID: appID, path: path)
    }

    private func validateParentManifest(_ manifest: HTMLAppManifest) throws -> URL {
        guard manifest.validate(requiringSignature: !allowsLocalHTTP).isValid,
              manifest.cache.strategy == .manifest,
              manifest.cache.persistent,
              let digest = manifest.cache.resourceManifestSHA256,
              HTMLAppCachePolicy.isValidSHA256(digest),
              let value = manifest.cache.resourceManifestURL,
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
        guard package.appID == parent.appID, package.version == parent.cache.version else {
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
