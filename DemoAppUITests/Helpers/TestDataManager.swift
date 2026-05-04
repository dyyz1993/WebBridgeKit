import Foundation
@testable import WebBridgeKit

/// 测试数据管理器
/// 使用 Mock 服务为测试提供数据
class TestDataManager {
    static let shared = TestDataManager()
    private init() {}

    // MARK: - 服务配置

    /// 配置 Mock 服务模式
    /// - Parameter useInMemoryRealm: 是否使用 Realm 内存数据库
    func setupMockServices(useInMemoryRealm: Bool = false) {
        ServiceLocator.shared.setupMockServices(useInMemoryRealm: useInMemoryRealm)
    }

    /// 重置服务到生产模式
    func resetServices() {
        ServiceLocator.shared.reset()
    }

    // MARK: - Mock 数据准备

    /// 准备 Mock 历史记录数据
    /// - Parameter urls: 要添加的 URL 数组
    func prepareMockHistoryData(urls: [String] = [
        "https://example.com",
        "https://github.com",
        "https://stackoverflow.com",
        "https://developer.apple.com",
        "https://reddit.com"
    ]) {
        guard let historyService = ServiceLocator.shared.historyService as? MockHistoryService else {
            fatalError("HistoryService is not a MockHistoryService. Call setupMockServices() first.")
        }

        let titles = urls.map { "Test: \($0)" }
        historyService.addMockData(urls: urls, titles: titles)
    }

    /// 准备 Mock 收藏数据
    /// - Parameter urls: 要添加的 URL 数组
    func prepareMockFavoriteData(urls: [String] = [
        "https://apple.com",
        "https://google.com",
        "https://microsoft.com"
    ]) {
        guard let favoriteService = ServiceLocator.shared.favoriteService as? MockFavoriteService else {
            fatalError("FavoriteService is not a MockFavoriteService. Call setupMockServices() first.")
        }

        let titles = urls.map { URL(string: $0)?.host }
        for (index, url) in urls.enumerated() {
            if let url = URL(string: url) {
                favoriteService.addFavorite(url: url, title: titles[index], favicon: nil)
            }
        }
    }

    /// 准备完整的 Mock 数据
    func prepareMockData() {
        setupMockServices()
        prepareMockHistoryData()
        prepareMockFavoriteData()
    }

    // MARK: - 数据清理

    /// 清空所有 Mock 数据
    func cleanupTestData() {
        guard let historyService = ServiceLocator.shared.historyService as? MockHistoryService,
              let favoriteService = ServiceLocator.shared.favoriteService as? MockFavoriteService else {
            fatalError("Services are not Mock services. Call setupMockServices() first.")
        }

        historyService.clearMockData()
        favoriteService.clearMockData()
    }
}
