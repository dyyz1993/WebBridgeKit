//
//  WebBrowserViewController+Toolbar.swift
//  WebBridgeKit
//
//  Navigation bar configuration, toolbar buttons, constraints, and gestures
//

import SnapKit
import UIKit

extension WebBrowserViewController {

    func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never

        titleContainerView.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        titleContainerView.addSubview(titleLabel)
        titleContainerView.addSubview(cacheStatusLabel)

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalToSuperview().offset(-20)
            make.left.greaterThanOrEqualToSuperview()
        }

        cacheStatusLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(6)
            make.centerY.equalTo(titleLabel)
            make.right.lessThanOrEqualToSuperview()
            make.width.greaterThanOrEqualTo(34)
            make.height.equalTo(18)
        }

        navigationItem.titleView = titleContainerView

        let closeBtn = UIBarButtonItem(
            image: LucideIcon.xmark.image(),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeBtn.tintColor = ThemeTokens.Color.text
        closeBtn.accessibilityIdentifier = "browserManager.closeButton"
        closeBtn.accessibilityLabel = "关闭"
        self.closeBarButton = closeBtn

        let menuBtn = UIBarButtonItem(
            image: LucideIcon.ellipsis.image(),
            style: .plain,
            target: self,
            action: #selector(menuButtonTapped)
        )
        menuBtn.tintColor = ThemeTokens.Color.text
        menuBtn.accessibilityIdentifier = "browserManager.menuButton"
        menuBtn.accessibilityLabel = "更多菜单"
        self.menuBarButton = menuBtn

        let backBtn = UIBarButtonItem(
            image: LucideIcon.chevronLeft.image(),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backBtn.tintColor = ThemeTokens.Color.text
        backBtn.accessibilityIdentifier = "browserManager.backButton"
        backBtn.accessibilityLabel = "返回"
        self.backBarButton = backBtn

        // 返回按钮常驻（懒加载 custom:// 页的历史由 App 层维护，canGoBack
        // KVO 不可靠；反复换 items 会被其他路径重置，只用 enable/tint 控制）
        navigationItem.leftBarButtonItems = [backBtn, closeBtn]
        navigationItem.rightBarButtonItem = menuBtn

        backBtn.isEnabled = false
        backBtn.tintColor = .clear
    }

    @objc func closeButtonTapped() {
        dismissOrPop()
    }

    @objc func backButtonTapped() {
        if webView.canGoBack {
            webView.goBack()
            return
        }
        // custom:// 页间导航没有 WebKit 后退历史，走 App 层栈：
        // 弹掉当前页，加载上一页（didFinish 里的去重保证栈不回涨）。
        guard customNavStack.count > 1 else { return }
        customNavStack.removeLast()
        if let previous = customNavStack.last,
           let scheme = previous.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            // 直载（不走 smartLoad 管线）：http 文档加载会重置 App 层栈，
            // 之后的页内跳转回到 WebKit 原生历史，语义一致且无竞态。
            loadURLDirect(previous)
        } else {
            // 根条目异常（空路径污染）时兜底：收起浏览器回宿主页面
            customNavStack.removeAll()
            closeButtonTapped()
        }
    }

    @objc func menuButtonTapped() {
        showMenu()
    }

    func setupConstraints() {
        let safeAreaLayoutGuide = view.safeAreaLayoutGuide

        webView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.bottom.equalToSuperview()
        }

        progressView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.right.equalToSuperview()
            make.height.equalTo(2)
        }

        immersiveMenuButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(ThemeTokens.Spacing.sm)
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).inset(ThemeTokens.Spacing.md)
            make.size.equalTo(ThemeTokens.ComponentContract.TapTarget.minimumHeight)
        }

    }

    func setupActions() {
        // Bar buttons use target-action in configureNavigationBar().
    }

    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        tapGesture = tap
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard hideNavBar else { return }

        let location = gesture.location(in: view)
        if location.y > view.bounds.height - 100 {
            dismissOrPop()
        }
    }

}
