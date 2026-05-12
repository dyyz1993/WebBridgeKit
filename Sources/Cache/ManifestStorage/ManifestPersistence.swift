//
//  ManifestPersistence.swift
//  WebBridgeKit
//
//  Persistence layer for ManifestStore — disk I/O operations.
//

import Foundation

extension ManifestStore {

    // MARK: - Sync Load

    func loadFromDiskSync() {
        if let htmlData = try? Data(contentsOf: htmlFilePath),
           let htmlDict = try? PropertyListSerialization.propertyList(from: htmlData, options: [], format: nil) as? [String: String] {
            htmlCache = htmlDict.mapValues { CacheEntry(html: $0, timestamp: Date()) }
        }

        if let manifestData = try? Data(contentsOf: manifestFilePath),
           let manifestDict = try? PropertyListSerialization.propertyList(from: manifestData, options: [], format: nil) as? [String: [String: Any]] {
            var loaded: [String: ManifestCacheEntry] = [:]

            for (key, value) in manifestDict {
                if let resources = value["resources"] as? [String: String] {
                    var manifest = Manifest(resources: resources)

                    if let version = value["version"] as? String {
                        manifest.version = version
                    }
                    if let timestamp = value["lastUpdated"] as? TimeInterval {
                        manifest.lastUpdated = Date(timeIntervalSince1970: timestamp)
                    }
                    if let appid = value["appid"] as? String, !appid.isEmpty {
                        manifest.appid = appid
                    }
                    if let name = value["name"] as? String, !name.isEmpty {
                        manifest.name = name
                    }
                    if let icon = value["icon"] as? String, !icon.isEmpty {
                        manifest.icon = icon
                    }
                    if let isPinned = value["isPinned"] as? Bool {
                        manifest.isPinned = isPinned
                    }
                    if let isFavorite = value["isFavorite"] as? Bool {
                        manifest.isFavorite = isFavorite
                    }
                    if let lastAccessedTimestamp = value["lastAccessed"] as? TimeInterval {
                        manifest.lastAccessed = Date(timeIntervalSince1970: lastAccessedTimestamp)
                    }
                    if let accessCount = value["accessCount"] as? Int {
                        manifest.accessCount = accessCount
                    }

                    let cacheTimestamp = manifest.lastUpdated ?? Date()
                    loaded[key] = ManifestCacheEntry(manifest: manifest, timestamp: cacheTimestamp)
                }
            }

            manifestCache = loaded
        }
    }

    // MARK: - Async Load

    func loadFromDisk() {
        if let htmlData = try? Data(contentsOf: htmlFilePath),
           let htmlDict = try? PropertyListSerialization.propertyList(from: htmlData, options: [], format: nil) as? [String: String] {
            let newHtmlCache = htmlDict.mapValues { html in
                CacheEntry(html: html, timestamp: Date())
            }
            serialQueue.async { [weak self] in
                guard let self = self else { return }
                self.htmlCache = newHtmlCache
            }
        }

        if let manifestData = try? Data(contentsOf: manifestFilePath),
           let manifestDict = try? PropertyListSerialization.propertyList(from: manifestData, options: [], format: nil) as? [String: [String: Any]] {
            var loaded: [String: ManifestCacheEntry] = [:]

            for (key, value) in manifestDict {
                if let resources = value["resources"] as? [String: String] {
                    var manifest = Manifest(resources: resources)

                    if let version = value["version"] as? String {
                        manifest.version = version
                    }
                    if let timestamp = value["lastUpdated"] as? TimeInterval {
                        manifest.lastUpdated = Date(timeIntervalSince1970: timestamp)
                    }
                    if let appid = value["appid"] as? String, !appid.isEmpty {
                        manifest.appid = appid
                    }
                    if let name = value["name"] as? String, !name.isEmpty {
                        manifest.name = name
                    }
                    if let icon = value["icon"] as? String, !icon.isEmpty {
                        manifest.icon = icon
                    }
                    if let isPinned = value["isPinned"] as? Bool {
                        manifest.isPinned = isPinned
                    }
                    if let isFavorite = value["isFavorite"] as? Bool {
                        manifest.isFavorite = isFavorite
                    }
                    if let lastAccessedTimestamp = value["lastAccessed"] as? TimeInterval {
                        manifest.lastAccessed = Date(timeIntervalSince1970: lastAccessedTimestamp)
                    }
                    if let accessCount = value["accessCount"] as? Int {
                        manifest.accessCount = accessCount
                    }

                    let cacheTimestamp = manifest.lastUpdated ?? Date()
                    loaded[key] = ManifestCacheEntry(manifest: manifest, timestamp: cacheTimestamp)
                }
            }

            serialQueue.async { [weak self] in
                guard let self = self else { return }
                self.manifestCache = loaded
            }
        }

        let htmlCount = serialQueue.sync { htmlCache.count }
        let manifestCount = serialQueue.sync { manifestCache.count }
        Log.info("Loaded from disk: \(htmlCount) HTMLs, \(manifestCount) manifests", category: .manifest)
    }

