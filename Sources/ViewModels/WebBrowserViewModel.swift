//
//  WebBrowserViewModel.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import Foundation
import RxCocoa
import RxSwift
import UIKit
import WebKit

/// 浏览器 ViewModel
public class WebBrowserViewModel: ViewModel {

    // MARK: - Input & Output

    public struct Input {
        let loadURL: Driver<URL>
        let goBack: Driver<Void>
        let goForward: Driver<Void>
        let reload: Driver<Void>
        let stopLoading: Driver<Void>
        let bookmarkToggle: Driver<Void>
        let menuTap: Driver<Void>
    }

    public struct Output {
        let title: Driver<String?>
        let url: Driver<URL?>
        let canGoBack: Driver<Bool>
        let canGoForward: Driver<Bool>
        let isLoading: Driver<Bool>
        let estimatedProgress: Driver<Double>
        let showMenu: Driver<Void>
        let error: Driver<String>
    }

    // MARK: - Properties

    private let webView: WKWebView
    private let jsBridge: WebJavaScriptBridge
    public let initialURL: URL?
    public let disposeBag = DisposeBag()

    // MARK: - Relay

    private let titleRelay = BehaviorRelay<String?>(value: nil)
    private let urlRelay = BehaviorRelay<URL?>(value: nil)
    private let isLoadingRelay = BehaviorRelay<Bool>(value: false)
    private let showMenuRelay = PublishRelay<Void>()
    private let errorRelay = PublishRelay<String>()

    // MARK: - Initialization

    public init(url: URL? = nil) {
        self.initialURL = url

        // 创建 WebView 配置和 Bridge
        let (configuration, bridge) = WKWebViewConfiguration.createDefault()
        self.jsBridge = bridge

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.allowsBackForwardNavigationGestures = true

        super.init()

        // 设置 bridge 的 webView
        self.jsBridge.setWebView(self.webView)

        // 设置初始 URL
        if let url = url {
            self.urlRelay.accept(url)
        }
    }

    // MARK: - Transform

    public func transform(input: Input) -> Output {

        // MARK: - 导航事件绑定

        // 标题更新
        webView.rx.title
            .bind(to: titleRelay)
            .disposed(by: disposeBag)

        // URL 变化
        webView.rx.url
            .bind(to: urlRelay)
            .disposed(by: disposeBag)

        // 加载状态
        webView.rx.didStart
            .subscribe(onNext: { [weak self] _ in
                self?.isLoadingRelay.accept(true)
            })
            .disposed(by: disposeBag)

        webView.rx.didFinish
            .subscribe(onNext: { [weak self] _ in
                self?.isLoadingRelay.accept(false)
            })
            .disposed(by: disposeBag)

        webView.rx.didFail
            .subscribe(onNext: { [weak self] (_, error) in
                self?.isLoadingRelay.accept(false)
                self?.errorRelay.accept(error.localizedDescription)
            })
            .disposed(by: disposeBag)

        // MARK: - 用户操作

        // 加载 URL
        input.loadURL
            .drive(onNext: { [weak self] url in
                self?.loadURL(url)
            })
            .disposed(by: disposeBag)

        // 后退
        input.goBack
            .drive(onNext: { [weak self] in
                self?.webView.goBack()
            })
            .disposed(by: disposeBag)

        // 前进
        input.goForward
            .drive(onNext: { [weak self] in
                self?.webView.goForward()
            })
            .disposed(by: disposeBag)

        // 刷新
        input.reload
            .drive(onNext: { [weak self] in
                self?.webView.reload()
            })
            .disposed(by: disposeBag)

        // 停止加载
        input.stopLoading
            .drive(onNext: { [weak self] in
                self?.webView.stopLoading()
            })
            .disposed(by: disposeBag)

        // 菜单
        input.menuTap
            .drive(onNext: { [weak self] in
                self?.showMenuRelay.accept(())
            })
            .disposed(by: disposeBag)

        // MARK: - Output

        return Output(
            title: titleRelay.asDriver(onErrorJustReturn: nil),
            url: urlRelay.asDriver(onErrorJustReturn: nil),
            canGoBack: webView.rx.canGoBack.asDriver(onErrorJustReturn: false),
            canGoForward: webView.rx.canGoForward.asDriver(onErrorJustReturn: false),
            isLoading: isLoadingRelay.asDriver(onErrorJustReturn: false),
            estimatedProgress: webView.rx.estimatedProgress.asDriver(onErrorJustReturn: 0),
            showMenu: showMenuRelay.asDriver(onErrorJustReturn: ()),
            error: errorRelay.asDriver(onErrorJustReturn: "")
        )
    }

    // MARK: - Private Methods

    private func loadURL(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    // MARK: - Public Methods

    /// 获取 WebView（用于 ViewController）
    public func getWebView() -> WKWebView {
        return webView
    }
}

// MARK: - WKWebViewConfiguration Extension

extension WKWebViewConfiguration {
    /// 创建默认配置，返回配置和 bridge
    internal static func createDefault() -> (WKWebViewConfiguration, WebJavaScriptBridge) {
        let config = WKWebViewConfiguration()

        // 1. 数据存储配置
        config.websiteDataStore = WKWebsiteDataStore.default()

        // 2. 用户内容控制器（JS 桥接）
        let userContentController = WKUserContentController()

        // 注入 WebBridge.js 脚本
        if let scriptPath = Bundle.main.path(forResource: "WebBridge", ofType: "js"),
           let script = try? String(contentsOfFile: scriptPath) {
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }

        // 注册消息处理器
        let bridge = WebJavaScriptBridge()
        userContentController.add(bridge, name: "BarkBridge")

        config.userContentController = userContentController

        // 3. 偏好设置
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences

        // 4. 媒体播放策略
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        // 5. 注册自定义 Scheme Handler
        ManifestURLSchemeHandler.register(to: config, scheme: "custom")
        ManifestURLSchemeHandler.register(to: config, scheme: "wb-resource")

        return (config, bridge)
    }
}
