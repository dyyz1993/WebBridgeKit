//
//  WebPageHistory.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-15.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift


// Framework imports

/// H5页面历史记录模型
public class WebPageHistory: Object {
    @objc dynamic public var id: String = UUID().uuidString
    @objc dynamic public var url: String = ""
    @objc dynamic public var title: String?
    @objc dynamic public var favicon: Data?
    @objc dynamic public var htmlPath: String?
    public let resourcePaths = List<String>()
    @objc dynamic public var cachedSize: Int64 = 0
    @objc dynamic public var isCached: Bool = false
    @objc dynamic public var isPinned: Bool = false      // 是否置顶
    @objc dynamic public var isFavorite: Bool = false    // 是否收藏
    @objc dynamic public var visitCount: Int = 0
    @objc dynamic public var lastVisitDate = Date()
    @objc dynamic public var cacheDate: Date?
    @objc dynamic public var thumbnail: Data?

    // PageCacheRule 关联
    @objc dynamic public var ruleId: String?        // 关联的规则 ID
    @objc dynamic public var ruleName: String?      // 关联的规则名称
    @objc dynamic public var isExcluded: Bool = false     // 是否被规则排除

    override public class func primaryKey() -> String? {
        return "id"
    }

    override public class func indexedProperties() -> [String] {
        return ["url", "isCached", "lastVisitDate", "ruleId"]
    }

    /// 格式化缓存大小为可读字符串
    public var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: cachedSize, countStyle: .file)
    }

    /// 是否有缩略图
    var hasThumbnail: Bool {
        return thumbnail != nil
    }

    /// 获取缓存目录
    var cacheDirectory: URL? {
        guard isCached else { return nil }
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheBase.appendingPathComponent("WebPageCache").appendingPathComponent(id)
    }
}

// MARK: - IdentifiableType

#if canImport(RxDataSources)
import RxDataSources

extension WebPageHistory: IdentifiableType {
    public var identity: String {
        return id
    }
}
#endif
