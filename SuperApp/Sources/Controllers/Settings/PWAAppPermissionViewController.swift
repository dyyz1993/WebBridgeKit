import UIKit
import WebBridgeKit

/// Shows both the WebBridgeKit grant and the independent iOS system status for
/// every capability declared by one managed PWA.
final class PWAAppPermissionViewController: UITableViewController {
    private struct CapabilityItem {
        let capability: HTMLAppCapability
        let grants: [HTMLAppPermissionGrant]
        let systemStatus: HTMLAppCapabilityResult.Status
    }

    private struct CapabilityGroup {
        enum Kind {
            case attention
            case allowed
            case unused

            var title: String {
                switch self {
                case .attention: return "需要处理"
                case .allowed: return "已允许"
                case .unused: return "尚未使用"
                }
            }
        }

        let kind: Kind
        let items: [CapabilityItem]
    }

    private let manifest: HTMLAppManifest
    private let permissionLedger: HTMLAppPermissionLedger
    private let nativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding
    private var groups: [CapabilityGroup] = []
    private var grants: [HTMLAppPermissionGrant] = []

    init(
        manifest: HTMLAppManifest,
        permissionLedger: HTMLAppPermissionLedger = .shared,
        nativeAuthorizationProvider: HTMLAppNativeAuthorizationProviding = HTMLAppSystemAuthorizationProvider()
    ) {
        self.manifest = manifest
        self.permissionLedger = permissionLedger
        self.nativeAuthorizationProvider = nativeAuthorizationProvider
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "权限与原生能力"
        view.backgroundColor = ThemeTokens.Color.background
        tableView.backgroundColor = ThemeTokens.Color.background
        tableView.accessibilityIdentifier = "pwa.permission.center"
        tableView.register(PWAAppPermissionCell.self, forCellReuseIdentifier: PWAAppPermissionCell.reuseID)
        tableView.tableHeaderView = makeHeader()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "全部撤销",
            style: .plain,
            target: self,
            action: #selector(revokeAll)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "pwa.permission.revokeAll"
        reloadState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reloadState()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        groups.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups[section].items.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        groups[section].kind.title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == groups.count - 1 else { return nil }
        return "未使用的能力不能在这里预先授予。PWA 实际调用时，WebBridgeKit 会展示用途并再次询问。"
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PWAAppPermissionCell.reuseID,
            for: indexPath
        ) as? PWAAppPermissionCell else {
            return UITableViewCell()
        }
        let item = groups[indexPath.section].items[indexPath.row]
        let grantStatus = grantStatusText(for: item.grants)
        let systemStatus = systemStatusText(for: item.systemStatus)
        let needsSettings = needsSystemSettings(item.systemStatus)
        cell.configure(
            capability: item.capability,
            grantStatus: grantStatus,
            systemStatus: systemStatus,
            statusColor: statusColor(for: item),
            actionText: item.grants.isEmpty
                ? (needsSettings ? "前往设置" : "使用时询问")
                : "管理"
        )
        cell.accessibilityIdentifier = "pwa.permission.capability.\(item.capability.rawValue)"
        cell.selectionStyle = item.grants.isEmpty && !needsSettings ? .none : .default
        cell.accessoryType = item.grants.isEmpty && !needsSettings ? .none : .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = groups[indexPath.section].items[indexPath.row]
        if !item.grants.isEmpty {
            showRevokeSheet(for: item)
        } else if needsSystemSettings(item.systemStatus) {
            openSystemSettings()
        }
    }

    @objc private func revokeAll() {
        guard !grants.isEmpty else { return }
        let sheet = PWARevokePermissionSheetViewController(
            title: "撤销全部 PWA 授权？",
            message: "这不会更改 iOS 系统权限。下次使用原生能力时，WebBridgeKit 会逐项重新询问。",
            destructiveTitle: "全部撤销",
            showsSystemSettings: false
        ) { [weak self] action in
            guard let self, action == .revoke else { return }
            self.permissionLedger.revokeAll(appID: self.manifest.appID)
            self.reloadState()
        }
        present(sheet, animated: false)
    }

    private func showRevokeSheet(for item: CapabilityItem) {
        let sheet = PWARevokePermissionSheetViewController(
            title: "撤销\(item.capability.displayName)授权？",
            message: "撤销后，下次 PWA 调用这项能力时会重新显示用途说明并询问。",
            destructiveTitle: "撤销授权",
            showsSystemSettings: needsSystemSettings(item.systemStatus)
        ) { [weak self] action in
            guard let self else { return }
            switch action {
            case .revoke:
                item.grants.forEach {
                    self.permissionLedger.revoke(
                        appID: $0.appID,
                        origin: $0.origin,
                        capability: $0.capability
                    )
                }
                self.reloadState()
            case .openSystemSettings:
                self.openSystemSettings()
            case .cancel:
                break
            }
        }
        present(sheet, animated: false)
    }

    private func reloadState() {
        grants = permissionLedger.grants(for: manifest.appID)
        let groupedGrants = Dictionary(grouping: grants, by: \.capability)
        let items = manifest.capabilities.map { capability in
            CapabilityItem(
                capability: capability,
                grants: groupedGrants[capability] ?? [],
                systemStatus: nativeAuthorizationProvider.authorizationStatus(for: capability)
            )
        }

        let attention = items.filter { needsSystemSettings($0.systemStatus) }
        let allowed = items.filter { !needsSystemSettings($0.systemStatus) && !$0.grants.isEmpty }
        let unused = items.filter { !needsSystemSettings($0.systemStatus) && $0.grants.isEmpty }
        groups = [
            CapabilityGroup(kind: .attention, items: attention),
            CapabilityGroup(kind: .allowed, items: allowed),
            CapabilityGroup(kind: .unused, items: unused)
        ].filter { !$0.items.isEmpty }

        navigationItem.rightBarButtonItem?.isEnabled = !grants.isEmpty
        tableView.reloadData()
    }

    private func grantStatusText(for grants: [HTMLAppPermissionGrant]) -> String {
        guard let first = grants.first else { return "WebBridgeKit：尚未授权" }
        let scope: String
        switch first.scope {
        case .once: scope = "仅一次"
        case .appSession: scope = "本次使用期间"
        case .always: scope = "始终允许"
        @unknown default: scope = "未知范围"
        }
        return grants.count > 1
            ? "WebBridgeKit：\(scope) · \(grants.count) 个来源"
            : "WebBridgeKit：\(scope)"
    }

    private func systemStatusText(for status: HTMLAppCapabilityResult.Status) -> String {
        switch status {
        case .granted: return "iOS 系统：已允许"
        case .denied, .requiresSettings: return "iOS 系统：已拒绝"
        case .notDetermined: return "iOS 系统：尚未请求"
        case .restricted: return "iOS 系统：受系统限制"
        case .unavailable: return "iOS 系统：当前设备不可用"
        @unknown default: return "iOS 系统：未知"
        }
    }

    private func needsSystemSettings(_ status: HTMLAppCapabilityResult.Status) -> Bool {
        switch status {
        case .denied, .requiresSettings, .restricted, .unavailable: return true
        case .granted, .notDetermined: return false
        @unknown default: return true
        }
    }

    private func statusColor(for item: CapabilityItem) -> UIColor {
        if needsSystemSettings(item.systemStatus) { return ThemeTokens.Color.warning }
        return item.grants.isEmpty ? ThemeTokens.Color.textTertiary : ThemeTokens.Color.success
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func makeHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 176))

        let iconView = UIView()
        iconView.backgroundColor = ThemeTokens.Color.primarySoft
        iconView.layer.cornerRadius = ThemeTokens.CornerRadius.xl
        let icon = UIImageView(image: LucideIcon.shield.templateImage(pointSize: 28, weight: .semibold))
        icon.tintColor = ThemeTokens.Color.primary
        iconView.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.font = ThemeTokens.Typography.title3
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.textAlignment = .center
        titleLabel.text = manifest.name

        let summaryLabel = UILabel()
        summaryLabel.font = ThemeTokens.Typography.caption1
        summaryLabel.textColor = ThemeTokens.Color.textSecondary
        summaryLabel.textAlignment = .center
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "每项原生能力都会在实际使用时单独询问。\n系统权限与 WebBridgeKit 授权相互独立。"

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, summaryLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = ThemeTokens.Spacing.sm
        header.addSubview(stack)
        [stack, icon].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: ThemeTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: ThemeTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -ThemeTokens.Spacing.xl),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),
            icon.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28)
        ])
        return header
    }
}

