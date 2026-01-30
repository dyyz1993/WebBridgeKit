//
//  AppDelegate.swift
//  DemoApp
//
//  Created on 2026-01-16.
//

import UIKit
import WebBridgeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 初始化 WebBridgeKit
        WebBridgeKit.shared.initialize()

        // 创建窗口
        window = UIWindow(frame: UIScreen.main.bounds)

        // 创建根视图控制器（使用 TabBar）
        let tabBarController = TabBarController()

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        return true
    }
}