    // MARK: - Async Save (Scheduled)

    func scheduleAsyncSave() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let htmlCopy: [String: String]
            let manifestDictCopy: [String: [String: Any]]

            htmlCopy = self.serialQueue.sync {
                return self.htmlCache.mapValues { $0.html }
            }

            manifestDictCopy = self.serialQueue.sync {
                var dict: [String: [String: Any]] = [:]
                for (key, entry) in self.manifestCache {
                    let manifest = entry.manifest
                    var manifestDict: [String: Any] = [
                        "resources": manifest.resources,
                        "appid": manifest.appid ?? "",
                        "name": manifest.name ?? "",
                        "icon": manifest.icon ?? "",
                        "isPinned": manifest.isPinned ?? false,
                        "isFavorite": manifest.isFavorite ?? false,
                        "accessCount": manifest.accessCount ?? 0
                    ]
                    if let version = manifest.version {
                        manifestDict["version"] = version
                    }
                    if let lastUpdated = manifest.lastUpdated {
                        manifestDict["lastUpdated"] = lastUpdated.timeIntervalSince1970
                    }
                    if let lastAccessed = manifest.lastAccessed {
                        manifestDict["lastAccessed"] = lastAccessed.timeIntervalSince1970
                    }
                    dict[key] = manifestDict
                }
                return dict
            }

            if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCopy, format: .xml, options: 0) {
                try? htmlData.write(to: self.htmlFilePath)
            }

            if let manifestData = try? PropertyListSerialization.data(fromPropertyList: manifestDictCopy, format: .xml, options: 0) {
                try? manifestData.write(to: self.manifestFilePath)
            }
        }
    }

    // MARK: - Sync Save

    func saveToDisk() {
        let htmlCopy = serialQueue.sync {
            return htmlCache.mapValues { $0.html }
        }

        if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCopy, format: .xml, options: 0) {
            try? htmlData.write(to: htmlFilePath)
        }

        let manifestCopy = serialQueue.sync {
            var dict: [String: [String: Any]] = [:]
            for (key, entry) in manifestCache {
                let manifest = entry.manifest
                var manifestDict: [String: Any] = [
                    "resources": manifest.resources,
                    "appid": manifest.appid ?? "",
                    "name": manifest.name ?? "",
                    "icon": manifest.icon ?? "",
                    "isPinned": manifest.isPinned ?? false,
                    "isFavorite": manifest.isFavorite ?? false,
                    "accessCount": manifest.accessCount ?? 0
                ]

                if let version = manifest.version {
                    manifestDict["version"] = version
                }

                if let lastUpdated = manifest.lastUpdated {
                    manifestDict["lastUpdated"] = lastUpdated.timeIntervalSince1970
                }

                if let lastAccessed = manifest.lastAccessed {
                    manifestDict["lastAccessed"] = lastAccessed.timeIntervalSince1970
                }

                dict[key] = manifestDict
            }
            return dict
        }

        if let manifestData = try? PropertyListSerialization.data(fromPropertyList: manifestCopy, format: .xml, options: 0) {
            try? manifestData.write(to: manifestFilePath)
        }
    }

    public func saveToDiskSync() {
        let htmlCopy = htmlCache.mapValues { $0.html }

        if let htmlData = try? PropertyListSerialization.data(fromPropertyList: htmlCopy, format: .xml, options: 0) {
            try? htmlData.write(to: htmlFilePath)
        }

        var dict: [String: [String: Any]] = [:]
        for (key, entry) in manifestCache {
            let manifest = entry.manifest
            var manifestDict: [String: Any] = [
                "resources": manifest.resources,
                "appid": manifest.appid ?? "",
                "name": manifest.name ?? "",
                "icon": manifest.icon ?? "",
                "isPinned": manifest.isPinned ?? false,
                "isFavorite": manifest.isFavorite ?? false,
                "accessCount": manifest.accessCount ?? 0
            ]
            if let version = manifest.version {
                manifestDict["version"] = version
            }
            if let lastUpdated = manifest.lastUpdated {
                manifestDict["lastUpdated"] = lastUpdated.timeIntervalSince1970
            }
            if let lastAccessed = manifest.lastAccessed {
                manifestDict["lastAccessed"] = lastAccessed.timeIntervalSince1970
            }
            dict[key] = manifestDict
        }

        if let manifestData = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
            try? manifestData.write(to: manifestFilePath)
        }
    }
}