private final class PWAAppPermissionCell: UITableViewCell {
    static let reuseID = "PWAAppPermissionCell"

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let grantLabel = UILabel()
    private let systemLabel = UILabel()
    private let statusDot = UIView()
    private let actionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        capability: HTMLAppCapability,
        grantStatus: String,
        systemStatus: String,
        statusColor: UIColor,
        actionText: String
    ) {
        titleLabel.text = capability.displayName
        grantLabel.text = grantStatus
        systemLabel.text = systemStatus
        actionLabel.text = actionText
        statusDot.backgroundColor = statusColor
        iconView.image = Self.icon(for: capability).templateImage(pointSize: 20, weight: .medium)
        iconView.tintColor = statusColor
        iconContainer.backgroundColor = statusColor.withAlphaComponent(ThemeTokens.Opacity.badgeFill)
    }

    private func configureLayout() {
        backgroundColor = ThemeTokens.Color.cardBackground

        iconContainer.layer.cornerRadius = ThemeTokens.CornerRadius.md
        iconContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        titleLabel.font = ThemeTokens.Typography.rowTitle
        titleLabel.textColor = ThemeTokens.Color.text
        grantLabel.font = ThemeTokens.Typography.caption1
        grantLabel.textColor = ThemeTokens.Color.textSecondary
        systemLabel.font = ThemeTokens.Typography.caption1
        systemLabel.textColor = ThemeTokens.Color.textSecondary
        actionLabel.font = ThemeTokens.Typography.caption2
        actionLabel.textColor = ThemeTokens.Color.textTertiary
        actionLabel.textAlignment = .right
        actionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        statusDot.layer.cornerRadius = ThemeTokens.CornerRadius.full
        let titleRow = UIStackView(arrangedSubviews: [statusDot, titleLabel, UIView(), actionLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = ThemeTokens.Spacing.sm
        let labels = UIStackView(arrangedSubviews: [titleRow, grantLabel, systemLabel])
        labels.axis = .vertical
        labels.spacing = ThemeTokens.Spacing.xs

        contentView.addSubview(iconContainer)
        contentView.addSubview(labels)
        [iconContainer, labels, statusDot].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ThemeTokens.Spacing.lg),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            labels.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: ThemeTokens.Spacing.md),
            labels.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -ThemeTokens.Spacing.lg),
            labels.topAnchor.constraint(equalTo: contentView.topAnchor, constant: ThemeTokens.Spacing.md),
            labels.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -ThemeTokens.Spacing.md),
            statusDot.widthAnchor.constraint(equalToConstant: 7),
            statusDot.heightAnchor.constraint(equalToConstant: 7),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 82)
        ])
    }

    private static func icon(for capability: HTMLAppCapability) -> LucideIcon {
        switch capability {
        case .biometrics: return .shield
        case .camera, .scan: return .camera
        case .clipboard, .contacts: return .clipboard
        case .fileExport, .fileImport: return .folder
        case .location: return .pin
        case .microphone: return .mic
        case .notification: return .bell
        case .photoLibrary: return .image
        case .share: return .share
        case .bluetooth, .deviceControl, .displayStatus, .motion: return .network
        @unknown default: return .shield
        }
    }
}

