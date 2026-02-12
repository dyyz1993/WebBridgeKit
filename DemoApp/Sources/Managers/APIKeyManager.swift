//
//  APIKeyManager.swift
//  DemoApp
//
//  Created on 2026-02-07.
//

import Foundation
import RxSwift
import RxCocoa

/// API Key 管理器
class APIKeyManager {
    
    static let shared = APIKeyManager()
    
    private let keysRelay = BehaviorRelay<[APIKey]>(value: [])
    private let storageKey = "SuperCache_APIKeys"
    
    private init() {
        loadKeys()
    }
    
    // MARK: - Public API
    
    /// API Key 列表流
    var keys: Observable<[APIKey]> {
        return keysRelay.asObservable()
    }
    
    /// 获取所有 Key
    func getAllKeys() -> [APIKey] {
        return keysRelay.value
    }
    
    /// 创建新 Key
    @discardableResult
    func createKey(name: String, description: String? = nil, boundGroupId: String? = nil, expiresAt: Date? = nil) -> APIKey {
        let newKey = APIKey(name: name, expiresAt: expiresAt, description: description, boundGroupId: boundGroupId)
        var current = keysRelay.value
        current.append(newKey)
        keysRelay.accept(current)
        saveKeys()
        return newKey
    }
    
    /// 删除 Key
    func deleteKey(id: String) {
        var current = keysRelay.value
        current.removeAll { $0.id == id }
        keysRelay.accept(current)
        saveKeys()
    }
    
    /// 更新 Key 状态
    func updateKey(_ key: APIKey) {
        var current = keysRelay.value
        if let index = current.firstIndex(where: { $0.id == key.id }) {
            current[index] = key
            keysRelay.accept(current)
            saveKeys()
        }
    }
    
    /// 根据密钥值查找对应的 Key 配置
    func findKey(by value: String) -> APIKey? {
        return keysRelay.value.first { $0.value == value && $0.isEnabled && !$0.isExpired }
    }
    
    // MARK: - Compatibility Methods for APIKeyManageViewModel
    
    /// 获取永久密钥（如果不存在则创建一个）
    func getPermanentKey() -> APIKey {
        if let permanent = keysRelay.value.first(where: { $0.isPermanent }) {
            return permanent
        }
        return createKey(name: "默认永久密钥", description: "主账号使用的永久 Webhook 密钥")
    }
    
    /// 刷新永久密钥
    func refreshPermanentKey() -> APIKey {
        var current = keysRelay.value
        if let index = current.firstIndex(where: { $0.isPermanent }) {
            let oldKey = current[index]
            let newKey = APIKey(name: oldKey.name, description: oldKey.description, boundGroupId: oldKey.boundGroupId)
            current[index] = newKey
            keysRelay.accept(current)
            saveKeys()
            return newKey
        } else {
            return createKey(name: "默认永久密钥")
        }
    }
    
    /// 生成临时密钥
    func generateTemporaryKey(duration: TimeInterval, name: String? = nil, boundGroupId: String? = nil) -> APIKey {
        let expiresAt = Date().addingTimeInterval(duration)
        let finalName = name ?? "临时密钥 (\(Int(duration / 3600))小时)"
        return createKey(name: finalName, boundGroupId: boundGroupId, expiresAt: expiresAt)
    }
    
    /// 获取所有临时密钥
    func getTemporaryKeys() -> [APIKey] {
        return keysRelay.value.filter { !$0.isPermanent }
    }
    
    /// 清理已过期的临时密钥
    func cleanupExpiredKeys() {
        var current = keysRelay.value
        let originalCount = current.count
        current.removeAll { $0.isExpired }
        if current.count != originalCount {
            keysRelay.accept(current)
            saveKeys()
        }
    }
    
    // MARK: - Persistence
    
    private func saveKeys() {
        do {
            let data = try JSONEncoder().encode(keysRelay.value)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ [APIKeyManager] Failed to save keys: \(error)")
        }
    }
    
    private func loadKeys() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // 如果是第一次使用，不默认创建，让 getPermanentKey 处理
            return
        }
        do {
            let decoded = try JSONDecoder().decode([APIKey].self, from: data)
            keysRelay.accept(decoded)
        } catch {
            print("❌ [APIKeyManager] Failed to load keys: \(error)")
        }
    }
}
