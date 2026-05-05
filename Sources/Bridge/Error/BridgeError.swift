//
//  BridgeError.swift
//  WebBridgeKit
//

import Foundation

/// 统一的 Bridge 错误类型
public enum BridgeError: Error, LocalizedError {
    case permissionDenied(action: String, permission: String)
    case parameterInvalid(action: String, param: String, reason: String)
    case hardwareUnavailable(action: String, reason: String)
    case timeout(action: String, seconds: Double)
    case cancelled(action: String)
    case notSupported(action: String, reason: String)
    case executionFailed(action: String, underlyingError: Error)
    case notRegistered(action: String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let action, let perm):
            return "[\(action)] Permission denied: \(perm)"
        case .parameterInvalid(let action, let param, let reason):
            return "[\(action)] Invalid parameter '\(param)': \(reason)"
        case .hardwareUnavailable(let action, let reason):
            return "[\(action)] Hardware unavailable: \(reason)"
        case .timeout(let action, let seconds):
            return "[\(action)] Timeout after \(String(format: "%.1f", seconds))s"
        case .cancelled(let action):
            return "[\(action)] Cancelled by user"
        case .notSupported(let action, let reason):
            return "[\(action)] Not supported: \(reason)"
        case .executionFailed(let action, let error):
            return "[\(action)] Execution failed: \(error.localizedDescription)"
        case .notRegistered(let action):
            return "[\(action)] Handler not registered"
        }
    }
    
    /// 标准错误码
    public var errorCode: String {
        switch self {
        case .permissionDenied:  return "PERMISSION_DENIED"
        case .parameterInvalid:  return "PARAMETER_INVALID"
        case .hardwareUnavailable: return "HARDWARE_UNAVAILABLE"
        case .timeout:           return "TIMEOUT"
        case .cancelled:         return "CANCELLED"
        case .notSupported:      return "NOT_SUPPORTED"
        case .executionFailed:   return "EXECUTION_FAILED"
        case .notRegistered:     return "NOT_REGISTERED"
        }
    }
    
    /// 建议的解决方案
    public var suggestion: String {
        switch self {
        case .permissionDenied(_, let perm):
            return "Please grant \(perm) permission in Settings > Privacy"
        case .parameterInvalid(_, let param, _):
            return "Check the '\(param)' parameter value"
        case .hardwareUnavailable(_, let reason):
            return "This device does not support this feature: \(reason)"
        case .timeout:
            return "Try again or increase the timeout"
        case .cancelled:
            return "User cancelled the operation"
        case .notSupported(_, let reason):
            return "This feature is not available: \(reason)"
        case .executionFailed(_, let error):
            return "Check the underlying error: \(error.localizedDescription)"
        case .notRegistered(let action):
            return "Handler '\(action)' is not registered. Available handlers may not include this action."
        }
    }
    
    /// 可复制的调试信息
    public var debugInfo: String {
        """
        BridgeError: \(errorCode)
        Action: \(actionName)
        Message: \(errorDescription ?? "unknown")
        Suggestion: \(suggestion)
        """
    }
    
    /// 关联的 action 名称
    public var actionName: String {
        switch self {
        case .permissionDenied(let a, _): return a
        case .parameterInvalid(let a, _, _): return a
        case .hardwareUnavailable(let a, _): return a
        case .timeout(let a, _): return a
        case .cancelled(let a): return a
        case .notSupported(let a, _): return a
        case .executionFailed(let a, _): return a
        case .notRegistered(let a): return a
        }
    }
    
    /// 转为 JS 返回的 error 对象
    public var jsErrorDict: [String: Any] {
        [
            "success": false,
            "error": [
                "code": errorCode,
                "action": actionName,
                "message": errorDescription ?? "",
                "suggestion": suggestion
            ]
        ]
    }
}
