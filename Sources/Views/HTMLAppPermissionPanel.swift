//
//  HTMLAppPermissionPanel.swift
//  WebBridgeKit
//
//  Branded first-layer consent panel for HTML app native capabilities,
//  presented as a token-based bottom card. The iOS system prompt, if any,
//  only appears after the user accepts this panel.
//

import UIKit

extension HTMLAppCapability {
    /// Default Chinese display names; hosts can override per context if needed.
    public var localizedName: String {
        switch self {
        case .biometrics: return "身份验证"
        case .bluetooth: return "蓝牙"
        case .camera: return "相机"
        case .clipboard: return "剪贴板"
        case .contacts: return "通讯录"
        case .deviceControl: return "设备控制"
        case .displayStatus: return "投屏状态"
        case .fileExport: return "文件导出"
        case .fileImport: return "文件导入"
        case .location: return "位置"
        case .microphone: return "麦克风"
        case .motion: return "运动传感器"
        case .notification: return "通知"
        case .photoLibrary: return "照片图库"
        case .scan: return "扫码"
        case .share: return "分享"
        }
    }

    public var panelIcon: LucideIcon {
        switch self {
        case .biometrics: return .key
        case .bluetooth: return .network
        case .camera: return .camera
        case .clipboard: return .clipboard
        case .contacts: return .appBadge
        case .deviceControl: return .settings
        case .displayStatus: return .network
        case .fileExport: return .download
        case .fileImport: return .upload
        case .location: return .pin
        case .microphone: return .mic
        case .motion: return .compass
        case .notification: return .bell
        case .photoLibrary: return .image
        case .scan: return .scan
        case .share: return .share
        }
    }
}

public final class HTMLAppPermissionPanelPresenter: HTMLAppPermissionPromptPresenting {

    public init() {}

    private weak var activePanel: HTMLAppPermissionPanelViewController?

    @discardableResult
    public func presentPrompt(
        for context: HTMLAppPermissionPromptContext,
        completion: @escaping (HTMLAppPermissionPromptOutcome) -> Void
    ) -> Bool {
        guard let host = Self.topMostViewController() else {
            completion(.cancelled)
            return false
        }

        let panel = HTMLAppPermissionPanelViewController(context: context, onOutcome: completion)
        activePanel = panel
        panel.modalPresentationStyle = .overFullScreen
        panel.modalTransitionStyle = .crossDissolve
        host.present(panel, animated: true)
        return true
    }

    public func dismissActivePrompt() {
        guard let panel = activePanel else { return }
        panel.resolveAsCancelled()
    }

    static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

final class HTMLAppPermissionPanelViewController: UIViewController {

    private let context: HTMLAppPermissionPromptContext
    private let onOutcome: (HTMLAppPermissionPromptOutcome) -> Void
    private let onceLock = NSLock()
    private var hasResolved = false

    private let dimmingView = UIControl()
    private let cardView = UIView()
    private let grabberView = UIView()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let badgeLabel = UILabel()
    private let titleLabel = UILabel()
    private let reasonTitleLabel = UILabel()
    private let reasonLabel = UILabel()
    private let originLabel = UILabel()
    private let hintLabel = UILabel()
    private let buttonsStack = UIStackView()
    private var cardBottomConstraint: NSLayoutConstraint?

    init(context: HTMLAppPermissionPromptContext, onOutcome: @escaping (HTMLAppPermissionPromptOutcome) -> Void) {
        self.context = context
        self.onOutcome = onOutcome
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "wbk.pwa-permission.panel"
        setupDimming()
        setupCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .layoutChanged, argument: cardView)
    }

    // MARK: - Outcome

    func resolveAsCancelled() {
        resolve(.cancelled)
    }

    private func resolve(_ outcome: HTMLAppPermissionPromptOutcome) {
        onceLock.lock()
        let alreadyResolved = hasResolved
        hasResolved = true
        onceLock.unlock()
        guard !alreadyResolved else { return }

        dismiss(animated: true) { [onOutcome] in
            onOutcome(outcome)
        }
    }

