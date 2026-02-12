//
//  ActionSheetView.swift
//  DemoApp
//
//  Created on 2025-01-29.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit

/// 操作面板视图
/// 底部弹出的操作选择面板
class ActionSheetView: UIView {

    // MARK: - UI Components

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 1
        stack.backgroundColor = UIColor.separator
        return stack
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        button.backgroundColor = UIColor.systemBackground
        return button
    }()

    // MARK: - Properties

    private var actions: [(title: String, style: UIAlertAction.Style, action: () -> Void)] = []

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(backgroundView)
        addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(stackView)
        containerView.addSubview(cancelButton)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.lessThanOrEqualTo(400)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.right.equalToSuperview()
            make.height.equalTo(30)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
        }

        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            make.height.equalTo(56)
            make.bottom.equalToSuperview().offset(-34)
        }

        cancelButton.setTitle("取消", for: .normal)
        // Set accessibility identifier for testing
        cancelButton.accessibilityIdentifier = "actionsheet.取消"
        cancelButton.accessibilityLabel = "取消"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tapGesture)
    }

    // MARK: - Configure

    func configure(title: String? = nil, actions: [(title: String, style: UIAlertAction.Style, action: () -> Void)]) {
        self.actions = actions

        if let title = title {
            titleLabel.text = title
            titleLabel.isHidden = false
        } else {
            titleLabel.isHidden = true
        }

        // 清空旧的按钮
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 添加新的按钮
        for action in actions {
            let button = UIButton(type: .system)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .regular)
            button.backgroundColor = UIColor.systemBackground
            button.setTitle(action.title, for: .normal)
            button.tag = actions.firstIndex(where: { $0.title == action.title }) ?? 0

            // 根据样式设置颜色
            switch action.style {
            case .destructive:
                button.setTitleColor(UIColor.systemRed, for: .normal)
            case .cancel:
                button.setTitleColor(UIColor.systemBlue, for: .normal)
            default:
                button.setTitleColor(UIColor.systemBlue, for: .normal)
            }

            // Set accessibility identifier for testing
            button.accessibilityIdentifier = "actionsheet.\(action.title)"
            button.accessibilityLabel = action.title

            button.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            button.snp.makeConstraints { make in
                make.height.equalTo(56)
            }

            stackView.addArrangedSubview(button)
        }
    }

    // MARK: - Show/Dismiss

    func show(in view: UIView) {
        self.frame = view.bounds
        view.addSubview(self)

        // 初始状态
        backgroundView.alpha = 0
        containerView.transform = CGAffineTransform(translationX: 0, y: containerView.bounds.height)

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.backgroundView.alpha = 1
            self.containerView.transform = .identity
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.backgroundView.alpha = 0
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.containerView.bounds.height)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    // MARK: - Actions

    @objc private func backgroundTapped() {
        dismiss()
    }

    @objc private func cancelTapped() {
        dismiss()
    }

    @objc private func actionTapped(_ sender: UIButton) {
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.actions[sender.tag].action()
        }
    }
}
