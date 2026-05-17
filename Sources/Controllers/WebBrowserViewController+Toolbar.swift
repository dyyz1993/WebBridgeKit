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
            make.width.equalTo(60)
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

        navigationItem.leftBarButtonItems = [closeBtn]
        navigationItem.rightBarButtonItem = menuBtn

        backBtn.isEnabled = false
        backBtn.tintColor = .clear
    }

    @objc func closeButtonTapped() {
        dismissOrPop()
    }

    @objc func backButtonTapped() {
        webView.goBack()
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
    }

    func setupActions() {
        // Buttons use target-action pattern in configureNavigationBar()
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
