//
//  WebhookMessage.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import Foundation

/// Webhook 消息模型
struct WebhookMessage: Codable, Equatable {
    /// 唯一标识
    let id: String
    /// 标题
    let title: String
    /// 内容描述
    let content: String
    /// 来源（例如：CI/CD BOT, GitHub）
    let source: String
    /// 跳转 URL（可选）
    let url: String?
    /// AppID（可选，用于直接打开应用）
    let appId: String?
    /// 时间戳
    let timestamp: Date
    /// 是否已读
    var isRead: Bool
    /// 附加参数（用于透传至 WebView）
    let params: [String: String]?
    
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         source: String,
         url: String? = nil,
         appId: String? = nil,
         timestamp: Date = Date(),
         isRead: Bool = false,
         params: [String: String]? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.url = url
        self.appId = appId
        self.timestamp = timestamp
        self.isRead = isRead
        self.params = params
    }
}
