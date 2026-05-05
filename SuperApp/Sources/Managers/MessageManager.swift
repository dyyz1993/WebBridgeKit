//
//  MessageManager.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import Foundation
import RxSwift
import RxCocoa

/// 消息管理类
/// 负责消息的持久化、未读计数以及消息的分发
class MessageManager {
    
    static let shared = MessageManager()
    
    private let messagesRelay = BehaviorRelay<[WebhookMessage]>(value: [])
    private let unreadCountRelay = BehaviorRelay<Int>(value: 0)
    
    private let disposeBag = DisposeBag()
    private let storageKey = "SuperCache_Messages"
    
    private init() {
        loadMessages()
        
        // 自动更新未读计数
        messagesRelay
            .map { $0.filter { !$0.isRead }.count }
            .bind(to: unreadCountRelay)
            .disposed(by: disposeBag)
    }
    
    // MARK: - Public API
    
    /// 消息列表流
    var messages: Observable<[WebhookMessage]> {
        return messagesRelay.asObservable()
    }
    
    /// 未读消息数流
    var unreadCount: Observable<Int> {
        return unreadCountRelay.asObservable()
    }
    
    /// 添加新消息（模拟 Webhook 接收）
    func addMessage(_ message: WebhookMessage) {
        var current = messagesRelay.value
        current.insert(message, at: 0)
        messagesRelay.accept(current)
        saveMessages()
        
        // 如果消息带有 URL 或 AppID，且符合“自动打开”条件，可以触发通知
        if let urlString = message.url, let url = URL(string: urlString) {
            print("🔔 [MessageManager] New message received with URL: \(urlString)")
            // 这里可以触发一个 Notification 供其他组件监听并跳转
            NotificationCenter.default.post(name: .didReceivePushMessage, object: nil, userInfo: ["url": url, "message": message])
        }
    }
    
    /// 标记为已读
    func markAsRead(id: String) {
        var current = messagesRelay.value
        if let index = current.firstIndex(where: { $0.id == id }) {
            var msg = current[index]
            msg.isRead = true
            current[index] = msg
            messagesRelay.accept(current)
            saveMessages()
        }
    }
    
    /// 清空所有消息
    func clearAll() {
        messagesRelay.accept([])
        saveMessages()
    }
    
    // MARK: - Persistence
    
    private func saveMessages() {
        do {
            let data = try JSONEncoder().encode(messagesRelay.value)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ [MessageManager] Failed to save messages: \(error)")
        }
    }
    
    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([WebhookMessage].self, from: data)
            messagesRelay.accept(decoded)
        } catch {
            print("❌ [MessageManager] Failed to load messages: \(error)")
        }
    }
}
