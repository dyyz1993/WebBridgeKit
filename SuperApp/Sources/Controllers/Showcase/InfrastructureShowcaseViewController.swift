import UIKit
import WebBridgeKit
import SnapKit

class InfrastructureShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var components: [(String, String)] = []

    private enum Section: Int, CaseIterable {
        case overview, components, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "基础设施"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        loadComponents()
    }

    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ComponentCell.self, forCellReuseIdentifier: "ComponentCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadComponents() {
        components = [
            ("Structured Logger", "Structured logging system"),
            ("Performance Monitor", "Performance metrics tracking"),
            ("Error Handler", "Centralized error handling"),
            ("Memory Manager", "Memory optimization"),
            ("Thread Manager", "Thread pool management"),
            ("Configuration Manager", "App configuration handling")
        ]
    }
}

extension InfrastructureShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return 1
        case .components: return components.count
        case .actions: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .components: return "Infrastructure Components"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ComponentCell", for: indexPath) as! ComponentCell
            cell.configure(name: "Infrastructure Module", description: "Foundation services for logging, monitoring, and error handling.")
            return cell

        case .components:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ComponentCell", for: indexPath) as! ComponentCell
            let (name, description) = components[indexPath.row]
            cell.configure(name: name, description: description)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("View Logs", .primary, { [weak self] in self?.viewLogs() }),
                ("Check Performance", .secondary, { [weak self] in self?.checkPerformance() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class ComponentCell: UITableViewCell {
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

extension InfrastructureShowcaseViewController {
    private func viewLogs() {
        Task { @MainActor in
            let logs = StructuredLogger.shared.query(limit: 20)
            let message = logs.map { "\($0.consoleString)" }.joined(separator: "\n")
            let alert = UIAlertController(title: "Recent Logs", message: message.isEmpty ? "No logs" : message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func checkPerformance() {
        let alert = UIAlertController(title: "Performance", message: "Checking system performance metrics...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