private final class PWARevokePermissionSheetViewController: UIViewController {
    enum Action: Equatable {
        case revoke
        case openSystemSettings
        case cancel
    }

    private let sheetTitle: String
    private let sheetMessage: String
    private let destructiveTitle: String
    private let showsSystemSettings: Bool
    private let completion: (Action) -> Void
    private let dimmingControl = UIControl()
    private let sheetView = UIView()
    private var hasResolved = false

    init(
        title: String,
        message: String,
        destructiveTitle: String,
        showsSystemSettings: Bool,
        completion: @escaping (Action) -> Void
    ) {
        sheetTitle = title
        sheetMessage = message
        self.destructiveTitle = destructiveTitle
        self.showsSystemSettings = showsSystemSettings
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "pwa.permission.revokeSheet"

        dimmingControl.backgroundColor = ThemeTokens.Color.scrim
        dimmingControl.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(dimmingControl)
        dimmingControl.translatesAutoresizingMaskIntoConstraints = false

        sheetView.backgroundColor = ThemeTokens.Color.surfaceElevated
        sheetView.layer.cornerRadius = ThemeTokens.CornerRadius.sheet
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(sheetView)
        sheetView.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.backgroundColor = ThemeTokens.Color.errorSoft
        iconContainer.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        let icon = UIImageView(image: LucideIcon.shield.templateImage(pointSize: 24, weight: .semibold))
        icon.tintColor = ThemeTokens.Color.error
        iconContainer.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.font = ThemeTokens.Typography.title3
        titleLabel.textColor = ThemeTokens.Color.text
        titleLabel.text = sheetTitle
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.font = ThemeTokens.Typography.body
        messageLabel.textColor = ThemeTokens.Color.textSecondary
        messageLabel.text = sheetMessage
        messageLabel.numberOfLines = 0

        let revokeButton = ThemeButton(type: .system)
        revokeButton.configure(title: destructiveTitle, style: .secondary)
        revokeButton.backgroundColor = ThemeTokens.Color.errorSoft
        revokeButton.setTitleColor(ThemeTokens.Color.error, for: .normal)
        revokeButton.layer.borderColor = ThemeTokens.Color.error.withAlphaComponent(0.3).cgColor
        revokeButton.accessibilityIdentifier = "pwa.permission.revokeConfirm"
        revokeButton.addTarget(self, action: #selector(revoke), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconContainer, titleLabel, messageLabel, revokeButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = ThemeTokens.Spacing.lg

        if showsSystemSettings {
            let settingsButton = ThemeButton(type: .system)
            settingsButton.configure(title: "前往系统设置", style: .secondary)
            settingsButton.accessibilityIdentifier = "pwa.permission.openSystemSettings"
            settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
            stack.addArrangedSubview(settingsButton)
            settingsButton.heightAnchor.constraint(equalToConstant: ThemeTokens.ComponentContract.Button.height).isActive = true
        }

        let cancelButton = ThemeButton(type: .system)
        cancelButton.configure(title: "取消", style: .ghost)
        cancelButton.accessibilityIdentifier = "pwa.permission.revokeCancel"
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        stack.addArrangedSubview(cancelButton)

        sheetView.addSubview(stack)
        [stack, icon].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            dimmingControl.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingControl.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: ThemeTokens.Spacing.md),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ThemeTokens.Spacing.md),
            sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: ThemeTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: ThemeTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -ThemeTokens.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: sheetView.safeAreaLayoutGuide.bottomAnchor, constant: -ThemeTokens.Spacing.lg),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            revokeButton.heightAnchor.constraint(equalToConstant: ThemeTokens.ComponentContract.Button.height),
            cancelButton.heightAnchor.constraint(equalToConstant: ThemeTokens.ComponentContract.Button.height)
        ])
    }

    @objc private func revoke() {
        resolve(.revoke)
    }

    @objc private func openSettings() {
        resolve(.openSystemSettings)
    }

    @objc private func cancel() {
        resolve(.cancel)
    }

    private func resolve(_ action: Action) {
        guard !hasResolved else { return }
        hasResolved = true
        dismiss(animated: true) { self.completion(action) }
    }
}
