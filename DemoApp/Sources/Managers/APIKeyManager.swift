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
    
    /// 创建新 Key
    func createKey(name: String, description: String? = nil) {
        let newKey = APIKey(name: name, description: description)
        var current = keysRelay.value
        current.append(newKey)
        keysRelay.accept(current)
        saveKeys()
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
        return keysRelay.value.first { $0.value == value && $0.isEnabled }
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
            // 如果是第一次使用，可以默认创建一个
            createKey(name: "默认推送密钥", description: "主账号使用的 Webhook 密钥")
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
