//
//  PWAPermissionCenterViewController.swift
//  SuperApp
//
//  PWA permission management page: WebBridgeKit authorization scopes plus iOS
//  system status per capability, with revocation and the iOS Settings handoff.
//

import UIKit
import WebBridgeKit

final class PWAPermissionCenterViewController: UIViewController {

    private struct RowModel {
        let capability: HTMLAppCapability
        let grant: HTMLAppPermissionGrant?
        let systemStatus: HTMLAppCapabilityResult.Status
        let section: Section

        enum Section: Int, CaseIterable {
            case needsAttention
            case allowed
            case unused

            var title: String {
                switch self {
                case .needsAttention: return "需要处理"
                case .allowed: return "已允许"
                case .unused: return "尚未使用"
                }
            }
        }

        var scopeText: String {
            switch grant?.scope {
            case .once: return "仅这一次"
            case .appSession: return "本次使用期间"
            case .always: return "始终允许"
            case nil: return "尚未请求"
            }
        }

        var systemText: String {
            switch systemStatus {
            case .granted: return "已允许"
            case .denied: return "已被拒绝"
            case .restricted: return "受限制"
            case .requiresSettings: return "需在系统设置开启"
            case .notDetermined: return "未询问"
            case .unavailable: return "不可用"
            }
        }
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let appID: String
    private let runtime = HTMLAppRuntimeCenter.shared
    private let gatewayRegistry = HTMLAppGatewayRegistry()
    private var rows: [RowModel] = []
    private var manifest: HTMLAppManifest?

    init(appID: String) {
        self.appID = appID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeTokens.Color.background
        title = "权限与原生能力"
        navigationItem.largeTitleDisplayMode = .never

        // Keep the runtime's gateway identity in sync with the active gateway
        // so grants never carry across a gateway switch.
        if let active = gatewayRegistry.activeGateway() {
            runtime.gatewayIdentity = "\(active.id)#\(active.publicKeyID ?? "unsigned")"
        }

        setupLayout()
        reload()
    }

    // MARK: - Data

    private func reload() {
        guard let manifest = runtime.trustRegistry.manifest(for: appID) else {
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            contentStack.addArrangedSubview(makeEmptyLabel(text: "未找到该应用的注册信息。"))
            return
        }
        self.manifest = manifest

        guard let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: URL(string: manifest.startURL) ?? URL(fileURLWithPath: "/")),
              let subject = runtime.subject(appID: appID, origin: origin) else {
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            contentStack.addArrangedSubview(makeEmptyLabel(text: "尚未配置网关，无法管理权限。"))
            return
        }

        let grants = runtime.permissionLedger.grants(for: subject)
        rows = manifest.capabilities.map { capability in
            let grant = grants.first { $0.capability == capability }
            let systemStatus = runtime.systemPermissionAdapter.authorizationStatus(for: capability)
            let section: RowModel.Section
            if grant != nil && systemStatus == .denied {
                // WebBridgeKit allowed it, but iOS refuses: needs the Settings handoff.
                section = .needsAttention
            } else if grant != nil && systemStatus == .granted {
                section = .allowed
            } else if grant != nil {
                section = .needsAttention
            } else if systemStatus == .denied {
                // 未授权但 iOS 系统已拒绝：用户需要知道去系统设置开启
                section = .needsAttention
            } else {
                section = .unused
            }
            return RowModel(capability: capability, grant: grant, systemStatus: systemStatus, section: section)
        }

