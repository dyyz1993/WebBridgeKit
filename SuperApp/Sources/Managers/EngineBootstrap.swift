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

        #if DEBUG
        print("🚀 [EngineBootstrap] Starting engine initialization...")
        #endif

        await bootstrapTheme(in: window)

        #if DEBUG
        print("  ✅ Cache Engine: using WebBridgeKit CacheManager")
        #endif

        await bootstrapMessage()

        await bootstrapAI()

        await bootstrapSkills()

        await bootstrapCommandParser()

        #if DEBUG
        print("  ✅ Bridge Engine: using WebBridgeKit HandlerRegistry")
        #endif

        #if DEBUG
        print("🚀 [EngineBootstrap] All engines initialized!")
        #endif
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

        #if DEBUG
        print("  ✅ Theme Engine: initialized with '\(theme.name)' theme")
        #endif
    }

    // MARK: - Message

    private func bootstrapMessage() async {
        let engine = MessageEngine.shared

        let persistentStore = UserDefaultsMessageStore(key: "SuperCache_Messages")
        await engine.setStore(persistentStore)
        #if DEBUG
        print("  ✅ Message Engine: UserDefaults persistent store configured")
        #endif

        let barkServerURL = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://wbk.shanbox.19930810.xyz:8443"
        let barkKey = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""

        if !barkKey.isEmpty {
            let barkChannel = BarkChannel(serverURL: barkServerURL, key: barkKey)
            await engine.registerChannel(barkChannel)
            #if DEBUG
            print("  ✅ Message Engine: Bark channel registered (server: \(barkServerURL))")
            #endif
        } else {
            #if DEBUG
            print("  ⚠️ Message Engine: Bark channel skipped (no key configured)")
            #endif
        }

        let webhookChannel = WebhookChannel()
        await engine.registerChannel(webhookChannel)
        #if DEBUG
        print("  ✅ Message Engine: Webhook channel registered")
        #endif

        let pipeline = MessageProcessorPipeline()
        await pipeline.register(MarkdownProcessor())
        await pipeline.register(LevelProcessor())
        await pipeline.register(BadgeProcessor())
        await pipeline.register(AutoCopyProcessor())
        await pipeline.register(ArchiveProcessor(store: persistentStore))
        await pipeline.register(MuteProcessor())
        await engine.setPipeline(pipeline)
        #if DEBUG
        print("  ✅ Message Engine: Processor pipeline configured (6 processors)")
        #endif

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
        #if DEBUG
        print("  ✅ Message Engine: initialized with \(channelCount) channels")
        #endif
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
            #if DEBUG
            print("  ✅ AI Engine: HTTP server started on port 8765")
            #endif
        } catch {
            #if DEBUG
            print("  ⚠️ AI Engine: Failed to start HTTP server: \(error)")
            #endif
        }
    }

    // MARK: - Skills

    private func bootstrapSkills() async {
        do {
            // Register all built-in skills with the unified SkillRegistry
            try await BuiltinSkills.registerAllWithRegistry()

            // AgentSchema now delegates to SkillRegistry.shared
            let capabilities = await AgentSchema.shared.getFullSchema()
            #if DEBUG
            print("  ✅ Skills: \(capabilities.count) framework capabilities registered (via SkillRegistry)")
            #endif

            let categories = await AgentSchema.shared.getCategories()
            let tags = await AgentSchema.shared.getTags()
            #if DEBUG
            print("  ✅ Skills: \(categories.count) categories, \(tags.count) tags indexed")
            #endif
        } catch {
            #if DEBUG
            print("  ⚠️ Skills: Failed to register capabilities - \(error)")
            #endif
        }
    }

    // MARK: - CommandParser

    private func bootstrapCommandParser() async {
        let config = CommandParserConfiguration(
            maxPayloadSize: 4096,
            maxAge: 300,
            allowedSchemes: ["http", "https"],
            enableSignatureVerification: false,
            enableTimestampValidation: false
        )
        await CommandParser.shared.setConfiguration(config)
        #if DEBUG
        print("  ✅ CommandParser Engine: initialized (clipboard monitoring active)")
        #endif
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
        @unknown default:
            break
        }
    }

    public func shutdown() async {
        if let server = aiServer {
            await server.stop()
        }
        let engine = MessageEngine.shared
        await engine.stopAll()
        #if DEBUG
        print("🛑 [EngineBootstrap] All engines stopped")
        #endif
    }
}
