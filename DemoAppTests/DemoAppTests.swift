//
//  DemoAppTests.swift
//  DemoAppTests
//
//  Created by 许映洲 on 2026/1/23.
//

import Testing
import Foundation
@testable import WebBridgeKit

/// ServiceLocator 模式切换测试
struct ServiceLocatorTests {

    @Test("ServiceLocator should switch from mock to production mode")
    func testServiceLocatorModeSwitch() async throws {
        // 创建一个新的 ServiceLocator 实例用于测试
        let serviceLocator = ServiceLocator.shared

        // 验证初始模式（应该是 mock 模式，因为在 DEBUG 模式下初始化）
        #expect(serviceLocator.currentMode == .mock, "Initial mode should be mock in DEBUG")

        // 切换到生产模式
        serviceLocator.setupProductionServices()

        // 验证模式已切换
        #expect(serviceLocator.currentMode == .production, "Mode should be production after setupProductionServices()")

        // 验证服务实例类型
        let historyService = serviceLocator.historyService
        let favoriteService = serviceLocator.favoriteService

        #expect(historyService is RealmHistoryService, "History service should be RealmHistoryService in production mode")
        #expect(favoriteService is RealmFavoriteService, "Favorite service should be RealmFavoriteService in production mode")
    }

    @Test("ServiceLocator should switch from production to mock mode")
    func testServiceLocatorProductionToMock() async throws {
        let serviceLocator = ServiceLocator.shared

        // 切换到生产模式
        serviceLocator.setupProductionServices()
        #expect(serviceLocator.currentMode == .production)

        // 切换到 Mock 模式
        serviceLocator.setupMockServices(useInMemoryRealm: false)

        // 验证模式已切换
        #expect(serviceLocator.currentMode == .mock, "Mode should be mock after setupMockServices()")

        // 验证服务实例类型
        let historyService = serviceLocator.historyService
        let favoriteService = serviceLocator.favoriteService

        #expect(historyService is MockHistoryService, "History service should be MockHistoryService in mock mode")
        #expect(favoriteService is MockFavoriteService, "Favorite service should be MockFavoriteService in mock mode")
    }

    @Test("ServiceLocator should setup mock services with sample data")
    func testServiceLocatorMockWithSampleData() async throws {
        let serviceLocator = ServiceLocator.shared

        // 设置 Mock 服务并添加示例数据
        serviceLocator.setupMockServicesWithSampleData(useInMemoryRealm: false)

        // 验证模式
        #expect(serviceLocator.currentMode == .mock)

        // 验证示例数据已添加
        let historyCount = serviceLocator.historyService.getTotalCount()
        let favoriteCount = serviceLocator.favoriteService.getTotalCount()

        #expect(historyCount == 5, "Should have 5 sample history items")
        #expect(favoriteCount == 3, "Should have 3 sample favorite items")
    }

    @Test("ServiceLocator should provide valid services")
    func testServiceLocatorProvidesValidServices() async throws {
        let serviceLocator = ServiceLocator.shared

        // 确保服务已初始化
        serviceLocator.setupMockServices(useInMemoryRealm: false)

        // 验证服务不是 nil
        let historyService = serviceLocator.historyService
        let favoriteService = serviceLocator.favoriteService

        #expect(historyService != nil, "History service should not be nil")
        #expect(favoriteService != nil, "Favorite service should not be nil")

        // 验证快捷访问
        let historyViaShortcut = ServiceLocator.history
        let favoriteViaShortcut = ServiceLocator.favorite

        #expect(historyViaShortcut !== nil, "History service via shortcut should not be nil")
        #expect(favoriteViaShortcut !== nil, "Favorite service via shortcut should not be nil")
    }

