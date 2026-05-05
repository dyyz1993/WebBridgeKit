//
//  HandlerMeta.swift
//  WebBridgeKit
//

import Foundation

/// Handler 分类
public enum HandlerCategory: String, Codable, CaseIterable {
    case hardware
    case media
    case navigation
    case system
    case feedback
    case sensor
    case clipboard
    case permission
    case debug
    case cache
    case file
    case speech

    public var displayName: String {
        switch self {
        case .hardware:   return "硬件"
        case .media:      return "媒体"
        case .navigation: return "导航"
        case .system:     return "系统"
        case .feedback:   return "反馈"
        case .sensor:     return "传感器"
        case .clipboard:  return "剪贴板"
        case .permission: return "权限"
        case .debug:      return "调试"
        case .cache:      return "缓存"
        case .file:       return "文件"
        case .speech:     return "语音"
        }
    }

    public var emoji: String {
        switch self {
        case .hardware:   return "🔧"
        case .media:      return "🎬"
        case .navigation: return "🧭"
        case .system:     return "⚙️"
        case .feedback:   return "📳"
        case .sensor:     return "📡"
        case .clipboard:  return "📋"
        case .permission: return "🔐"
        case .debug:      return "🐛"
        case .cache:      return "📦"
        case .file:       return "📁"
        case .speech:     return "🗣️"
        }
    }
}

/// 参数类型
public enum ParamType: String, Codable {
    case string
    case int
    case double
    case bool
    case array
    case object
}

/// 参数定义（用于自动生成调试表单）
public struct ParamDef: Codable {
    public let name: String
    public let type: ParamType
    public let required: Bool
    public let defaultValue: String?
    public let description: String
    public let options: [String]?

    public init(name: String, type: ParamType, required: Bool = false,
                defaultValue: String? = nil, description: String = "",
                options: [String]? = nil) {
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
        self.description = description
        self.options = options
    }
}

/// 返回值定义
public struct ReturnDef: Codable {
    public let name: String
    public let type: ParamType
    public let description: String

    public init(name: String, type: ParamType, description: String = "") {
        self.name = name
        self.type = type
        self.description = description
    }
}

/// Handler 元数据（自动注册、自动发现、调试面板自动生成）
public struct HandlerMeta: Codable {
    /// action 名称（JS 调用时的 key）
    public let action: String

    /// 分类
    public let category: HandlerCategory

    /// 显示名称
    public let displayName: String

    /// 描述
    public let description: String

    /// 需要的权限
    public let requiredPermissions: [String]

    /// 参数定义
    public let parameters: [ParamDef]

    /// 返回值定义
    public let returns: [ReturnDef]

    /// 是否需要网络
    public let requiresNetwork: Bool

    /// 是否需要硬件
    public let requiresHardware: Bool

    /// 最低 iOS 版本
    public let minimumiOSVersion: String?

    public init(
        action: String,
        category: HandlerCategory,
        displayName: String,
        description: String,
        requiredPermissions: [String] = [],
        parameters: [ParamDef] = [],
        returns: [ReturnDef] = [],
        requiresNetwork: Bool = false,
        requiresHardware: Bool = false,
        minimumiOSVersion: String? = nil
    ) {
        self.action = action
        self.category = category
        self.displayName = displayName
        self.description = description
        self.requiredPermissions = requiredPermissions
        self.parameters = parameters
        self.returns = returns
        self.requiresNetwork = requiresNetwork
        self.requiresHardware = requiresHardware
        self.minimumiOSVersion = minimumiOSVersion
    }

    /// 转为 JSON（用于 API 输出）
    public var jsonDict: [String: Any] {
        var dict: [String: Any] = [
            "action": action,
            "category": category.rawValue,
            "displayName": displayName,
            "description": description,
            "requiresNetwork": requiresNetwork,
            "requiresHardware": requiresHardware
        ]
        if !requiredPermissions.isEmpty {
            dict["requiredPermissions"] = requiredPermissions
        }
        if !parameters.isEmpty {
            dict["parameters"] = parameters.map { [
                "name": $0.name,
                "type": $0.type.rawValue,
                "required": $0.required,
                "description": $0.description,
                "default": $0.defaultValue ?? NSNull(),
                "options": $0.options ?? []
            ] }
        }
        if !returns.isEmpty {
            dict["returns"] = returns.map { [
                "name": $0.name,
                "type": $0.type.rawValue,
                "description": $0.description
            ] }
        }
        if let version = minimumiOSVersion {
            dict["minimumiOSVersion"] = version
        }
        return dict
    }
}
