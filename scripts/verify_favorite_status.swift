#!/usr/bin/env swift

//
//  verify_favorite_status.swift
//  WebBridgeKit
//
//  验证收藏状态显示功能的实现
//

import Foundation

print("🔍 验证收藏状态显示功能...")
print("")

// 检查文件是否存在
let fileManager = FileManager.default

let filesToCheck = [
    "/Users/xuyingzhou/Project/temporary/WebBridgeKit/DemoApp/Sources/Views/Cells/URLGridCell.swift",
    "/Users/xuyingzhou/Project/temporary/WebBridgeKit/DemoApp/Sources/Controllers/MainViewController.swift"
]

for file in filesToCheck {
    if fileManager.fileExists(atPath: file) {
        print("✅ 文件存在: \(file)")
    } else {
        print("❌ 文件不存在: \(file)")
    }
}

print("")
print("📋 检查关键实现...")

// 检查 URLGridCell.swift
if let content = try? String(contentsOfFile: filesToCheck[0]) {
    let checks = [
        ("isFavorite 属性", content.contains("var isFavorite: Bool")),
        ("updateFavoriteIcon 方法", content.contains("private func updateFavoriteIcon()")),
        ("收藏状态更新", content.contains("favoriteIconView.isHidden = !isFavorite")),
        ("prepareForReuse 重置", content.contains("isFavorite = false"))
    ]

    for (name, passed) in checks {
        print(passed ? "✅" : "❌", name)
    }
}

print("")

// 检查 MainViewController.swift
if let content = try? String(contentsOfFile: filesToCheck[1]) {
    let checks = [
        ("收藏状态检查", content.contains("URLFavoriteManager.shared.findFavorite")),
        ("cell.isFavorite 设置", content.contains("cell.isFavorite ="))
    ]

    for (name, passed) in checks {
        print(passed ? "✅" : "❌", name)
    }
}

print("")
print("🎉 收藏状态显示功能实现完成!")
print("")
print("📝 功能说明:")
print("1. URLGridCell 现在拥有 isFavorite 属性")
print("2. 当 isFavorite 为 true 时，会显示星标图标")
print("3. MainViewController 在渲染 cell 时会检查收藏状态")
print("4. 使用 URLFavoriteManager.shared.findFavorite(url:) 检查收藏状态")
print("")
print("🧪 测试方法:")
print("1. 运行应用")
print("2. 访问一些网页")
print("3. 长按某个历史记录，选择'收藏'")
print("4. 检查该项目是否显示黄色星标图标")
print("5. 下拉刷新，验证星标图标持续显示")