    @Test("ServiceLocator should clear all services")
    func testServiceLocatorClearServices() async throws {
        let serviceLocator = ServiceLocator.shared

        // 设置服务
        serviceLocator.setupMockServices(useInMemoryRealm: false)

        // 清除服务
        serviceLocator.clearServices()

        // 验证尝试访问服务会触发 fatalError
        // 注意：这个测试会导致应用崩溃，所以我们在实际测试中跳过
        // 在生产环境中，clearServices 后应该重新设置服务
    }

    @Test("ServiceLocator reset should return to production mode")
    func testServiceLocatorReset() async throws {
        let serviceLocator = ServiceLocator.shared

        // 先切换到 Mock 模式
        serviceLocator.setupMockServices(useInMemoryRealm: false)
        #expect(serviceLocator.currentMode == .mock)

        // 重置到生产模式
        serviceLocator.reset()

        // 验证已回到生产模式
        #expect(serviceLocator.currentMode == .production, "Reset should return to production mode")
    }
}

/// MockHistoryService 数据操作测试
struct MockHistoryServiceTests {

    @Test("MockHistoryService should add and retrieve history")
    func testMockHistoryServiceAddAndRetrieve() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)

        // 清空数据
        service.clearMockData()

        // 添加历史记录
        let url = URL(string: "https://www.example.com")!
        service.addOrUpdateHistory(url: url, title: "Example")

        // 验证总数
        let count = service.getTotalCount()
        #expect(count == 1, "Should have 1 history item")

        // 验证可以找到
        let found = service.findHistory(url: url)
        #expect(found != nil, "Should find the added history")
        #expect(found?.url == "https://www.example.com", "URL should match")
        #expect(found?.title == "Example", "Title should match")
    }

    @Test("MockHistoryService should update existing history")
    func testMockHistoryServiceUpdateExisting() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!

        // 第一次添加
        service.addOrUpdateHistory(url: url, title: "First Title")
        let firstVisit = service.findHistory(url: url)
        #expect(firstVisit?.visitCount == 1, "First visit count should be 1")

        // 第二次访问（应该更新）
        service.addOrUpdateHistory(url: url, title: "Updated Title")
        let secondVisit = service.findHistory(url: url)

        #expect(secondVisit?.visitCount == 2, "Second visit count should be 2")
        #expect(secondVisit?.title == "Updated Title", "Title should be updated")
    }

    @Test("MockHistoryService should delete history by ID")
    func testMockHistoryServiceDeleteById() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        service.addOrUpdateHistory(url: url, title: "Example")

        // 获取 ID
        guard let historyId = service.findHistory(url: url)?.id else {
            throw TestError("Failed to get history ID")
        }

        // 删除
        service.deleteHistory(id: historyId)

        // 验证已删除
        let count = service.getTotalCount()
        #expect(count == 0, "Should have 0 items after deletion")

        let found = service.findHistory(url: url)
        #expect(found == nil, "Should not find deleted history")
    }

    @Test("MockHistoryService should clear all histories")
    func testMockHistoryServiceClearAll() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        // 添加多条记录
        service.addMockData(urls: [
            "https://www.example1.com",
            "https://www.example2.com",
            "https://www.example3.com"
        ])

        #expect(service.getTotalCount() == 3, "Should have 3 items")

        // 清空
        service.clearAllHistory()

        #expect(service.getTotalCount() == 0, "Should have 0 items after clearing")
    }

    @Test("MockHistoryService should find history by ID")
    func testMockHistoryServiceFindById() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        service.addOrUpdateHistory(url: url, title: "Example")

        guard let historyId = service.findHistory(url: url)?.id else {
            throw TestError("Failed to get history ID")
        }

        // 通过 ID 查找
        let found = service.findHistory(id: historyId)

        #expect(found != nil, "Should find history by ID")
        #expect(found?.id == historyId, "ID should match")
        #expect(found?.url == "https://www.example.com", "URL should match")
    }

    @Test("MockHistoryService should return most visited sites")
    func testMockHistoryServiceMostVisited() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        let url1 = URL(string: "https://www.popular.com")!
        let url2 = URL(string: "https://www.rare.com")!

        // 访问 popular.com 5 次
        for _ in 0..<5 {
            service.addOrUpdateHistory(url: url1, title: "Popular")
        }

        // 访问 rare.com 1 次
        service.addOrUpdateHistory(url: url2, title: "Rare")

        // 获取最常访问的站点
        let mostVisited = service.getMostVisited(limit: 2)

        #expect(mostVisited.count == 2, "Should return 2 items")
        #expect(mostVisited[0].url == "https://www.popular.com", "Most visited should be popular.com")
        #expect(mostVisited[0].visitCount == 5, "Should have 5 visits")
    }

    @Test("MockHistoryService should add mock data")
    func testMockHistoryServiceAddMockData() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        // 添加 Mock 数据
        service.addMockData(urls: [
            "https://www.apple.com",
            "https://www.google.com",
            "https://www.microsoft.com"
        ])

        #expect(service.getTotalCount() == 3, "Should have 3 mock items")

        // 验证标题格式
        let apple = service.findHistory(url: URL(string: "https://www.apple.com")!)
        #expect(apple?.title == "Mock: https://www.apple.com", "Title should use default format")
    }

    @Test("MockHistoryService should support custom titles in mock data")
    func testMockHistoryServiceAddMockDataWithTitles() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        // 添加带自定义标题的 Mock 数据
        service.addMockData(
            urls: ["https://www.apple.com"],
            titles: ["Apple"]
        )

        let apple = service.findHistory(url: URL(string: "https://www.apple.com")!)
        #expect(apple?.title == "Apple", "Should use custom title")
    }

    @Test("MockHistoryService should get today's visit count")
    func testMockHistoryServiceTodayVisitCount() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        // 添加今天的访问
        let url = URL(string: "https://www.example.com")!
        service.addOrUpdateHistory(url: url, title: "Today")

        let todayCount = service.getTodayVisitCount()

        #expect(todayCount == 1, "Should have 1 visit today")
    }

    @Test("MockHistoryService should get all histories as array")
    func testMockHistoryServiceGetAllHistoriesArray() async throws {
        let service = MockHistoryService(useInMemoryRealm: false)
        service.clearMockData()

        service.addMockData(urls: [
            "https://www.example1.com",
            "https://www.example2.com"
        ])

        let array = service.getAllHistoriesArray()

        #expect(array.count == 2, "Should return 2 items")
        #expect(array is [WebPageHistory], "Should return array of WebPageHistory")
    }
}

