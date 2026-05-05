//
//  WebContactsHandler.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Contacts
import ContactsUI
import Foundation
import UIKit
import WebKit

// Framework imports

/// 通讯录功能处理器
/// 支持选择单个联系人、获取所有联系人、检查通讯录权限
public class WebContactsHandler: BaseWebNativeHandler {

    private var pendingCompletion: ((Any) -> Void)?

    /**
     * 处理通讯录相关请求
     * - Parameters:
     *   - body: 请求参数字典 (action, limit)
     *   - completion: 结果回调
     */
    public override func handle(body: [String: Any], completion: @escaping (Any) -> Void) {
        // 兼容 body 或 body.params
        let params = body["params"] as? [String: Any] ?? body
        let action = params["action"] as? String ?? "pick"

        // 兼容 JS 传来的数字类型 (NSNumber)
        let limit: Int
        if let limitNum = params["limit"] as? NSNumber {
            limit = limitNum.intValue
        } else if let limitInt = params["limit"] as? Int {
            limit = limitInt
        } else {
            limit = 1
        }

        switch action {
        case "pick":
            requestContactsPermission { [weak self] granted in
                if granted {
                    self?.pickContact(limit: limit, completion: completion)
                } else {
                    self?.rejectPermissionDenied(type: .contacts, status: .denied, completion: completion)
                }
            }
        case "checkPermission":
            checkPermission(completion: completion)
        case "getAll":
            requestContactsPermission { [weak self] granted in
                if granted {
                    self?.fetchAllContacts(limit: limit, completion: completion)
                } else {
                    self?.rejectPermissionDenied(type: .contacts, status: .denied, completion: completion)
                }
            }
        default:
            reject(error: "Unknown action: \(action)", completion: completion)
        }
    }

    /**
     * 检查通讯录权限状态
     * - Parameter completion: 结果回调
     */
    private func checkPermission(completion: @escaping (Any) -> Void) {
        runOnMainThread {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            let authorized = status == .authorized

            self.resolve([
                "authorized": authorized,
                "status": self.permissionStatusString(status)
            ], completion: completion)
        }
    }

    /**
     * 将权限状态枚举转换为字符串
     * - Parameter status: 权限状态
     * - Returns: 状态字符串
     */
    private func permissionStatusString(_ status: CNAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            "authorized"
        case .denied:
            "denied"
        case .restricted:
            "restricted"
        case .notDetermined:
            "notDetermined"
        case .limited:
            // Limited access available in iOS 14+
            if #available(iOS 14.0, *) {
                "limited"
            } else {
                "unknown"
            }
        @unknown default:
            // Handle any future authorization status values
            "unknown"
        }
    }

    /**
     * 请求通讯录访问权限
     * - Parameter completion: 权限结果回调
     */
    private func requestContactsPermission(completion: @escaping (Bool) -> Void) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            runOnMainThread {
                completion(true)
            }
        case .notDetermined:
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { [weak self] granted, _ in
                self?.runOnMainThread {
                    completion(granted)
                }
            }
        default:
            runOnMainThread {
                completion(false)
            }
        }
    }

    /**
     * 打开系统联系人选择器
     * - Parameters:
     *   - limit: 选择限制（目前 iOS 系统选择器主要支持单选或多选模式切换）
     *   - completion: 结果回调
     */
    private func pickContact(limit: Int, completion: @escaping (Any) -> Void) {
        guard let topVC = self.topViewController else {
            reject(error: "No view controller available", completion: completion)
            return
        }

        self.pendingCompletion = completion

        runOnMainThread {
            let picker = CNContactPickerViewController()
            picker.delegate = self
            topVC.present(picker, animated: true)
        }
    }

    /**
     * 获取所有联系人列表
     * - Parameters:
     *   - limit: 数量限制
     *   - completion: 结果回调
     */
    private func fetchAllContacts(limit: Int, completion: @escaping (Any) -> Void) {
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var contacts: [[String: Any]] = []
        var count = 0

        do {
            try store.enumerateContacts(with: request) { (contact, stop) in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                let phones = contact.phoneNumbers.map { $0.value.stringValue }

                contacts.append([
                    "name": name,
                    "phones": phones
                ])

                count += 1
                if count >= limit {
                    stop.pointee = true
                }
            }
            resolve(["contacts": contacts], completion: completion)
        } catch {
            reject(error: "Failed to fetch contacts: \(error.localizedDescription)", completion: completion)
        }
    }
}

// MARK: - CNContactPickerDelegate

extension WebContactsHandler: CNContactPickerDelegate {
    /**
     * 用户取消选择联系人
     */
    public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        if let completion = self.pendingCompletion {
            reject(error: "User cancelled", completion: completion)
            self.pendingCompletion = nil
        }
    }

    /**
     * 用户选择了单个联系人
     */
    public func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if let completion = self.pendingCompletion {
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phones = contact.phoneNumbers.map { $0.value.stringValue }

            let result = [[
                "name": name,
                "phones": phones
            ]]

            resolve(["contacts": result], completion: completion)
            self.pendingCompletion = nil
        }
    }
}
