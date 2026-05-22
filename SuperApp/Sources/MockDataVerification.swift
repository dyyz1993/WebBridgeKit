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
        #if DEBUG
        print("[SEARCH] [MockDataVerification] 开始验证Mock数据...")
        #endif

        let locator = ServiceLocator.shared
        let historyService = locator.historyService
        let favoriteService = locator.favoriteService

        // 检查服务模式
        if locator.currentMode == .mock {
            #if DEBUG
            print("[OK] 服务模式: Mock")
            #endif
        } else {
            #if DEBUG
            print("[WARN] 服务模式: Production (应该是Mock)")
            #endif
        }

        // 检查历史记录数量
        let historyCount = historyService.getTotalCount()
        #if DEBUG
        print("[STATS] 历史记录数量: \(historyCount)")
        #endif

        // 检查收藏数量
        let favoriteCount = favoriteService.getTotalCount()
        #if DEBUG
        print("[STATS] 收藏数量: \(favoriteCount)")
        #endif

        // 验证是否有数据
        let hasData = historyCount > 0 && favoriteCount > 0
        if hasData {
            #if DEBUG
            print("[OK] Mock数据验证成功！")
            #endif
        } else {
            #if DEBUG
            print("[FAIL] Mock数据验证失败！")
            #endif
        }

        return hasData
    }
}
