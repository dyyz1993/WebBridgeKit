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

        #if !DREL_CONTAINER_ONLY
        print("[LAUNCH] [EngineBootstrap] Starting engine initialization...")
        #endif

        await bootstrapTheme(in: window)

        #if !DREL_CONTAINER_ONLY
        print("  [OK] Cache Engine: using WebBridgeKit CacheManager")
        #endif

        await bootstrapMessage()

        await bootstrapAI()

        await bootstrapSkills()

        await bootstrapCommandParser()

        #if !DREL_CONTAINER_ONLY
        print("  [OK] Bridge Engine: using WebBridgeKit HandlerRegistry")
        #endif

        #if !DREL_CONTAINER_ONLY
        print("[LAUNCH] [EngineBootstrap] All engines initialized!")
        #endif
    }

    // MARK: - Theme

    private func bootstrapTheme(in window: UIWindow?) async {
        let themeManager = ThemeManager.shared
        let storedMode = UserDefaults.standard.string(forKey: SettingsPreferenceKeys.appearanceMode)
            .flatMap(ThemeMode.init(rawValue:)) ?? .system

        await themeManager.apply(storedMode)
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

        #if !DREL_CONTAINER_ONLY
        print("  [OK] Theme Engine: initialized with '\(theme.name)' theme")
        #endif
    }

    // MARK: - Message

    private func bootstrapMessage() async {
        // Resurrect the push-encryption key on every launch: the keychain
        // original survives reinstalls, but the app-group mirrors the NSE
        // reads do not — heal them silently so encrypted pushes decrypt
        // without the user ever visiting the key page.
        _ = PushCipher.sharedKey()

        let engine = MessageEngine.shared

        let persistentStore = UserDefaultsMessageStore(key: "SuperCache_Messages")
        await engine.setStore(persistentStore)
        #if !DREL_CONTAINER_ONLY
        print("  [OK] Message Engine: UserDefaults persistent store configured")
        #endif

        let barkServerURL = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.drel.app"
        let barkKey = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""

        if !barkKey.isEmpty {
            let barkChannel = BarkChannel(serverURL: barkServerURL, key: barkKey)
            await engine.registerChannel(barkChannel)
            #if !DREL_CONTAINER_ONLY
            print("  [OK] Message Engine: Bark channel registered (server: \(barkServerURL))")
            #endif
        } else {
            #if !DREL_CONTAINER_ONLY
            print("  [WARN] Message Engine: Bark channel skipped (no key configured)")
            #endif
        }

        let webhookChannel = WebhookChannel()
        await engine.registerChannel(webhookChannel)
        #if !DREL_CONTAINER_ONLY
        print("  [OK] Message Engine: Webhook channel registered")
        #endif

        let pipeline = MessageProcessorPipeline()
        await pipeline.register(MarkdownProcessor())
        await pipeline.register(LevelProcessor())
        await pipeline.register(BadgeProcessor())
        await pipeline.register(AutoCopyProcessor())
        // ArchiveProcessor is deliberately NOT registered here: receive()
        // already persists the final StoredMessage with its full payload
        // identity (messageId, contentType, qr/otp fields). The processor's
        // own rebuild-and-save dropped that identity and hardcoded
        // channel="push", so every message was stored twice — one rich row
        // and one stripped plain row (the "应用推送 + PUSH推送" duplicates).
        await pipeline.register(MuteProcessor())
        await engine.setPipeline(pipeline)
        #if !DREL_CONTAINER_ONLY
        print("  [OK] Message Engine: Processor pipeline configured (5 processors)")
        #endif

        #if !DREL_CONTAINER_ONLY
        // The reusable development host keeps its legacy live-message hooks
        // for exercising HTML-app routing. Drel's Store build is different:
        // receiving a push only records it in the inbox. A user's notification
        // tap is the sole path that may open its URL (via PushRouter), which
        // prevents an incoming message, its tap response, and session restore
        // from each opening the same page.
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
        #else
        await engine.setOnMessageReceived(nil)
        await engine.setOnRoute(nil)
        #endif

        let channelCount = await engine.getRegisteredChannels().count
        #if !DREL_CONTAINER_ONLY
        print("  [OK] Message Engine: initialized with \(channelCount) channels")
        #endif
    }

    // MARK: - AI

    private func bootstrapAI() async {
        // The local AI HTTP server is a development tool. Running it in
        // production builds burns a socket, widens the attack surface
        // (0.0.0.0 binding), and its accept loop once spun a device at
        // 100% CPU — keep it out of TestFlight/App Store builds entirely.
        #if !DREL_CONTAINER_ONLY
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
            print("  [OK] AI Engine: HTTP server started on port 8765")
        } catch {
            print("  [WARN] AI Engine: Failed to start HTTP server: \(error)")
        }
        #endif
    }

    // MARK: - Skills

    private func bootstrapSkills() async {
        do {
            // Register all built-in skills with the unified SkillRegistry
            try await BuiltinSkills.registerAllWithRegistry()

            // AgentSchema now delegates to SkillRegistry.shared
            let capabilities = await AgentSchema.shared.getFullSchema()
            #if !DREL_CONTAINER_ONLY
            print("  [OK] Skills: \(capabilities.count) framework capabilities registered (via SkillRegistry)")
            #endif

            let categories = await AgentSchema.shared.getCategories()
            let tags = await AgentSchema.shared.getTags()
            #if !DREL_CONTAINER_ONLY
            print("  [OK] Skills: \(categories.count) categories, \(tags.count) tags indexed")
            #endif
        } catch {
            #if !DREL_CONTAINER_ONLY
            print("  [WARN] Skills: Failed to register capabilities - \(error)")
            #endif
        }
    }

    // MARK: - CommandParser

    private func bootstrapCommandParser() async {
        await CommandHandler.configureParserForAppCommands()
        #if !DREL_CONTAINER_ONLY
        print("  [OK] CommandParser Engine: initialized (clipboard monitoring active)")
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
                let parsed = WebBrowserParams.from(url: url)
                var params = WebBrowserParams(
                    displayMode: parsed.displayMode,
                    modalSize: parsed.modalSize,
                    showMask: parsed.showMask,
                    clickMaskCloses: parsed.clickMaskCloses,
                    showCloseButton: parsed.showCloseButton,
                    hideNavigationBar: parsed.hideNavigationBar,
                    hideStatusBar: parsed.hideStatusBar,
                    hideTabBar: parsed.hideTabBar,
                    disableSwipeBack: parsed.disableSwipeBack,
                    orientation: parsed.orientation,
                    allowJavaScriptClose: parsed.allowJavaScriptClose,
                    customTitle: parsed.customTitle,
                    debugMode: parsed.debugMode,
                    useManifestLoader: false
                )
                if let mode = target.mode {
                    switch mode {
                    case "immersive": params = WebBrowserParams(displayMode: .immersive, useManifestLoader: false)
                    case "modal": params = WebBrowserParams(displayMode: .modal, useManifestLoader: false)
                    default: break
                    }
                }
                WebBrowserManager.shared.openBrowser(url: url, params: params)
            }
        case .appId:
            // The appId must be resolved through the launch resolver to get
            // the trusted manifest's actual startURL — passing the raw appId
            // string as a URL produces an invalid scheme and a blank page.
            let resolver = HTMLAppLaunchResolver(
                trustRegistry: HTMLAppRuntimeCenter.shared.trustRegistry
            )
            do {
                let route = payload.route ?? "/"
                let launchTarget = try resolver.resolve(
                    appID: target.destination,
                    route: route
                )
                let params = WebBrowserParams(
                    displayMode: .immersive,
                    hideNavigationBar: true,
                    hideStatusBar: true,
                    hideTabBar: true,
                    payload: launchTarget.context.bridgePayload,
                    useManifestLoader: false,
                    preferCachedContent: launchTarget.offlineMode == .partial
                )
                WebBrowserManager.shared.openBrowser(
                    url: launchTarget.loaderURL,
                    params: params
                )
            } catch {
                StructuredLogger.shared.warning(
                    "[EngineBootstrap] Failed to resolve appId route: \(error.localizedDescription)",
                    category: .navigation
                )
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
        #if !DREL_CONTAINER_ONLY
        print("[EMOJI] [EngineBootstrap] All engines stopped")
        #endif
    }
}
