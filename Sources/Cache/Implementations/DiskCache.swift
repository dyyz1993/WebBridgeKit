import Foundation

/// Disk-based cache implementation using FileManager
public actor DiskCache: AnyCacheStorage {
    public typealias Key = String
    
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private var configuration: CacheConfiguration
    private var statistics: SystemCacheStatistics
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init(
        directoryName: String = "DiskCache",
        configuration: CacheConfiguration = .persistent
    ) throws {
        self.fileManager = FileManager.default
        self.configuration = configuration
        self.statistics = SystemCacheStatistics()
        
        // Create cache directory
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesURL.appendingPathComponent(directoryName)
        
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }
    
    public func get(for key: Key) async -> (any Codable & Sendable)? {
        let start = Date()
        defer {
            let elapsed = Date().timeIntervalSince(start)
            statistics.updateAccessTime(elapsed)
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            statistics.recordMiss()
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try decoder.decode(CacheEntryWrapper.self, from: data)
            
            // Check expiration
            if entry.metadata.isExpired {
                try? fileManager.removeItem(at: fileURL)
                statistics.recordMiss()
                return nil
            }
            
            // Update metadata
            var updatedEntry = entry
            updatedEntry.metadata.accessCount += 1
            updatedEntry.metadata.lastAccessed = Date()
            
            let updatedData = try encoder.encode(updatedEntry)
            try updatedData.write(to: fileURL)
            
            statistics.recordHit()
            return try? entry.getValue()
        } catch {
            statistics.recordMiss()
            return nil
        }
    }

    
    public func set(_ value: any Codable & Sendable, for key: Key, expiration: TimeInterval?) async {
        let expirationDate: Date?
        if let expiration = expiration {
            expirationDate = Date().addingTimeInterval(expiration)
        } else {
            expirationDate = configuration.expirationPolicy.timeInterval.map {
                Date().addingTimeInterval($0)
            }
        }
        
        let metadata = CacheMetadata(
            createdAt: Date(),
            expiration: expirationDate,
            accessCount: 0
        )
        
        do {
            let wrapper = try CacheEntryWrapper(value: value, metadata: metadata)
            let data = try encoder.encode(wrapper)
            let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
            try data.write(to: fileURL)
            
            // Evict if needed
            await evictIfNeeded()
            
            let fileCount = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path).count
            statistics.totalEntries = UInt64(fileCount ?? 0)
        } catch {
            // Log error but don't fail
        }
    }
    
    public func remove(for key: Key) async {
        let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
        try? fileManager.removeItem(at: fileURL)
        let fileCount = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path).count
        statistics.totalEntries = UInt64(fileCount ?? 0)
    }
    
    public func clearAll() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        statistics.totalEntries = 0
    }
    
    public func contains(_ key: Key) async -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try decoder.decode(CacheEntryWrapper.self, from: data)
            return !entry.metadata.isExpired
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func sanitizeKey(_ key: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return key.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    private func evictIfNeeded() async {
        guard case .sizeBased(let maxBytes) = configuration.evictionPolicy else {
            return
        }
        
        var currentSize: UInt64 = 0
        var files: [(URL, Date)] = []
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                   let fileSize = resourceValues.fileSize,
                   let modificationDate = resourceValues.contentModificationDate {
                    currentSize += UInt64(fileSize)
                    files.append((fileURL, modificationDate))
                }
            }
        }
        
        // Evict oldest files until under size limit
        files.sort { $0.1 < $1.1 }
        
        while currentSize > maxBytes && !files.isEmpty {
            let (fileURL, _) = files.removeFirst()
            if let fileSize = try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64 {
                currentSize -= fileSize
            }
            try? fileManager.removeItem(at: fileURL)
            statistics.recordEviction()
        }
        
        statistics.totalEntries = UInt64(files.count)
    }
    
    // MARK: - Statistics
    
    public func getStatistics() -> SystemCacheStatistics {
        statistics
    }
    
    public func resetStatistics() {
        statistics = SystemCacheStatistics()
    }
    
    // MARK: - Helper Types
    
    private struct CacheEntryWrapper: Codable {
        let typeName: String
        let valueData: Data
        var metadata: CacheMetadata
        
        init(value: any Codable & Sendable, metadata: CacheMetadata) throws {
            self.typeName = String(describing: type(of: value))
            self.valueData = try JSONEncoder().encode(value)
            self.metadata = metadata
        }
        
        func getValue() throws -> (any Codable & Sendable)? {
            // For simple types, decode directly
            switch typeName {
            case "String":
                return try JSONDecoder().decode(String.self, from: valueData)
            case "Int":
                return try JSONDecoder().decode(Int.self, from: valueData)
            case "Double":
                return try JSONDecoder().decode(Double.self, from: valueData)
            case "Bool":
                return try JSONDecoder().decode(Bool.self, from: valueData)
            case "Data":
                return try JSONDecoder().decode(Data.self, from: valueData)
            default:
                // For complex types, we can't decode them without knowing the actual type
                // In this case, return nil and let the caller handle it
                return nil
            }
        }
    }
}
