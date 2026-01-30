//
//  RealmConfiguration.swift
//  NotificationServiceExtension
//
//  Created by huangfeng on 2024/5/29.
//  Copyright © 2024 Fin. All rights reserved.
//

@_exported import RealmSwift
import UIKit

let kRealmDefaultConfiguration = {
    var fileUrl: URL
    if let groupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.xuyingzhou.bark") {
        fileUrl = groupUrl.appendingPathComponent("bark.realm")
    } else {
        // 如果 App Group 不可用，使用默认目录
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileUrl = documentsUrl.appendingPathComponent("bark.realm")
    }
    let config = Realm.Configuration(
        fileURL: fileUrl,
        schemaVersion: 18,
        migrationBlock: { migration, oldSchemaVersion in
            // Migration logic should be handled in the app layer, not in WebBridgeKit
            // This configuration is provided for backward compatibility
            switch oldSchemaVersion {
            default:
                break
            }
        }
    )
    return config
}()
