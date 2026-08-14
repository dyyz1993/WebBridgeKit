//
//  HTMLAppLaunchRuntime.swift
//  WebBridgeKit
//

import CryptoKit
import Foundation

public enum HTMLAppLaunchSource: String, Codable, Equatable, Sendable {
    case direct
    case notification
    case restore
}

public enum HTMLAppOfflineMode: String, Codable, Equatable, Sendable {
    case networkOnly
    case partial
    case strong
}

public struct HTMLAppLaunchContext: Codable, Equatable, Sendable {
    public let appID: String
    public let route: String
    public let parameters: [String: String]
    public let source: HTMLAppLaunchSource

    public init(
        appID: String,
        route: String,
        parameters: [String: String] = [:],
        source: HTMLAppLaunchSource
    ) {
        self.appID = appID
        self.route = route
        self.parameters = parameters
        self.source = source
    }

    public var bridgePayload: [String: String] {
        var payload = parameters
        payload["webbridgekitAppId"] = appID
        payload["webbridgekitRoute"] = route
        payload["webbridgekitSource"] = source.rawValue
        return payload
    }
}

public struct HTMLAppLaunchTarget: Equatable, Sendable {
    public let manifest: HTMLAppManifest
    public let pageURL: URL
    public let resourceManifestURL: URL?
    public let installedPackageURL: URL?
    public let offlineMode: HTMLAppOfflineMode
    public let context: HTMLAppLaunchContext

    public init(
        manifest: HTMLAppManifest,
        pageURL: URL,
        resourceManifestURL: URL?,
        installedPackageURL: URL? = nil,
        offlineMode: HTMLAppOfflineMode,
        context: HTMLAppLaunchContext
    ) {
        self.manifest = manifest
        self.pageURL = pageURL
        self.resourceManifestURL = resourceManifestURL
        self.installedPackageURL = installedPackageURL
        self.offlineMode = offlineMode
        self.context = context
    }

    public var loaderURL: URL {
        installedPackageURL ?? resourceManifestURL ?? pageURL
    }
}

public enum HTMLAppLaunchError: Error, Equatable, LocalizedError {
    case appNotRegistered(String)
    case invalidEnvelope
    case invalidStartURL
    case invalidResourceManifestURL

    public var errorDescription: String? {
        switch self {
        case .appNotRegistered(let appID): return "HTML app is not registered: \(appID)"
        case .invalidEnvelope: return "HTML app launch route is invalid or expired"
        case .invalidStartURL: return "HTML app start URL is invalid"
        case .invalidResourceManifestURL: return "HTML app resource manifest URL is invalid"
        }
    }
}

public final class HTMLAppLaunchResolver {
    private let trustRegistry: HTMLAppTrustRegistry
    private let packageLocator: HTMLAppOfflinePackageLocator

    public init(
        trustRegistry: HTMLAppTrustRegistry = HTMLAppTrustRegistry(),
        packageLocator: HTMLAppOfflinePackageLocator = HTMLAppOfflinePackageLocator()
    ) {
        self.trustRegistry = trustRegistry
        self.packageLocator = packageLocator
    }

    public func resolve(
        envelope: HTMLAppPushEnvelope,
        source: HTMLAppLaunchSource = .notification,
        now: Date = Date()
    ) throws -> HTMLAppLaunchTarget {
        guard let manifest = trustRegistry.manifest(for: envelope.appID) else {
            throw HTMLAppLaunchError.appNotRegistered(envelope.appID)
        }
        guard envelope.isValid(for: manifest, now: now) else {
            throw HTMLAppLaunchError.invalidEnvelope
        }
        return try resolve(
            manifest: manifest,
            route: envelope.route,
            parameters: envelope.parameters,
            source: source
        )
    }

    public func resolve(
        appID: String,
        route: String,
        parameters: [String: String] = [:],
        source: HTMLAppLaunchSource = .direct
    ) throws -> HTMLAppLaunchTarget {
        guard let manifest = trustRegistry.manifest(for: appID) else {
            throw HTMLAppLaunchError.appNotRegistered(appID)
        }
        guard manifest.allows(route: route) else {
            throw HTMLAppLaunchError.invalidEnvelope
        }
        return try resolve(manifest: manifest, route: route, parameters: parameters, source: source)
    }

