//
//  URLInputView.swift
//  SuperApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import WebBridgeKit

/// URL 输入工具栏视图
/// 包含 URL 输入框、缓存开关和缓存按钮
class URLInputView: UIView {

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.cardBackground
        return view
    }()

    let urlTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = L10n.tr("common.open")
        textField.font = ThemeTokens.Typography.subheadline
        textField.textColor = ThemeColors.current.text
        textField.backgroundColor = ThemeColors.current.surface
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = .URL
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .go
        return textField
    }()

    private let cacheSwitchContainer: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.surface
        view.layer.cornerRadius = ThemeTokens.CornerRadius.md
        return view
    }()

    private let cacheLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("discover.action_sheet.cache")
        label.font = ThemeTokens.Typography.caption1
        label.textColor = ThemeColors.current.textSecondary
        return label
    }()

    let cacheSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = false
        switchControl.tintColor = ThemeTokens.Color.primary
        return switchControl
    }()

    let cacheButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.tr("discover.action_sheet.cache"), for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.callout
        button.backgroundColor = ThemeTokens.Color.primary
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.isEnabled = false
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = ThemeColors.current.divider
        return view
    }()

    // MARK: - Callbacks

    var onLoadURL: ((URL) -> Void)?
    var onCacheTap: (() -> Void)?
    var onCacheModeChange: ((Bool) -> Void)?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = ThemeColors.current.cardBackground

        addSubview(containerView)
        containerView.addSubview(urlTextField)
        containerView.addSubview(cacheSwitchContainer)
        containerView.addSubview(cacheButton)
        containerView.addSubview(separatorView)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(52)
        }

        // URL 输入框
        urlTextField.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalTo(cacheSwitchContainer.snp.left).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
        }

        // 缓存开关容器
        cacheSwitchContainer.snp.makeConstraints { make in
            make.right.equalTo(cacheButton.snp.left).offset(-8)
            make.centerY.equalToSuperview()
            make.width.equalTo(70)
            make.height.equalTo(36)
        }

        cacheSwitchContainer.addSubview(cacheLabel)
        cacheSwitchContainer.addSubview(cacheSwitch)

        cacheLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(6)
            make.centerY.equalToSuperview()
        }

        cacheSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-6)
            make.centerY.equalToSuperview()
        }

        // 缓存按钮
        cacheButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
            make.height.equalTo(36)
        }

        // 分隔线
        separatorView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }

    private func setupActions() {
        // URL 输入框回车
        urlTextField.rx.controlEvent(.editingDidEndOnExit)
            .subscribe(onNext: { [weak self] in
                self?.handleURLInput()
            })
            .disposed(by: rx)

        // 缓存按钮点击
        cacheButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.onCacheTap?()
            })
            .disposed(by: rx)

        // 缓存开关切换
        cacheSwitch.rx.value
            .skip(1)
            .subscribe(onNext: { [weak self] isEnabled in
                self?.onCacheModeChange?(isEnabled)
            })
            .disposed(by: rx)
    }

    // MARK: - Public Methods

    func setURL(_ url: URL) {
        urlTextField.text = url.absoluteString
    }

    func setCacheButtonEnabled(_ enabled: Bool) {
        cacheButton.isEnabled = enabled
        cacheButton.alpha = enabled ? 1.0 : 0.5
    }

    func setCacheButtonTitle(_ title: String) {
        cacheButton.setTitle(title, for: .normal)
    }

    func setCached(_ isCached: Bool) {
        if isCached {
            cacheButton.setTitle(L10n.tr("common.delete"), for: .normal)
            cacheButton.backgroundColor = ThemeTokens.Color.error
        } else {
            cacheButton.setTitle(L10n.tr("discover.action_sheet.cache"), for: .normal)
            cacheButton.backgroundColor = ThemeTokens.Color.primary
        }
    }

    // MARK: - Private Methods

    private func handleURLInput() {
        print("🟡 [URLInputView] handleURLInput called")
        guard let text = urlTextField.text,
              !text.isEmpty,
              let url = URL(string: text) else {
            print("🟡 [URLInputView] Invalid URL, returning")
            return
        }

        // 自动添加 http/https 前缀
        let finalURL: URL
        if let scheme = url.scheme, !scheme.isEmpty {
            finalURL = url
        } else if text.contains("https://") {
            finalURL = URL(string: "https://\(text)")!
        } else {
            finalURL = URL(string: "http://\(text)")!
        }

        print("🟡 [URLInputView] Calling onLoadURL callback with: \(finalURL.absoluteString)")
        onLoadURL?(finalURL)
        urlTextField.resignFirstResponder()
        print("🟡 [URLInputView] onLoadURL callback completed")
    }

    private let rx = DisposeBag()
}

// MARK: - Rx Extension

import RxCocoa
import RxSwift

extension URLInputView {
    var urlDidChange: Driver<String?> {
        return urlTextField.rx.text.asDriver()
    }
}
