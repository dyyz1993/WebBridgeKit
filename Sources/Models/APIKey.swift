//
//  APIKey.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import RxDataSources

/// API 密钥模型
public class APIKey: Object {
    @objc dynamic public var id: String = UUID().uuidString
    @objc dynamic public var keyType: String = "permanent" // permanent/temporary
    @objc dynamic public var keyValue: String = ""
    @objc dynamic public var isActive: Bool = true
    @objc dynamic public var createdAt: Date = Date()
    @objc dynamic public var expiresAt: Date? = nil

    override public class func primaryKey() -> String? {
        return "id"
    }

    override public class func indexedProperties() -> [String] {
        return ["keyType", "isActive"]
    }

    /// 是否永久密钥
    public var isPermanent: Bool {
        return keyType == "permanent"
    }

    /// 是否已过期
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// 剩余有效时间（秒）
    public var remainingSeconds: Int? {
        guard let expiresAt = expiresAt else { return nil }
        let remaining = expiresAt.timeIntervalSince(Date())
        return max(0, Int(remaining))
    }

    /// 剩余有效时间格式化字符串
    public var remainingTimeText: String? {
        guard let remaining = remainingSeconds else { return nil }

        if isPermanent {
            return "永久有效"
        }

        if remaining == 0 {
            return "已过期"
        }

        let days = remaining / 86400
        let hours = (remaining % 86400) / 3600
        let minutes = (remaining % 3600) / 60

        if days > 0 {
            return "\(days)天\(hours)小时"
        } else if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }

    /// 格式化创建时间
    public var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 密钥脱敏显示（只显示前 8 位和后 4 位）
    public var maskedKey: String {
        guard keyValue.count > 12 else { return keyValue }
        let prefix = String(keyValue.prefix(8))
        let suffix = String(keyValue.suffix(4))
        return "\(prefix)****\(suffix)"
    }
}

// MARK: - IdentifiableType

extension APIKey: IdentifiableType {
    public var identity: String {
        return id
    }
}
