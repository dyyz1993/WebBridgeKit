//
//  URLInputView.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// URL 输入工具栏视图
/// 包含 URL 输入框、缓存开关和缓存按钮
class URLInputView: UIView {

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        return view
    }()

    let urlTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "输入或粘贴网址"
        textField.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = .label
        textField.backgroundColor = .tertiarySystemBackground
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
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 8
        return view
    }()

    private let cacheLabel: UILabel = {
        let label = UILabel()
        label.text = "缓存"
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    let cacheSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = false
        switchControl.tintColor = .systemBlue
        return switchControl
    }()

    let cacheButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("缓存", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.isEnabled = false
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
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
        backgroundColor = .secondarySystemBackground

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
            cacheButton.setTitle("删除", for: .normal)
            cacheButton.backgroundColor = .systemRed
        } else {
            cacheButton.setTitle("缓存", for: .normal)
            cacheButton.backgroundColor = .systemBlue
        }
    }

    // MARK: - Private Methods

    private func handleURLInput() {
        guard let text = urlTextField.text,
              !text.isEmpty,
              let url = URL(string: text) else {
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

        onLoadURL?(finalURL)
        urlTextField.resignFirstResponder()
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
