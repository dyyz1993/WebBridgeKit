import XCTest
@testable import WebBridgeKit

final class ManifestExtensionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // 清理缓存以确保测试环境干净
        ManifestStore.shared.clearAll()
    }
    
    /// 测试 Manifest 扩展字段的持久化
    func testManifestExtensionPersistence() {
        let appID = "test.app.id"
        let lastAccessedDate = Date()
        
        var manifest = Manifest(
            resources: ["index.html": "http://example.com/index.html"],
            version: "1.0.0",
            appid: appID,
            name: "Test App",
            icon: "test_icon",
            isPinned: true,
            isFavorite: true,
            lastAccessed: lastAccessedDate,
            accessCount: 5
        )
        
        // 1. 保存到 Store
        ManifestStore.shared.saveManifest(manifest, for: appID)
        
        // 2. 从 Store 读取
        guard let savedManifest = ManifestStore.shared.getManifest(for: appID) else {
            XCTFail("Failed to retrieve manifest from store")
            return
        }
        
        // 3. 验证字段
        XCTAssertEqual(savedManifest.appid, appID)
        XCTAssertEqual(savedManifest.name, "Test App")
        XCTAssertEqual(savedManifest.icon, "test_icon")
        XCTAssertEqual(savedManifest.isPinned, true)
        XCTAssertEqual(savedManifest.isFavorite, true)
        XCTAssertEqual(savedManifest.accessCount, 5)
        
        // 验证日期（考虑到精度损失，比较 TimeInterval）
        XCTAssertEqual(savedManifest.lastAccessed?.timeIntervalSince1970 ?? 0, lastAccessedDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    /// 测试默认值
    func testManifestExtensionDefaults() {
        let appID = "test.defaults"
        let manifest = Manifest(resources: [:])
        
        XCTAssertEqual(manifest.isPinned, false)
        XCTAssertEqual(manifest.isFavorite, false)
        XCTAssertEqual(manifest.accessCount, 0)
        XCTAssertNil(manifest.lastAccessed)
    }
}
