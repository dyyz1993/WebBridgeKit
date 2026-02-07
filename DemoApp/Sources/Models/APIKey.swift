//
//  APIKey.swift
//  DemoApp
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
         description: String? = nil,
         isEnabled: Bool = true,
         boundGroupId: String? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.createdAt = createdAt
        self.description = description
        self.isEnabled = isEnabled
        self.boundGroupId = boundGroupId
    }
}
