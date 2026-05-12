//
//  ResourceCacheSpace.swift
//  WebBridgeKit
//
//  Split from WebResourceCacheManager.swift
//

import Foundation
import RealmSwift

extension WebResourceCacheManager {

    func getRealm() -> Realm? {
        return try? Realm(configuration: realmConfiguration)
    }

    func setupStats() {
        let realm = getRealm()
        if realm?.object(ofType: WebCacheStatistics.self, forPrimaryKey: "global") == nil {
            try? realm?.write {
                let stats = WebCacheStatistics()
                stats.domain = "global"
                realm?.add(stats)
            }
        }
    }

    func setupCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheBaseDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheBaseDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ [WebResourceCacheManager] Created cache directory")
            } catch {
                print("❌ [WebResourceCacheManager] Failed to create cache directory: \(error.localizedDescription)")
            }
        }
    }

    func loadCacheIndex() {
        guard fileManager.fileExists(atPath: cacheIndexFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: cacheIndexFile)
            if let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] {
                mapLock.lock()
                urlToCacheIDMap = dict
                mapLock.unlock()
                print("✅ [WebResourceCacheManager] Loaded cache index: \(dict.count) entries")
            }
        } catch {
            print("❌ [WebResourceCacheManager] Failed to load cache index: \(error.localizedDescription)")
        }
    }

    func saveCacheIndex() {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                self.mapLock.lock()
                let mapCopy = self.urlToCacheIDMap
                self.mapLock.unlock()

                let data = try PropertyListSerialization.data(fromPropertyList: mapCopy, format: .xml, options: 0)
                try data.write(to: self.cacheIndexFile)
            } catch {
                print("❌ [WebResourceCacheManager] Failed to save cache index: \(error.localizedDescription)")
            }
        }
    }

    func updateAccessTime(for cacheID: String) {
        accessLock.lock()
        defer { accessLock.unlock() }
        cacheAccessTimes[cacheID] = Date()
    }

    func updateTotalCacheSize() {
        queue.async { [weak self] in
            guard let self = self else { return }

            var total: Int64 = 0

            if let enumerator = self.fileManager.enumerator(at: self.cacheBaseDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        total += Int64(fileSize)
                    }
                }
            }

            self.sizeLock.lock()
            self.totalCacheSize = total
            self.sizeLock.unlock()

            print("📊 [WebResourceCacheManager] Total cache size: \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
        }
    }

    public func createCacheSpace(for url: URL) -> String {
        mapLock.lock()
        defer { mapLock.unlock() }

        let urlString = url.absoluteString
        if let existingID = urlToCacheIDMap[urlString] {
            updateAccessTime(for: existingID)
            print("♻️ [WebResourceCacheManager] Reusing existing cache space: \(existingID)")
            return existingID
        }

        let cacheID = UUID().uuidString

        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)", isDirectory: true)
        let resourcesDirectory = cacheDirectory.appendingPathComponent("resources", isDirectory: true)

        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true, attributes: nil)

            urlToCacheIDMap[urlString] = cacheID
            cacheAccessTimes[cacheID] = Date()
            saveCacheIndex()

            print("✅ [WebResourceCacheManager] Created cache space")
            print("   - Cache ID: \(cacheID)")
            print("   - URL: \(urlString)")
            print("   - Directory: \(cacheDirectory.path)")

            return cacheID
        } catch {
            print("❌ [WebResourceCacheManager] Failed to create cache space: \(error.localizedDescription)")
            return cacheID
        }
    }

    public func getCacheID(for url: URL) -> String? {
        mapLock.lock()
        defer { mapLock.unlock() }

        let urlString = url.absoluteString
        let cacheID = urlToCacheIDMap[urlString]

        if let cacheID = cacheID {
            updateAccessTime(for: cacheID)
        }

        return cacheID
    }

    public func getURL(for cacheID: String) -> URL? {
        mapLock.lock()
        defer { mapLock.unlock() }

        if let urlString = urlToCacheIDMap.first(where: { $1 == cacheID })?.key {
            return URL(string: urlString)
        }
        return nil
    }

    public func removeCacheSpace(cacheID: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.mapLock.lock()
            defer { self.mapLock.unlock() }

            if let urlString = self.urlToCacheIDMap.first(where: { $1 == cacheID })?.key {
                self.urlToCacheIDMap.removeValue(forKey: urlString)
            }

            self.cacheAccessTimes.removeValue(forKey: cacheID)

            let cacheDirectory = self.cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")

            do {
                try self.fileManager.removeItem(at: cacheDirectory)
                self.saveCacheIndex()
                self.updateTotalCacheSize()

                print("🗑️ [WebResourceCacheManager] Removed cache space: \(cacheID)")
            } catch {
                print("❌ [WebResourceCacheManager] Failed to remove cache space: \(error.localizedDescription)")
            }
        }
    }

    public func cacheSpaceExists(cacheID: String) -> Bool {
        mapLock.lock()
        defer { mapLock.unlock() }

        let cacheDirectory = cacheBaseDirectory.appendingPathComponent("cache-\(cacheID)")
        return fileManager.fileExists(atPath: cacheDirectory.path)
    }
}
