//
//  WebCacheStatistics.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import RealmSwift

/// 网站缓存统计模型
public class WebCacheStatistics: Object {
    @objc dynamic public var domain = ""
    @objc dynamic public var totalSize: Int64 = 0
    @objc dynamic public var fileCount = 0
    @objc dynamic public var lastUpdate = Date()

    override public class func primaryKey() -> String? {
        return "domain"
    }

    override public class func indexedProperties() -> [String] {
        return ["domain", "lastUpdate"]
    }

    /// 格式化缓存大小为可读字符串
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