    private func resolve(
        manifest: HTMLAppManifest,
        route: String,
        parameters: [String: String],
        source: HTMLAppLaunchSource
    ) throws -> HTMLAppLaunchTarget {
        guard let startURL = URL(string: manifest.startURL),
              var components = URLComponents(url: startURL, resolvingAgainstBaseURL: false) else {
            throw HTMLAppLaunchError.invalidStartURL
        }
        components.path = route
        // Keep the document URL stable so one cached shell can handle many
        // notification payloads. Dynamic values are delivered through the
        // launch context instead of leaking into URL history/cache keys.
        guard let pageURL = components.url, manifest.allows(documentURL: pageURL) else {
            throw HTMLAppLaunchError.invalidStartURL
        }

        let resourceManifestURL: URL?
        if let value = manifest.cache.resourceManifestURL {
            guard let url = URL(string: value), manifest.allows(documentURL: url) else {
                throw HTMLAppLaunchError.invalidResourceManifestURL
            }
            resourceManifestURL = url
        } else {
            resourceManifestURL = nil
        }

        let offlineMode: HTMLAppOfflineMode
        var installedPackageURL: URL?
        if manifest.cache.strategy == .networkOnly {
            offlineMode = .networkOnly
        } else if manifest.cache.isStrongOfflineEligible,
                  let package = try? packageLocator.installedPackage(appID: manifest.appID),
                  package.version == manifest.cache.version,
                  package.resourceManifestSHA256 == manifest.cache.resourceManifestSHA256,
                  let entrypoint = try? packageLocator.entrypointURL(for: package) {
            offlineMode = .strong
            installedPackageURL = entrypoint
        } else {
            offlineMode = .partial
        }

        return HTMLAppLaunchTarget(
            manifest: manifest,
            pageURL: pageURL,
            resourceManifestURL: resourceManifestURL,
            installedPackageURL: installedPackageURL,
            offlineMode: offlineMode,
            context: HTMLAppLaunchContext(
                appID: manifest.appID,
                route: route,
                parameters: parameters,
                source: source
            )
        )
    }
}

public struct HTMLAppStateSnapshot: Codable, Equatable, Sendable {
    public let appID: String
    public let route: String
    public let payload: Data
    public let updatedAt: Date

    public init(appID: String, route: String, payload: Data, updatedAt: Date = Date()) {
        self.appID = appID
        self.route = route
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

public enum HTMLAppStateSnapshotError: Error, Equatable, LocalizedError {
    case invalidJSON
    case snapshotTooLarge
    case persistenceFailed

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: return "HTML app state snapshot must contain valid JSON"
        case .snapshotTooLarge: return "HTML app state snapshot exceeds the size limit"
        case .persistenceFailed: return "Unable to persist HTML app state snapshot"
        }
    }
}

public final class HTMLAppStateSnapshotStore {
    public static let maximumSnapshotSize = 10 * 1_024 * 1_024

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.rootDirectory = appSupport.appendingPathComponent("WebBridgeKit/AppState", isDirectory: true)
        }
    }

    public func save(
        appID: String,
        route: String,
        jsonData: Data,
        updatedAt: Date = Date()
    ) throws -> HTMLAppStateSnapshot {
        guard jsonData.count <= Self.maximumSnapshotSize else {
            throw HTMLAppStateSnapshotError.snapshotTooLarge
        }
        guard (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
            throw HTMLAppStateSnapshotError.invalidJSON
        }
        let snapshot = HTMLAppStateSnapshot(appID: appID, route: route, payload: jsonData, updatedAt: updatedAt)

        lock.lock()
        defer { lock.unlock() }
        do {
            let directory = directoryURL(for: appID)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableDirectory = directory
            try? mutableDirectory.setResourceValues(values)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: directory.appendingPathComponent("snapshot.json"), options: .atomic)
            return snapshot
        } catch {
            throw HTMLAppStateSnapshotError.persistenceFailed
        }
    }

    public func snapshot(for appID: String) -> HTMLAppStateSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        let url = directoryURL(for: appID).appendingPathComponent("snapshot.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HTMLAppStateSnapshot.self, from: data)
    }

    public func clear(appID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let directory = directoryURL(for: appID)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            try fileManager.removeItem(at: directory)
        } catch {
            throw HTMLAppStateSnapshotError.persistenceFailed
        }
    }

    private func directoryURL(for appID: String) -> URL {
        let digest = SHA256.hash(data: Data(appID.utf8)).map { String(format: "%02x", $0) }.joined()
        return rootDirectory.appendingPathComponent(digest, isDirectory: true)
    }
}
