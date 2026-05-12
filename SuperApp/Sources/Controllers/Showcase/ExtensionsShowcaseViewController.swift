import UIKit
import WebBridgeKit
import SnapKit

class ExtensionsShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var extensions: [(String, String)] = []

    private enum Section: Int, CaseIterable {
        case overview, extensions, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "扩展"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        loadExtensions()
    }

    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ExtensionCell.self, forCellReuseIdentifier: "ExtensionCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadExtensions() {
        extensions = [
            ("UIKit Extensions", "UIView, UIViewController extensions"),
            ("SwiftUI Extensions", "SwiftUI view modifiers"),
            ("Combine Extensions", "Combine operators and publishers"),
            ("Core Graphics", "Drawing and animation helpers"),
            ("Foundation Extensions", "Foundation type enhancements"),
            ("System Extensions", "System-level utilities")
        ]
    }
}

extension ExtensionsShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return 1
        case .extensions: return extensions.count
        case .actions: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .extensions: return "Framework Extensions"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExtensionCell", for: indexPath) as! ExtensionCell
            cell.configure(name: "Extensions Module", description: "Convenient extensions for UIKit, SwiftUI, and system frameworks.")
            return cell

        case .extensions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExtensionCell", for: indexPath) as! ExtensionCell
            let (name, description) = extensions[indexPath.row]
            cell.configure(name: name, description: description)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("Test Extensions", .primary, { [weak self] in self?.testExtensions() }),
                ("View Samples", .secondary, { [weak self] in self?.viewSamples() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class ExtensionCell: UITableViewCell {
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

extension ExtensionsShowcaseViewController {
    private func testExtensions() {
        let alert = UIAlertController(title: "Extensions Test", message: "Testing framework extensions...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func viewSamples() {
        let alert = UIAlertController(title: "Samples", message: "Available extension samples:\n• UIView extensions\n• SwiftUI modifiers\n• Combine operators", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