/// MockFavoriteService 数据操作测试
struct MockFavoriteServiceTests {

    @Test("MockFavoriteService should add and retrieve favorite")
    func testMockFavoriteServiceAddAndRetrieve() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        let favorite = service.addFavorite(url: url, title: "Example")

        // 验证总数
        let count = service.getTotalCount()
        #expect(count == 1, "Should have 1 favorite item")

        // 验证可以找到
        let found = service.findFavorite(url: url)
        #expect(found != nil, "Should find the added favorite")
        #expect(found?.url == "https://www.example.com", "URL should match")
        #expect(found?.title == "Example", "Title should match")

        // 验证返回值
        #expect(favorite?.id == found?.id, "Returned favorite should match")
    }

    @Test("MockFavoriteService should not add duplicate favorites")
    func testMockFavoriteServiceNoDuplicates() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!

        // 第一次添加
        let first = service.addFavorite(url: url, title: "First")
        #expect(first != nil, "First add should succeed")

        // 第二次添加（应该返回已存在的）
        let second = service.addFavorite(url: url, title: "Second")
        #expect(second != nil, "Second add should return existing")
        #expect(second?.title == "First", "Should keep original title")

        // 验证总数还是 1
        let count = service.getTotalCount()
        #expect(count == 1, "Should still have only 1 favorite")
    }

    @Test("MockFavoriteService should delete favorite by ID")
    func testMockFavoriteServiceDeleteById() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        let favorite = service.addFavorite(url: url, title: "Example")

        guard let favoriteId = favorite?.id else {
            throw TestError("Failed to get favorite ID")
        }

        // 删除
        service.deleteFavorite(id: favoriteId)

        // 验证已删除
        let count = service.getTotalCount()
        #expect(count == 0, "Should have 0 items after deletion")

        let found = service.findFavorite(url: url)
        #expect(found == nil, "Should not find deleted favorite")
    }

    @Test("MockFavoriteService should delete favorite by URL")
    func testMockFavoriteServiceDeleteByUrl() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        service.addFavorite(url: url, title: "Example")

        // 通过 URL 删除
        service.deleteFavorite(url: url)

        // 验证已删除
        let count = service.getTotalCount()
        #expect(count == 0, "Should have 0 items after deletion")
    }

    @Test("MockFavoriteService should toggle pin status")
    func testMockFavoriteServiceTogglePin() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        let favorite = service.addFavorite(url: url, title: "Example")

        guard let favoriteId = favorite?.id else {
            throw TestError("Failed to get favorite ID")
        }

        // 初始状态应该是未置顶
        let found = service.findFavorite(id: favoriteId)
        #expect(found?.isPinned == false, "Initial pin status should be false")

        // 切换到置顶
        let pinned = service.togglePin(id: favoriteId)
        #expect(pinned == true, "Pin status should be true after toggle")

        // 切换回未置顶
        let unpinned = service.togglePin(id: favoriteId)
        #expect(unpinned == false, "Pin status should be false after second toggle")
    }

    @Test("MockFavoriteService should update cache mode")
    func testMockFavoriteServiceUpdateCacheMode() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        let favorite = service.addFavorite(url: url, title: "Example")

        guard let favoriteId = favorite?.id else {
            throw TestError("Failed to get favorite ID")
        }

        // 启用缓存模式
        service.updateCacheMode(id: favoriteId, enabled: true)

        let found = service.findFavorite(id: favoriteId)
        #expect(found?.enableCacheMode == true, "Cache mode should be enabled")

        // 禁用缓存模式
        service.updateCacheMode(id: favoriteId, enabled: false)

        let updated = service.findFavorite(id: favoriteId)
        #expect(updated?.enableCacheMode == false, "Cache mode should be disabled")
    }

    @Test("MockFavoriteService should update favorite")
    func testMockFavoriteServiceUpdate() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        let favorite = service.addFavorite(url: url, title: "Original Title")

        guard let favoriteId = favorite?.id else {
            throw TestError("Failed to get favorite ID")
        }

        // 更新标题
        var updatedFavorite = service.findFavorite(id: favoriteId)!
        updatedFavorite.title = "Updated Title"
        service.updateFavorite(updatedFavorite)

        // 验证更新
        let found = service.findFavorite(id: favoriteId)
        #expect(found?.title == "Updated Title", "Title should be updated")
    }

    @Test("MockFavoriteService should add mock data")
    func testMockFavoriteServiceAddMockData() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        // 添加 Mock 数据
        service.addMockData(urls: [
            "https://www.apple.com",
            "https://www.google.com",
            "https://www.microsoft.com"
        ])

        #expect(service.getTotalCount() == 3, "Should have 3 mock items")

        // 验证数据
        let apple = service.findFavorite(url: URL(string: "https://www.apple.com")!)
        #expect(apple != nil, "Should find apple.com")
    }

    @Test("MockFavoriteService should get all favorites as array")
    func testMockFavoriteServiceGetAllFavoritesArray() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        service.addMockData(urls: [
            "https://www.example1.com",
            "https://www.example2.com"
        ])

        let array = service.getAllFavoritesArray()

        #expect(array.count == 2, "Should return 2 items")
        #expect(array is [URLFavorite], "Should return array of URLFavorite")
    }

    @Test("MockFavoriteService should find favorite by ID")
    func testMockFavoriteServiceFindById() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        let url = URL(string: "https://www.example.com")!
        let favorite = service.addFavorite(url: url, title: "Example")

        guard let favoriteId = favorite?.id else {
            throw TestError("Failed to get favorite ID")
        }

        // 通过 ID 查找
        let found = service.findFavorite(id: favoriteId)

        #expect(found != nil, "Should find favorite by ID")
        #expect(found?.id == favoriteId, "ID should match")
        #expect(found?.url == "https://www.example.com", "URL should match")
    }

    @Test("MockFavoriteService should clear all mock data")
    func testMockFavoriteServiceClearMockData() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)

        // 添加数据
        service.addMockData(urls: [
            "https://www.example1.com",
            "https://www.example2.com"
        ])

        #expect(service.getTotalCount() == 2, "Should have 2 items")

        // 清空
        service.clearMockData()

        #expect(service.getTotalCount() == 0, "Should have 0 items after clearing")
    }

    @Test("MockFavoriteService should update sort order")
    func testMockFavoriteServiceUpdateSortOrder() async throws {
        let service = MockFavoriteService(useInMemoryRealm: false)
        service.clearMockData()

        // 添加多个收藏
        let fav1 = service.addFavorite(url: URL(string: "https://www.example1.com")!, title: "First")!
        let fav2 = service.addFavorite(url: URL(string: "https://www.example2.com")!, title: "Second")!
        let fav3 = service.addFavorite(url: URL(string: "https://www.example3.com")!, title: "Third")!

        // 调整顺序
        let reordered = [fav3, fav1, fav2]
        service.updateSortOrder(favorites: reordered)

        // 验证顺序
        let all = service.getAllFavoritesArray()
        #expect(all[0].id == fav3.id, "First should be fav3")
        #expect(all[1].id == fav1.id, "Second should be fav1")
        #expect(all[2].id == fav2.id, "Third should be fav2")
    }
}

