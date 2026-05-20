//
//  ResourceStore.swift
//  WebBridgeKit
//
//  Split from WebResourceCacheManager.swift
//

import Foundation

extension WebResourceCacheManager {

    public func storeResource(
        cacheID: String,
        relativePath: String,
        data: Data,
        mimeType: String
    ) throws {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            throw CacheError.cacheSpaceNotFound(cacheID)
        }

        let resourcePath = cacheDirectory.appendingPathComponent(relativePath)

        let parentDirectory = resourcePath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDirectory.path) {
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        }

        try data.write(to: resourcePath)

        sizeLock.lock()
        totalCacheSize += Int64(data.count)
        sizeLock.unlock()

        updateManifestForResource(cacheID: cacheID, relativePath: relativePath, data: data, mimeType: mimeType)

        StructuredLogger.shared.debug("💾 [WebResourceCacheManager] Stored resource", category: .cache)
        StructuredLogger.shared.debug("   - Cache ID: \(cacheID)", category: .cache)
        StructuredLogger.shared.debug("   - Path: \(relativePath)", category: .cache)
        StructuredLogger.shared.debug("   - Size: \(data.count) bytes", category: .cache)
    }

    public func getResource(cacheID: String, relativePath: String) -> (data: Data, mimeType: String)? {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return nil
        }

        let resourcePath = cacheDirectory.appendingPathComponent(relativePath)

        guard fileManager.fileExists(atPath: resourcePath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: resourcePath)

            var mimeType = "application/octet-stream"
            if let manifest = loadManifest(for: cacheID),
               let resourceInfo = manifest.resources[relativePath] {
                mimeType = resourceInfo.mimeType
            }

            updateAccessTime(for: cacheID)

            return (data, mimeType)
        } catch {
            StructuredLogger.shared.error("❌ [WebResourceCacheManager] Failed to read resource: \(error.localizedDescription)", category: .cache)
            return nil
        }
    }

    public func removeResource(cacheID: String, relativePath: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let cacheDirectory = self.cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
            let resourcePath = cacheDirectory.appendingPathComponent(relativePath)

            do {
                if self.fileManager.fileExists(atPath: resourcePath.path) {
                    let attributes = try self.fileManager.attributesOfItem(atPath: resourcePath.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        self.sizeLock.lock()
                        self.totalCacheSize -= fileSize
                        self.sizeLock.unlock()
                    }

                    try self.fileManager.removeItem(at: resourcePath)
                    StructuredLogger.shared.debug("🗑️ [WebResourceCacheManager] Removed resource: \(relativePath)", category: .cache)
                }
            } catch {
                StructuredLogger.shared.error("❌ [WebResourceCacheManager] Failed to remove resource: \(error.localizedDescription)", category: .cache)
            }
        }
    }

    public func saveManifest(cacheID: String, manifest: WebResourceManifest) {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
        let manifestPath = cacheDirectory.appendingPathComponent("manifest.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: manifestPath)

            StructuredLogger.shared.debug("💾 [WebResourceCacheManager] Saved manifest for: \(cacheID)", category: .cache)
        } catch {
            StructuredLogger.shared.error("❌ [WebResourceCacheManager] Failed to save manifest: \(error.localizedDescription)", category: .cache)
        }
    }

    public func loadManifest(for cacheID: String) -> WebResourceManifest? {
        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
        let manifestPath = cacheDirectory.appendingPathComponent("manifest.json")

        guard fileManager.fileExists(atPath: manifestPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestPath)
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(WebResourceManifest.self, from: data)
            return manifest
        } catch {
            StructuredLogger.shared.error("❌ [WebResourceCacheManager] Failed to load manifest: \(error.localizedDescription)", category: .cache)
            return nil
        }
    }

    func updateManifestForResource(cacheID: String, relativePath: String, data: Data, mimeType: String) {
        var manifest = loadManifest(for: cacheID)

        if manifest == nil {
            if let url = getURL(for: cacheID) {
                manifest = WebResourceManifest(
                    url: url.absoluteString,
                    htmlContent: "",
                    resources: [:]
                )
            }
        }

        guard var manifest = manifest else { return }

        let resourceInfo = ResourceInfo(
            relativePath: relativePath,
            originalURL: relativePath,
            mimeType: mimeType,
            fileSize: data.count
        )

        manifest.resources[relativePath] = resourceInfo
        manifest.lastAccessedAt = Date()

        saveManifest(cacheID: cacheID, manifest: manifest)
    }
}
