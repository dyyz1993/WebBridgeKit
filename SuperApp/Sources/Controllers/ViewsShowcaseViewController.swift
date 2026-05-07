import UIKit
import WebBridgeKit
import SnapKit

class ViewsShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var views: [(String, String)] = []

    private enum Section: Int, CaseIterable {
        case overview, views, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "视图"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        loadViews()
    }

    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ViewCell.self, forCellReuseIdentifier: "ViewCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadViews() {
        views = [
            ("Theme Card", "Themed card container"),
            ("Theme Button", "Styled button components"),
            ("Theme Badge", "Status badges"),
            ("Theme Empty State", "Empty state view"),
            ("Theme Gradient", "Gradient background"),
            ("Custom Views", "Project-specific views")
        ]
    }
}

extension ViewsShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return 1
        case .views: return views.count
        case .actions: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .views: return "Custom Views"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ViewCell", for: indexPath) as! ViewCell
            cell.configure(name: "Views Module", description: "Reusable UI components and custom views built on top of the theme system.")
            return cell

        case .views:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ViewCell", for: indexPath) as! ViewCell
            let (name, description) = views[indexPath.row]
            cell.configure(name: name, description: description)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("View Components", .primary, { [weak self] in self?.viewComponents() }),
                ("Test Theme", .secondary, { [weak self] in self?.testTheme() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class ViewCell: UITableViewCell {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.headline
        label.textColor = ThemeColors.current.text
        return label
    }()
    private let descLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
        nameLabel.snp.makeConstraints { make in
            make.top.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.bottom.equalToSuperview().offset(-16)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, description: String) {
        nameLabel.text = name
        descLabel.text = description
    }
}

private class ActionCell: UITableViewCell {
    private let button = ThemeButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
            make.height.equalTo(40)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, style: ThemeButtonStyle, action: @escaping () -> Void) {
        button.configure(title: title, style: style)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }
}

extension ViewsShowcaseViewController {
    private func viewComponents() {
        let alert = UIAlertController(title: "Components", message: "Available view components:\n• ThemeCard\n• ThemeButton\n• ThemeBadge\n• ThemeEmptyState\n• ThemeGradient", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func testTheme() {
        let alert = UIAlertController(title: "Theme Test", message: "Current theme: \(ThemeColors.current.primary.toHexString())", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06X", rgb)
    }
}
