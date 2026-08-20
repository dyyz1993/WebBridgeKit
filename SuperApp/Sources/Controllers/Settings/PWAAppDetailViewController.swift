import UIKit
import WebBridgeKit

final class PWAAppDetailViewController: UITableViewController {
    private enum Row: Int, CaseIterable {
        case open
        case permissions
        case service
    }

    private let manifest: HTMLAppManifest
    private let permissionLedger: HTMLAppPermissionLedger
    private let onOpen: () -> Void
    private let onManageService: () -> Void

    init(
        manifest: HTMLAppManifest,
        permissionLedger: HTMLAppPermissionLedger,
        onOpen: @escaping () -> Void,
        onManageService: @escaping () -> Void
    ) {
        self.manifest = manifest
        self.permissionLedger = permissionLedger
        self.onOpen = onOpen
        self.onManageService = onManageService
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "应用设置"
        view.backgroundColor = ThemeTokens.Color.background
        tableView.backgroundColor = ThemeTokens.Color.background
        tableView.accessibilityIdentifier = "pwa.details"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AppDetailCell")
        tableView.tableHeaderView = makeHeader()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppDetailCell", for: indexPath)
        guard let row = Row(rawValue: indexPath.row) else { return cell }
        var content = cell.defaultContentConfiguration()
        content.textProperties.font = ThemeTokens.Typography.rowTitle
        content.secondaryTextProperties.font = ThemeTokens.Typography.caption1
        content.textProperties.color = ThemeTokens.Color.text
        content.secondaryTextProperties.color = ThemeTokens.Color.textSecondary
        cell.backgroundColor = ThemeTokens.Color.cardBackground
        cell.accessoryType = .disclosureIndicator

        switch row {
        case .open:
            content.text = "打开应用"
            content.secondaryText = "进入 \(manifest.name)"
            content.image = LucideIcon.appFill.templateImage(pointSize: 20, weight: .medium)
            content.imageProperties.tintColor = ThemeTokens.Color.primary
            cell.accessibilityIdentifier = "pwa.details.open"
        case .permissions:
            let grantCount = permissionLedger.grants(for: manifest.appID).count
            content.text = "权限与原生能力"
            content.secondaryText = "声明 \(manifest.capabilities.count) 项 · 已允许 \(grantCount) 项"
            content.image = LucideIcon.shield.templateImage(pointSize: 20, weight: .medium)
            content.imageProperties.tintColor = grantCount > 0
                ? ThemeTokens.Color.success
                : ThemeTokens.Color.textSecondary
            cell.accessibilityIdentifier = "pwa.details.permissions"
        case .service:
            content.text = "应用服务"
            content.secondaryText = "查看或切换当前网关"
            content.image = LucideIcon.server.templateImage(pointSize: 20, weight: .medium)
            content.imageProperties.tintColor = ThemeTokens.Color.info
            cell.accessibilityIdentifier = "pwa.details.service"
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }
        switch row {
        case .open:
            onOpen()
        case .permissions:
            navigationController?.pushViewController(
                PWAAppPermissionViewController(
                    manifest: manifest,
                    permissionLedger: permissionLedger
                ),
                animated: true
            )
        case .service:
            onManageService()
        }
    }

    private func makeHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 150))

        let iconView = UIView()
        iconView.backgroundColor = ThemeTokens.Color.primarySoft
        iconView.layer.cornerRadius = ThemeTokens.CornerRadius.xl

        let icon = UIImageView(image: LucideIcon.appFill.templateImage(pointSize: 30, weight: .semibold))
        icon.tintColor = ThemeTokens.Color.primary
        iconView.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30)
        ])

        let name = UILabel()
        name.font = ThemeTokens.Typography.title3
        name.textColor = ThemeTokens.Color.text
        name.textAlignment = .center
        name.text = manifest.name

        let origin = UILabel()
        origin.font = ThemeTokens.Typography.monospaceSmall
        origin.textColor = ThemeTokens.Color.textSecondary
        origin.textAlignment = .center
        origin.numberOfLines = 2
        origin.text = URL(string: manifest.startURL)?.host ?? manifest.startURL

        let stack = UIStackView(arrangedSubviews: [iconView, name, origin])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = ThemeTokens.Spacing.sm
        header.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: ThemeTokens.Spacing.lg),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: header.leadingAnchor, constant: ThemeTokens.Spacing.xl),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -ThemeTokens.Spacing.xl),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64)
        ])
        return header
    }
}