        render(manifest: manifest, subject: subject)
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentStack.axis = .vertical
        contentStack.spacing = ThemeTokens.Spacing.sm
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: ThemeTokens.Spacing.md),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -ThemeTokens.Spacing.xl),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: ThemeTokens.Spacing.screenHorizontal),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -ThemeTokens.Spacing.screenHorizontal)
        ])
    }

    private func render(manifest: HTMLAppManifest, subject: HTMLAppPermissionSubject) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(makeHeaderCard(manifest: manifest))

        // 只展示已授权与需处理项；「尚未使用」纯噪音，用户明确要求不显示
        let visibleSections: [RowModel.Section] = [.needsAttention, .allowed]
        for section in visibleSections {
            let sectionRows = rows.filter { $0.section == section }
            guard !sectionRows.isEmpty else { continue }
            contentStack.addArrangedSubview(makeSectionTitle(section.title, count: sectionRows.count))
            for row in sectionRows {
                contentStack.addArrangedSubview(makeCapabilityCard(row: row, subject: subject))
            }
        }

        if rows.contains(where: { $0.grant != nil }) {
            contentStack.addArrangedSubview(makeRevokeAllButton(subject: subject))
        }
    }

    private func makeHeaderCard(manifest: HTMLAppManifest) -> UIView {
        let card = ThemeCard()
        card.accessibilityIdentifier = "pwa-permission.headerCard"

        let icon = UIImageView(image: WebBridgeKitBrand.image ?? LucideIcon.appFill.image())
        icon.tintColor = ThemeTokens.Color.primary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = manifest.name
        nameLabel.font = ThemeTokens.Typography.cardTitle
        nameLabel.textColor = ThemeTokens.Color.text
        nameLabel.adjustsFontForContentSizeCategory = true

        let originLabel = UILabel()
        originLabel.text = manifest.allowedOrigins.first ?? manifest.startURL
        originLabel.font = ThemeTokens.Typography.monospaceSmall
        originLabel.textColor = ThemeTokens.Color.textSecondary
        originLabel.numberOfLines = 0
        originLabel.textAlignment = .natural
        originLabel.lineBreakMode = .byWordWrapping
        originLabel.adjustsFontForContentSizeCategory = true

        let noteLabel = UILabel()
        noteLabel.text = "授权只对该应用生效，可随时撤销；系统权限仍由 iOS 管理。"
        noteLabel.font = ThemeTokens.Typography.caption
        noteLabel.textColor = ThemeTokens.Color.textTertiary
        noteLabel.numberOfLines = 0
        noteLabel.adjustsFontForContentSizeCategory = true

        let titleColumn = UIStackView(arrangedSubviews: [nameLabel, originLabel])
        titleColumn.axis = .vertical
        titleColumn.spacing = ThemeTokens.Spacing.xs

        let header = UIStackView(arrangedSubviews: [icon, titleColumn])
        header.axis = .horizontal
        header.spacing = ThemeTokens.Spacing.md
        header.alignment = .top

        // note 与 name/origin 左对齐（缩进 = 图标宽度 + 间距），不再从卡片左缘开始
        let noteWrapper = UIStackView(arrangedSubviews: [UIView(), noteLabel])
        noteWrapper.axis = .horizontal
        noteWrapper.spacing = 0
        let iconSpacing = ThemeTokens.Spacing.md
        let iconSize: CGFloat = 32
        noteWrapper.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0, leading: iconSize + iconSpacing, bottom: 0, trailing: 0
        )
        noteWrapper.isLayoutMarginsRelativeArrangement = true
        noteWrapper.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 0).isActive = true

        let stack = UIStackView(arrangedSubviews: [header, noteWrapper])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ThemeTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ThemeTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ThemeTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ThemeTokens.Spacing.lg),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28)
        ])
        return card
    }

    private func makeSectionTitle(_ title: String, count: Int) -> UIView {
        let label = UILabel()
        label.text = "\(title)（\(count)）"
        label.font = ThemeTokens.Typography.caption
        label.textColor = ThemeTokens.Color.textTertiary
        label.accessibilityIdentifier = "pwa-permission.section.\(title)"
        return label
    }

    private func makeCapabilityCard(row: RowModel, subject: HTMLAppPermissionSubject) -> UIView {
        let card = ThemeCard()
        card.accessibilityIdentifier = "pwa-permission.capability.\(row.capability.rawValue)"

        let icon = UIImageView(image: row.capability.panelIcon.image())
        icon.tintColor = ThemeTokens.Color.textSecondary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = "\(row.capability.localizedName) · \(row.scopeText)"
        nameLabel.font = ThemeTokens.Typography.rowTitle
        nameLabel.textColor = ThemeTokens.Color.text
        nameLabel.adjustsFontForContentSizeCategory = true

        let systemLabel = UILabel()
        systemLabel.text = "iOS 系统：\(row.systemText)"
        systemLabel.font = ThemeTokens.Typography.caption
        systemLabel.textColor = row.systemStatus == .denied || row.systemStatus == .restricted
            ? ThemeTokens.Color.warning
            : ThemeTokens.Color.textSecondary
        systemLabel.adjustsFontForContentSizeCategory = true

        let textColumn = UIStackView(arrangedSubviews: [nameLabel, systemLabel])
        textColumn.axis = .vertical
        textColumn.spacing = ThemeTokens.Spacing.xs

        let actionButton = UIButton(type: .system)
        actionButton.titleLabel?.font = ThemeTokens.Typography.buttonMedium
        actionButton.heightAnchor.constraint(equalToConstant: 34)
        if row.grant != nil {
            actionButton.setTitle("撤销", for: .normal)
            actionButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
            actionButton.accessibilityIdentifier = "pwa-permission.revoke.\(row.capability.rawValue)"
            actionButton.addTarget(self, action: #selector(revokeTapped(_:)), for: .touchUpInside)
            actionButton.tag = row.capability.hashValue
            actionButton.accessibilityLabel = "撤销\(row.capability.localizedName)"
        } else if row.systemStatus == .denied {
            actionButton.setTitle("前往系统设置", for: .normal)
            actionButton.setTitleColor(ThemeTokens.Color.primary, for: .normal)
            actionButton.accessibilityIdentifier = "pwa-permission.settings.\(row.capability.rawValue)"
            actionButton.addTarget(self, action: #selector(systemSettingsTapped), for: .touchUpInside)
        } else {
            actionButton.setTitle("尚未请求", for: .normal)
            actionButton.setTitleColor(ThemeTokens.Color.textTertiary, for: .normal)
            actionButton.isEnabled = false
        }

        // Map hashValue back to the capability safely at tap time.
        if row.grant != nil {
            actionButton.accessibilityValue = row.capability.rawValue
        }

        let row0 = UIStackView(arrangedSubviews: [icon, textColumn, actionButton])
        row0.axis = .horizontal
        row0.spacing = ThemeTokens.Spacing.md
        row0.alignment = .center
        // 文字列填满中间空间：标题/状态明确左对齐，按钮明确靠右
        textColumn.translatesAutoresizingMaskIntoConstraints = false
        textColumn.setContentHuggingPriority(.required - 1, for: .horizontal)
        textColumn.setContentCompressionResistancePriority(.required - 1, for: .horizontal)

        row0.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row0)
        NSLayoutConstraint.activate([
            row0.topAnchor.constraint(equalTo: card.topAnchor, constant: ThemeTokens.Spacing.md),
            row0.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ThemeTokens.Spacing.md),
            row0.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ThemeTokens.Spacing.lg),
            row0.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ThemeTokens.Spacing.sm),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])
        return card
    }

    private func makeRevokeAllButton(subject: HTMLAppPermissionSubject) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("撤销全部授权", for: .normal)
        button.setTitleColor(ThemeTokens.Color.error, for: .normal)
        button.titleLabel?.font = ThemeTokens.Typography.buttonMedium
        button.backgroundColor = ThemeTokens.Color.errorSoft
        button.layer.cornerRadius = ThemeTokens.CornerRadius.md
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.accessibilityIdentifier = "pwa-permission.revokeAll"
        button.addTarget(self, action: #selector(revokeAllTapped), for: .touchUpInside)
        return button
    }

    private func makeEmptyLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = ThemeTokens.Typography.body
        label.textColor = ThemeTokens.Color.textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }

    // MARK: - Actions

    @objc private func revokeTapped(_ sender: UIButton) {
        guard let rawValue = sender.accessibilityValue,
              let capability = HTMLAppCapability(rawValue: rawValue),
              let subject = currentSubject() else { return }

        presentRevokeConfirm(
            title: "撤销「\(capability.localizedName)」授权？",
            message: "撤销后该应用再次使用此能力时会重新询问；进行中的会话（如蓝牙扫描）会立即停止。"
        ) { [runtime] in
            runtime.revokeAuthorization(subject: subject, capability: capability)
            self.reload()
        }
    }

    @objc private func revokeAllTapped() {
        guard let subject = currentSubject() else { return }
        presentRevokeConfirm(
            title: "撤销全部授权？",
            message: "将撤销该应用全部 WebBridgeKit 授权；iOS 系统权限保持不变。"
        ) {
            self.runtime.revokeAllAuthorizations(appID: self.appID)
            self.reload()
        }
    }

    @objc private func systemSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func currentSubject() -> HTMLAppPermissionSubject? {
        guard let manifest,
              let origin = HTMLAppOrigin.canonicalOrigin(forDocumentURL: URL(string: manifest.startURL) ?? URL(fileURLWithPath: "/")) else {
            return nil
        }
        return runtime.subject(appID: appID, origin: origin)
    }

    /// Design rule: revocation uses the branded bottom confirm panel, never a
    /// plain system alert.
    private func presentRevokeConfirm(title: String, message: String, onConfirm: @escaping () -> Void) {
        let confirm = PWARevokeConfirmViewController(title: title, message: message) { confirmed in
            guard confirmed else { return }
            onConfirm()
        }
        confirm.modalPresentationStyle = .overFullScreen
        confirm.modalTransitionStyle = .crossDissolve
        present(confirm, animated: true)
    }
}

