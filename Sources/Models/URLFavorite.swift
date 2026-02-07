//
//  URLFavorite.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import RxDataSources

/// URL 收藏模型
public class URLFavorite: Object {
    @objc dynamic public var id: String = UUID().uuidString
    @objc dynamic public var url: String = ""
    @objc dynamic public var title: String? = nil
    @objc dynamic public var favicon: Data? = nil
    @objc dynamic public var isPinned: Bool = false      // 置顶
    @objc dynamic public var sortOrder: Int = 0         // 排序
    @objc dynamic public var createdAt: Date = Date()
    @objc dynamic public var enableCacheMode: Bool = false // 开启缓存模式

    override public class func primaryKey() -> String? {
        return "id"
    }

    override public class func indexedProperties() -> [String] {
        return ["url", "isPinned", "sortOrder"]
    }

    /// 格式化创建时间
    public var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 获取 URL 的域名
    public var domain: String? {
        guard let urlObj = URL(string: url) else { return nil }
        return urlObj.host
    }
}

// MARK: - IdentifiableType

extension URLFavorite: IdentifiableType {
    public var identity: String {
        return id
    }
}
