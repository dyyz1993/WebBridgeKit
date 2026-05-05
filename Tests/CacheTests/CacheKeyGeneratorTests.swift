import XCTest
@testable import WebBridgeKit

final class CacheKeyGeneratorTests: XCTestCase {
    
    // MARK: - Basic Generation
    
    func testGenerateFromComponents() {
        let key1 = CacheKeyGenerator.generate(from: "api", "users", "123")
        let key2 = CacheKeyGenerator.generate(from: "api", "users", "123")
        let key3 = CacheKeyGenerator.generate(from: "api", "users", "456")
        
        XCTAssertEqual(key1, key2)  // Same components should produce same key
        XCTAssertNotEqual(key1, key3)  // Different components should produce different key
    }
    
    func testGenerateFromDictionary() {
        let dict1: [String: any Sendable] = ["id": 123, "name": "John"]
        let dict2: [String: any Sendable] = ["id": 123, "name": "John"]
        let dict3: [String: any Sendable] = ["id": 456, "name": "John"]
        
        let key1 = CacheKeyGenerator.generate(from: dict1)
        let key2 = CacheKeyGenerator.generate(from: dict2)
        let key3 = CacheKeyGenerator.generate(from: dict3)
        
        XCTAssertEqual(key1, key2)  // Same dictionary should produce same key
        XCTAssertNotEqual(key1, key3)  // Different dictionary should produce different key
    }
    
    func testGenerateFromURL() {
        let url1 = URL(string: "https://api.example.com/users/123")!
        let url2 = URL(string: "https://api.example.com/users/123")!
        let url3 = URL(string: "https://api.example.com/users/456")!
        
        let key1 = CacheKeyGenerator.generate(from: url1)
        let key2 = CacheKeyGenerator.generate(from: url2)
        let key3 = CacheKeyGenerator.generate(from: url3)
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    // MARK: - Namespaced Keys
    
    func testNamespacedKey() {
        let key1 = CacheKeyGenerator.generate(namespace: "api", identifier: "users:123")
        let key2 = CacheKeyGenerator.generate(namespace: "api", identifier: "users:123")
        let key3 = CacheKeyGenerator.generate(namespace: "api", identifier: "users:456")
        let key4 = CacheKeyGenerator.generate(namespace: "image", identifier: "users:123")
        
        XCTAssertEqual(key1, "api/users:123")
        XCTAssertEqual(key2, "api/users:123")
        XCTAssertNotEqual(key1, key3)
        XCTAssertNotEqual(key1, key4)
    }
    
    // MARK: - Versioned Keys
    
    func testVersionedKey() {
        let key = CacheKeyGenerator.generate(key: "users:123", version: 1)
        XCTAssertEqual(key, "users:123:v1")
        
        let keyV2 = CacheKeyGenerator.generate(key: "users:123", version: 2)
        XCTAssertEqual(keyV2, "users:123:v2")
        
        XCTAssertNotEqual(key, keyV2)
    }
    
    // MARK: - CacheNamespace
    
    func testCacheNamespace() {
        let key1 = CacheNamespace.bridge(forKey: "handler1")
        let key2 = CacheNamespace.bridge(forKey: "handler2")
        let key3 = CacheNamespace.api(forKey: "users")
        
        XCTAssertEqual(key1, "bridge/handler1")
        XCTAssertEqual(key2, "bridge/handler2")
        XCTAssertEqual(key3, "api/users")
        
        XCTAssertNotEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    // MARK: - Consistency
    
    func testConsistency() {
        let url = URL(string: "https://api.example.com/users/123")!
        
        let key1 = CacheKeyGenerator.generate(from: url)
        let key2 = CacheKeyGenerator.generate(from: url)
        let key3 = CacheKeyGenerator.generate(from: url)
        
        // Should always produce the same key for the same input
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key2, key3)
    }
    
    // MARK: - MD5 Format
    
    func testMD5Format() {
        let key = CacheKeyGenerator.generate(from: "test")
        
        // MD5 should be 32 characters
        XCTAssertEqual(key.count, 32)
        
        // Should only contain hexadecimal characters
        let hexSet = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(key.unicodeScalars.allSatisfy { hexSet.contains($0) })
    }
}
