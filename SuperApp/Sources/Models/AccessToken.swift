//
//  AccessToken.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import RxDataSources
import WebBridgeKit

/// 访问口令模型
public class AccessToken: Object {
    @objc public dynamic var id: String = UUID().uuidString
    @objc public dynamic var url: String = ""
    @objc public dynamic var token: String = ""           // 口令码
    @objc public dynamic var title: String?
    @objc public dynamic var validDuration: Int = 0       // 有效时长(秒)
    @objc public dynamic var createdAt: Date = Date()
    @objc public dynamic var expiresAt: Date = Date()
    @objc public dynamic var accessCount: Int = 0         // 访问次数

    override public class func primaryKey() -> String? {
        return "id"
    }

    override public class func indexedProperties() -> [String] {
        return ["token", "expiresAt"]
    }

    /// 是否已过期
    public var isExpired: Bool {
        return Date() > expiresAt
    }

    /// 剩余有效时间（秒）
    public var remainingSeconds: Int {
        let remaining = expiresAt.timeIntervalSince(Date())
        return max(0, Int(remaining))
    }

    /// 剩余有效时间格式化字符串
    public var remainingTimeText: String {
        let remaining = remainingSeconds

        if remaining == 0 {
            return L10n.tr("model.access_token.expired")
        }

        let days = remaining / 86400
        let hours = (remaining % 86400) / 3600
        let minutes = (remaining % 3600) / 60

        if days > 0 {
            return L10n.tr("model.access_token.days_hours_format", "\(days)", "\(hours)")
        } else if hours > 0 {
            return L10n.tr("model.access_token.hours_minutes_format", "\(hours)", "\(minutes)")
        } else {
            return L10n.tr("model.access_token.minutes_format", "\(minutes)")
        }
    }

    /// 是否永久有效
    public var isPermanent: Bool {
        return validDuration == -1
    }

    /// 格式化创建时间
    public var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }
}

// MARK: - IdentifiableType

extension AccessToken: IdentifiableType {
    public var identity: String {
        return id
    }
}