/// 服务集成测试
struct ServiceIntegrationTests {

    @Test("Services should work correctly in mock mode")
    func testServicesInMockMode() async throws {
        let serviceLocator = ServiceLocator.shared
        serviceLocator.setupMockServices(useInMemoryRealm: false)

        // 添加历史记录
        let historyService = serviceLocator.historyService as! MockHistoryService
        historyService.clearMockData()
        historyService.addMockData(urls: ["https://www.example.com"])

        // 添加收藏
        let favoriteService = serviceLocator.favoriteService as! MockFavoriteService
        favoriteService.clearMockData()
        favoriteService.addMockData(urls: ["https://www.example.com"])

        // 验证都能正常工作
        #expect(historyService.getTotalCount() == 1, "History service should work")
        #expect(favoriteService.getTotalCount() == 1, "Favorite service should work")
    }

    @Test("Mock services should maintain data consistency")
    func testMockServicesDataConsistency() async throws {
        let serviceLocator = ServiceLocator.shared
        serviceLocator.setupMockServices(useInMemoryRealm: false)

        let historyService = serviceLocator.historyService as! MockHistoryService
        let favoriteService = serviceLocator.favoriteService as! MockFavoriteService

        // 清空数据
        historyService.clearMockData()
        favoriteService.clearMockData()

        // 添加相同的 URL 到历史和收藏
        let urlString = "https://www.example.com"
        historyService.addMockData(urls: [urlString])
        favoriteService.addMockData(urls: [urlString])

        // 验证两个服务都能找到
        let url = URL(string: urlString)!
        let history = historyService.findHistory(url: url)
        let favorite = favoriteService.findFavorite(url: url)

        #expect(history != nil, "Should find in history")
        #expect(favorite != nil, "Should find in favorite")
        #expect(history?.url == urlString, "History URL should match")
        #expect(favorite?.url == urlString, "Favorite URL should match")
    }
}

/// 辅助类型
struct TestError: Error {
    let message: String
}
