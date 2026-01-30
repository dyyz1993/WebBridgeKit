//
//  WKWebView+Rx.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-13.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import WebKit

// Framework imports

// MARK: - Reactive Extension for WKWebView

extension Reactive where Base: WKWebView {

    /// UI 委托代理
    var uiDelegate: DelegateProxy<WKWebView, WKUIDelegate> {
        return RxWKUIDelegateProxy.proxy(for: base)
    }

    // MARK: - Navigation Events

    /// 开始导航
    var didStart: Observable<WKNavigation> {
        return navigationDelegate.methodInvoked(#selector(WKNavigationDelegate.webView(_:didStartProvisionalNavigation:)))
            .map { parameters in
                return parameters[1] as! WKNavigation
            }
    }

    /// 导航完成
    var didFinish: Observable<WKNavigation> {
        return navigationDelegate.methodInvoked(#selector(WKNavigationDelegate.webView(_:didFinish:)))
            .map { parameters in
                return parameters[1] as! WKNavigation
            }
    }

    /// 导航失败
    var didFail: Observable<(WKNavigation, Error)> {
        return navigationDelegate.methodInvoked(#selector(WKNavigationDelegate.webView(_:didFail:withError:)))
            .map { parameters in
                return (parameters[1] as! WKNavigation, parameters[2] as! Error)
            }
    }

    // MARK: - Content Loading Events

    /// 内容开始加载（提交导航）
    var didCommit: Observable<WKNavigation> {
        return navigationDelegate.methodInvoked(#selector(WKNavigationDelegate.webView(_:didCommit:)))
            .map { parameters in
                return parameters[1] as! WKNavigation
            }
    }

    // MARK: - UI Delegate Events

    /// JavaScript alert
    var alert: Observable<(String, ((Bool) -> Void)?)> {
        return uiDelegate.methodInvoked(#selector(WKUIDelegate.webView(_:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:)))
            .map { parameters in
                let message = parameters[1] as? String ?? ""
                let handler = parameters[3] as? () -> Void
                return (message, handler.map { h in { _ in h() } })
            }
    }

    /// JavaScript confirm
    var confirm: Observable<(String, ((Bool) -> Void)?)> {
        return uiDelegate.methodInvoked(#selector(WKUIDelegate.webView(_:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:)))
            .map { parameters in
                let message = parameters[1] as? String ?? ""
                let handler = parameters[3] as? (Bool) -> Void
                return (message, handler)
            }
    }

    /// JavaScript prompt
    var prompt: Observable<(String, String?, ((String?) -> Void)?)> {
        return uiDelegate.methodInvoked(#selector(WKUIDelegate.webView(_:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:)))
            .map { parameters in
                let promptText = parameters[1] as? String ?? ""
                let defaultText = parameters[2] as? String
                let handler = parameters[4] as? (String?) -> Void
                return (promptText, defaultText, handler)
            }
    }

    // MARK: - Properties

    /// 加载进度
    var estimatedProgress: Observable<Double> {
        return base.rx.observe(\.estimatedProgress, options: [.initial, .new])
            .map { $0 }
            .asObservable()
    }

    /// 标题
    var title: Observable<String?> {
        return base.rx.observe(\.title, options: [.initial, .new])
            .map { $0 }
            .asObservable()
    }

    /// URL
    var url: Observable<URL?> {
        return base.rx.observe(\.url, options: [.initial, .new])
            .map { $0 }
            .asObservable()
    }

    /// 是否可以后退
    var canGoBack: Observable<Bool> {
        return base.rx.observe(\.canGoBack, options: [.initial, .new])
            .map { $0 }
            .asObservable()
    }

    /// 是否可以前进
    var canGoForward: Observable<Bool> {
        return base.rx.observe(\.canGoForward, options: [.initial, .new])
            .map { $0 }
            .asObservable()
    }

    /// 是否正在加载
    var isLoading: Observable<Bool> {
        return base.rx.observe(\.isLoading, options: [.initial, .new])
            .map { $0 }
            .asObservable()
    }

    // MARK: - Script Message Handler

    /// 接收脚本消息
    var scriptMessage: Observable<WKScriptMessage> {
        return base.rx.observe(\.configuration.userContentController, options: [.initial, .new])
            .flatMap { [weak base] _ -> Observable<WKScriptMessage> in
                guard let base = base else { return .empty() }
                return Observable.create { observer in
                    let handler = WKScriptMessageHandlerProxy(observer: observer)
                    base.configuration.userContentController.add(handler, name: "BarkBridge")
                    return Disposables.create {
                        base.configuration.userContentController.removeScriptMessageHandler(forName: "BarkBridge")
                    }
                }
            }
            .asObservable()
    }
}

// MARK: - UI Delegate Proxy

/// WKUIDelegate 代理
class RxWKUIDelegateProxy: DelegateProxy<WKWebView, WKUIDelegate>, WKUIDelegate, DelegateProxyType {

    /// Typed parent object.
    public weak private(set) var webView: WKWebView?

    /// - parameter webView: Parent object for delegate proxy.
    public init(webView: ParentObject) {
        self.webView = webView
        super.init(parentObject: webView, delegateProxy: RxWKUIDelegateProxy.self)
    }

    // Register known implementations
    public static func registerKnownImplementations() {
        self.register { RxWKUIDelegateProxy(webView: $0) }
    }

    public static func currentDelegate(for object: WKWebView) -> WKUIDelegate? {
        object.uiDelegate
    }

    public static func setCurrentDelegate(_ delegate: WKUIDelegate?, to object: WKWebView) {
        object.uiDelegate = delegate
    }
}

// MARK: - Script Message Handler Proxy

/// 脚本消息处理器代理
class WKScriptMessageHandlerProxy: NSObject, WKScriptMessageHandler {
    private let observer: AnyObserver<WKScriptMessage>

    init(observer: AnyObserver<WKScriptMessage>) {
        self.observer = observer
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        observer.onNext(message)
    }
}
