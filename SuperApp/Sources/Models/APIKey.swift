//
//  APIKey.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import Foundation

/// API Key 模型
struct APIKey: Codable, Equatable {
    /// 唯一标识
    let id: String
    /// 密钥名称（如：GitHub 推送、新闻组）
    var name: String
    /// 原始密钥值 (sk-xxxx)
    let value: String
    /// 创建时间
    let createdAt: Date
    /// 过期时间（nil 表示永久有效）
    let expiresAt: Date?
    /// 绑定的来源/描述
    var description: String?
    /// 是否启用
    var isEnabled: Bool
    /// 绑定的群组或来源 ID (可选)
    var boundGroupId: String?
    
    init(id: String = UUID().uuidString,
         name: String,
         value: String = "sk-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
         createdAt: Date = Date(),
         expiresAt: Date? = nil,
         description: String? = nil,
         isEnabled: Bool = true,
         boundGroupId: String? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.description = description
        self.isEnabled = isEnabled
        self.boundGroupId = boundGroupId
    }

    // MARK: - Computed Properties for UI compatibility

    /// 是否是永久密钥
    var isPermanent: Bool {
        return expiresAt == nil
    }

    /// 是否已过期
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// 密钥显示值
    var keyValue: String {
        return value
    }

    /// 脱敏后的密钥
    var maskedKey: String {
        guard value.count > 10 else { return value }
        let prefix = value.prefix(6)
        let suffix = value.suffix(4)
        return "\(prefix)****\(suffix)"
    }

    /// 格式化后的创建时间
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 剩余时间文本
    var remainingTimeText: String? {
        guard let expiresAt = expiresAt else { return "永久有效" }
        let interval = expiresAt.timeIntervalSinceNow
        if interval <= 0 { return "已过期" }
        
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) 分钟后过期"
        }
        
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) 小时后过期"
        }
        
        let days = hours / 24
        return "\(days) 天后过期"
    }
}