    // MARK: - Setup

    private func setupDimming() {
        dimmingView.backgroundColor = ThemeTokens.Color.overlay
        dimmingView.addTarget(self, action: #selector(dimmingTapped), for: .touchUpInside)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.accessibilityLabel = "关闭权限申请"
        view.addSubview(dimmingView)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupCard() {
        cardView.backgroundColor = ThemeTokens.Color.surfaceElevated
        cardView.layer.cornerRadius = ThemeTokens.CornerRadius.xxl
        cardView.accessibilityIdentifier = "wbk.pwa-permission.card"
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(cardPanned(_:)))
        cardView.addGestureRecognizer(panGesture)

        grabberView.backgroundColor = ThemeTokens.Color.separator
        grabberView.layer.cornerRadius = 2.5
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(grabberView)

        let headerStack = makeHeaderStack()
        let reasonBlock = makeReasonBlock()
        let originRow = makeOriginRow()
        let hintRow = makeHintRow()
        buttonsStack.axis = .vertical
        buttonsStack.spacing = ThemeTokens.Spacing.sm
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(buttonsStack)
        appendScopeButtons()

        let denyButton = makeRejectButton()
        let contentStack = UIStackView(arrangedSubviews: [headerStack, reasonBlock, originRow, hintRow])
        contentStack.axis = .vertical
        contentStack.spacing = ThemeTokens.Spacing.md
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)
        cardView.addSubview(denyButton)

        let bottomAnchor = view.safeAreaLayoutGuide.bottomAnchor
        let cardBottom = cardView.bottomAnchor.constraint(equalTo: bottomAnchor)
        cardBottomConstraint = cardBottom

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ThemeTokens.Spacing.sm),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ThemeTokens.Spacing.sm),
            cardBottom,
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 440),

            grabberView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: ThemeTokens.Spacing.sm),
            grabberView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),

            contentStack.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: ThemeTokens.Spacing.md),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: ThemeTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -ThemeTokens.Spacing.lg),

            buttonsStack.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: ThemeTokens.Spacing.lg),
            buttonsStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            buttonsStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),

            denyButton.topAnchor.constraint(equalTo: buttonsStack.bottomAnchor, constant: ThemeTokens.Spacing.sm),
            denyButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            denyButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -ThemeTokens.Spacing.md),
            denyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func makeHeaderStack() -> UIStackView {
        badgeLabel.text = "原生能力申请"
        badgeLabel.font = ThemeTokens.Typography.badge
        badgeLabel.textColor = ThemeTokens.Color.primary
        badgeLabel.backgroundColor = ThemeTokens.Color.primarySoft
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.layer.masksToBounds = true

        iconContainer.backgroundColor = ThemeTokens.Color.iconBackground
        iconContainer.layer.cornerRadius = 10
        iconImageView.image = context.capability.panelIcon.image()
        iconImageView.tintColor = ThemeTokens.Color.primary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32)
        ])

        titleLabel.text = "允许「\(context.appName)」使用\(context.capability.localizedName)？"
        titleLabel.font = ThemeTokens.Typography.title3
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        let titleColumn = UIStackView(arrangedSubviews: [titleLabel, badgeLabel])
        titleColumn.axis = .vertical
        titleColumn.spacing = ThemeTokens.Spacing.xs

        let header = UIStackView(arrangedSubviews: [iconContainer, titleColumn])
        header.axis = .horizontal
        header.spacing = ThemeTokens.Spacing.md
        header.alignment = .top
        return header
    }

    private func makeReasonBlock() -> UIView {
        let container = UIView()
        container.backgroundColor = ThemeTokens.Color.backgroundSecondary
        container.layer.cornerRadius = ThemeTokens.CornerRadius.md

        reasonTitleLabel.text = "用途说明"
        reasonTitleLabel.font = ThemeTokens.Typography.caption
        reasonTitleLabel.textColor = ThemeTokens.Color.textTertiary

        reasonLabel.text = context.reason
        reasonLabel.font = ThemeTokens.Typography.body
        reasonLabel.textColor = ThemeTokens.Color.text
        reasonLabel.numberOfLines = 0
        reasonLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [reasonTitleLabel, reasonLabel])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: ThemeTokens.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -ThemeTokens.Spacing.md),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: ThemeTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -ThemeTokens.Spacing.md)
        ])
        return container
    }

    private func makeOriginRow() -> UIView {
        let label = UILabel()
        label.text = "来源  \(context.origin)"
        label.font = ThemeTokens.Typography.monospaceSmall
        label.textColor = ThemeTokens.Color.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    private func makeHintRow() -> UIView {
        let imageView = UIImageView(image: LucideIcon.info.image())
        imageView.tintColor = ThemeTokens.Color.textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.text = "允许后，iOS 可能仍会弹出系统权限确认。"
        hintLabel.font = ThemeTokens.Typography.caption
        hintLabel.textColor = ThemeTokens.Color.textTertiary
        hintLabel.numberOfLines = 0
        hintLabel.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [imageView, hintLabel])
        row.axis = .horizontal
        row.spacing = ThemeTokens.Spacing.sm
        row.alignment = .top
        imageView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        return row
    }

    /// All three scope options share identical visual weight. The recommended
    /// "while using" option gets a plain textual marker only; "always" must not
    /// be visually emphasized.
    private func appendScopeButtons() {
        let options: [(title: String, scope: HTMLAppPermissionScope, identifier: String)] = [
            ("仅这一次", .once, "wbk.pwa-permission.allow-once"),
            ("本次使用期间 · 推荐", .appSession, "wbk.pwa-permission.allow-session"),
            ("始终允许", .always, "wbk.pwa-permission.allow-always")
        ]
        for option in options {
            let button = UIButton(type: .system)
            button.setTitle(option.title, for: .normal)
            button.setTitleColor(ThemeTokens.Color.text, for: .normal)
            button.titleLabel?.font = ThemeTokens.Typography.buttonMedium
            button.backgroundColor = ThemeTokens.Color.backgroundSecondary
            button.layer.cornerRadius = ThemeTokens.CornerRadius.md
            button.layer.borderWidth = 1
            button.layer.borderColor = ThemeTokens.Color.border.cgColor
            button.accessibilityIdentifier = option.identifier
            button.accessibilityLabel = option.title
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
            button.addTarget(self, action: #selector(scopeButtonTapped(_:)), for: .touchUpInside)
            button.tag = scopeTag(option.scope)
            buttonsStack.addArrangedSubview(button)
        }
    }

    private func makeRejectButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("不允许", for: .normal)
        button.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.buttonMedium
        button.accessibilityIdentifier = "wbk.pwa-permission.deny"
        button.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)
        return button
    }

    private func scopeTag(_ scope: HTMLAppPermissionScope) -> Int {
        switch scope {
        case .once: return 0
        case .appSession: return 1
        case .always: return 2
        }
    }

    // MARK: - Actions

    @objc private func dimmingTapped() {
        resolve(.cancelled)
    }

    @objc private func rejectTapped() {
        resolve(.cancelled)
    }

    @objc private func scopeButtonTapped(_ sender: UIButton) {
        let scope: HTMLAppPermissionScope
        switch sender.tag {
        case 0: scope = .once
        case 1: scope = .appSession
        default: scope = .always
        }
        resolve(.authorized(scope: scope))
    }

    @objc private func cardPanned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: view).y
            if translation > 0 {
                cardBottomConstraint?.constant = translation
            }
        case .ended, .cancelled:
            let translation = gesture.translation(in: view).y
            if translation > 120, gesture.state == .ended {
                resolve(.cancelled)
            } else {
                cardBottomConstraint?.constant = 0
                UIView.animate(withDuration: 0.25) {
                    self.view.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }
}
