//
//  EngineBootstrap.swift
//  SuperApp
//
//  Created on 2026-05-05.
//

import Foundation
import UIKit
import WebBridgeKit

@MainActor
public final class EngineBootstrap {
    public static let shared = EngineBootstrap()

    private var aiServer: AIHTTPServer?
    private var isInitialized = false

    private init() {}

    public func initialize(in window: UIWindow?) async {
        guard !isInitialized else { return }
        isInitialized = true

        print("🚀 [EngineBootstrap] Starting engine initialization...")

        await bootstrapTheme(in: window)

        print("  ✅ Cache Engine: using WebBridgeKit CacheManager")

        await bootstrapMessage()

        await bootstrapAI()

        await bootstrapSkills()

        print("  ✅ Bridge Engine: using WebBridgeKit HandlerRegistry")

        print("🚀 [EngineBootstrap] All engines initialized!")
    }

    // MARK: - Theme

    private func bootstrapTheme(in window: UIWindow?) async {
        let themeManager = ThemeManager.shared
        let theme = await themeManager.getTheme()

        if let window = window {
            await themeManager.applyToWindow(window)
        }

        await themeManager.observe { _ in
            Task { @MainActor [weak self] in
                guard let window = self?.getCurrentWindow() else { return }
                await themeManager.applyToWindow(window)
            }
        }

        print("  ✅ Theme Engine: initialized with '\(theme.name)' theme")
    }

    // MARK: - Message

    private func bootstrapMessage() async {
        let engine = MessageEngine.shared

        let persistentStore = UserDefaultsMessageStore(key: "SuperCache_Messages")
        await engine.setStore(persistentStore)
        print("  ✅ Message Engine: UserDefaults persistent store configured")

        let barkServerURL = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.day.app"
        let barkKey = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""

        if !barkKey.isEmpty {
            let barkChannel = BarkChannel(serverURL: barkServerURL, key: barkKey)
            await engine.registerChannel(barkChannel)
            print("  ✅ Message Engine: Bark channel registered (server: \(barkServerURL))")
        } else {
            print("  ⚠️ Message Engine: Bark channel skipped (no key configured)")
        }

        let webhookChannel = WebhookChannel()
        await engine.registerChannel(webhookChannel)
        print("  ✅ Message Engine: Webhook channel registered")

        let pipeline = MessageProcessorPipeline()
        await pipeline.register(MarkdownProcessor())
        await pipeline.register(LevelProcessor())
        await pipeline.register(BadgeProcessor())
        await pipeline.register(AutoCopyProcessor())
        await pipeline.register(ArchiveProcessor(store: persistentStore))
        await pipeline.register(MuteProcessor())
        await engine.setPipeline(pipeline)
        print("  ✅ Message Engine: Processor pipeline configured (6 processors)")

        await engine.setOnMessageReceived { storedMessage in
            Task { @MainActor in
                if let urlString = storedMessage.payload.targetURL, let url = URL(string: urlString) {
                    NotificationCenter.default.post(
                        name: .didReceivePushMessage,
                        object: nil,
                        userInfo: [
                            "url": url,
                            "title": storedMessage.payload.title,
                            "body": storedMessage.payload.body,
                            "source": storedMessage.payload.channel,
                            "appId": storedMessage.payload.targetAppId as Any,
                            "params": storedMessage.payload.userInfo as Any
                        ]
                    )
                }
            }
        }

        await engine.setOnRoute { payload, target in
            Task { @MainActor in
                self.handleRoute(payload: payload, target: target)
            }
        }

        let channelCount = await engine.getRegisteredChannels().count
        print("  ✅ Message Engine: initialized with \(channelCount) channels")
    }

    // MARK: - AI

    private func bootstrapAI() async {
        let server = AIHTTPServer(port: 8765)
        await server.registerDefaultRoutes()

        for tool in BuiltinAITools.all {
            await server.registerRoute(method: .POST, path: "/tools/\(tool.name)") { _ in
                return AIResponse.ok(["result": "executed"])
            }
        }

        self.aiServer = server

        do {
            try await server.start()
            print("  ✅ AI Engine: HTTP server started on port 8765")
        } catch {
            print("  ⚠️ AI Engine: Failed to start HTTP server: \(error)")
        }
    }

    // MARK: - Skills

    private func bootstrapSkills() async {
        let registry = SkillRegistry.shared

        for skill in BuiltinSkills.all {
            await registry.register(skill)
        }

        let skills = await registry.listAll()
        print("  ✅ Skills Engine: \(skills.count) skills registered")
    }

    // MARK: - Helpers

    private func getCurrentWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private func handleRoute(payload: MessagePayload, target: RouteTarget) {
        switch target.type {
        case .url:
            if let url = URL(string: target.destination) {
                var params = WebBrowserParams.from(url: url)
                if let mode = target.mode {
                    switch mode {
                    case "immersive": params = WebBrowserParams(displayMode: .immersive)
                    case "modal": params = WebBrowserParams(displayMode: .modal)
                    default: break
                    }
                }
                WebBrowserManager.shared.openBrowser(url: url, params: params)
            }
        case .appId:
            if let url = URL(string: target.destination) {
                WebBrowserManager.shared.openBrowser(url: url)
            }
        case .deeplink:
            if let url = URL(string: target.destination) {
                UIApplication.shared.open(url)
            }
        case .none:
            break
        }
    }

    public func shutdown() async {
        if let server = aiServer {
            await server.stop()
        }
        let engine = MessageEngine.shared
        await engine.stopAll()
        print("🛑 [EngineBootstrap] All engines stopped")
    }
}