/// Branded revocation confirm bottom panel.
final class PWARevokeConfirmViewController: UIViewController {

    private let titleText: String
    private let messageText: String
    private let onResult: (Bool) -> Void
    private let onceLock = NSLock()
    private var hasResolved = false

    init(title: String, message: String, onResult: @escaping (Bool) -> Void) {
        self.titleText = title
        self.messageText = message
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "pwa-permission.revokeConfirm"

        let dimming = UIControl()
        dimming.backgroundColor = ThemeTokens.Color.overlay
        dimming.translatesAutoresizingMaskIntoConstraints = false
        dimming.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(dimming)
        NSLayoutConstraint.activate([
            dimming.topAnchor.constraint(equalTo: view.topAnchor),
            dimming.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimming.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimming.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let card = UIView()
        card.backgroundColor = ThemeTokens.Color.surfaceElevated
        card.layer.cornerRadius = ThemeTokens.CornerRadius.xxl
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = ThemeTokens.Typography.title3
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        let messageLabel = UILabel()
        messageLabel.text = messageText
        messageLabel.font = ThemeTokens.Typography.body
        messageLabel.textColor = ThemeTokens.Color.textSecondary
        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("撤销", for: .normal)
        confirmButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        confirmButton.titleLabel?.font = ThemeTokens.Typography.buttonMedium
        confirmButton.backgroundColor = ThemeTokens.Color.errorSoft
        confirmButton.layer.cornerRadius = ThemeTokens.CornerRadius.md
        confirmButton.accessibilityIdentifier = "pwa-permission.revokeConfirm.confirm"
        confirmButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(ThemeTokens.Color.textSecondary, for: .normal)
        cancelButton.titleLabel?.font = ThemeTokens.Typography.buttonMedium
        cancelButton.accessibilityIdentifier = "pwa-permission.revokeConfirm.cancel"
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [confirmButton, cancelButton])
        buttons.axis = .vertical
        buttons.spacing = ThemeTokens.Spacing.sm

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttons])
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        confirmButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        cancelButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ThemeTokens.Spacing.sm),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ThemeTokens.Spacing.sm),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: ThemeTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ThemeTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ThemeTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ThemeTokens.Spacing.lg),
            dimming.topAnchor.constraint(equalTo: view.topAnchor),
            dimming.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func confirm() { resolve(true) }
    @objc private func cancel() { resolve(false) }

    private func resolve(_ result: Bool) {
        onceLock.lock()
        let already = hasResolved
        hasResolved = true
        onceLock.unlock()
        guard !already else { return }
        dismiss(animated: true) { [onResult] in onResult(result) }
    }
}
