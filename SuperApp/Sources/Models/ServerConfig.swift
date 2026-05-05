//
//  ServerConfig.swift
//  WebBridgeKit
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RealmSwift
import RxDataSources

/// 服务器配置模型
public class ServerConfig: Object {
    @objc public dynamic var id: String = "default"
    @objc public dynamic var serverType: String = "default" // default/custom
    @objc public dynamic var baseURL: String?
    @objc public dynamic var apiEndpoint: String?
    @objc public dynamic var isActive: Bool = true
    @objc public dynamic var updatedAt: Date = Date()

    override public class func primaryKey() -> String? {
        return "id"
    }

    override public class func indexedProperties() -> [String] {
        return ["isActive", "serverType"]
    }

    /// 是否为默认配置
    public var isDefault: Bool {
        return serverType == "default"
    }

    /// 格式化更新时间
    public var formattedUpdatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: updatedAt)
    }

    /// 获取完整的 API 地址
    public var fullAPIURL: URL? {
        guard let endpoint = apiEndpoint else { return nil }
        if let base = baseURL {
            return URL(string: base + endpoint)
        }
        return URL(string: endpoint)
    }
}

// MARK: - IdentifiableType

extension ServerConfig: IdentifiableType {
    public var identity: String {
        return id
    }
}
