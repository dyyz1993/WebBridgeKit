//
//  MockDataVerification.swift
//  SuperApp
//
//  Created on 2026-01-31.
//

import Foundation
import WebBridgeKit

/// Mock数据验证工具
public class MockDataVerification {

    /// 验证Mock数据是否正确加载
    public static func verifyMockData() -> Bool {
        print("🔍 [MockDataVerification] 开始验证Mock数据...")

        let locator = ServiceLocator.shared
        let historyService = locator.historyService
        let favoriteService = locator.favoriteService

        // 检查服务模式
        if locator.currentMode == .mock {
            print("✅ 服务模式: Mock")
        } else {
            print("⚠️ 服务模式: Production (应该是Mock)")
        }

        // 检查历史记录数量
        let historyCount = historyService.getTotalCount()
        print("📊 历史记录数量: \(historyCount)")

        // 检查收藏数量
        let favoriteCount = favoriteService.getTotalCount()
        print("📊 收藏数量: \(favoriteCount)")

        // 验证是否有数据
        let hasData = historyCount > 0 && favoriteCount > 0
        if hasData {
            print("✅ Mock数据验证成功！")
        } else {
            print("❌ Mock数据验证失败！")
        }

        return hasData
    }
}
