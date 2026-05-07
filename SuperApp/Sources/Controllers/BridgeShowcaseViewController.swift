import UIKit
import WebBridgeKit
import SnapKit

class BridgeShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var handlers: [(String, String)] = []

    private enum Section: Int, CaseIterable {
        case overview, handlers, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "桥接"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        loadHandlers()
    }

    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HandlerCell.self, forCellReuseIdentifier: "HandlerCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadHandlers() {
        handlers = [
            ("Navigation Handler", "Deep linking and navigation bridge"),
            ("WebView Handler", "WebView communication bridge"),
            ("Message Handler", "Cross-component messaging"),
            ("Data Handler", "Data synchronization bridge"),
            ("UI Handler", "UI state synchronization"),
            ("Event Handler", "Event propagation bridge")
        ]
    }
}

extension BridgeShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return 1
        case .handlers: return handlers.count
        case .actions: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .handlers: return "Bridge Handlers"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HandlerCell", for: indexPath) as! HandlerCell
            cell.configure(name: "Bridge Module", description: "Bridges native iOS components with WebView and external systems.")
            return cell

        case .handlers:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HandlerCell", for: indexPath) as! HandlerCell
            let (name, description) = handlers[indexPath.row]
            cell.configure(name: name, description: description)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("Test Bridge", .primary, { [weak self] in self?.testBridge() }),
                ("View Logs", .secondary, { [weak self] in self?.viewLogs() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class HandlerCell: UITableViewCell {
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

extension BridgeShowcaseViewController {
    private func testBridge() {
        let alert = UIAlertController(title: "Bridge Test", message: "Testing bridge communication...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func viewLogs() {
        let alert = UIAlertController(title: "Bridge Logs", message: "Viewing bridge activity logs...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
