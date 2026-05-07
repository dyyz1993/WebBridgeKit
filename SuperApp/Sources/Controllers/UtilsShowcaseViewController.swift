import UIKit
import WebBridgeKit
import SnapKit

class UtilsShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var utilities: [(String, String)] = []

    private enum Section: Int, CaseIterable {
        case overview, utilities, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "工具"
        view.backgroundColor = ThemeColors.current.background
        setupUI()
        loadUtilities()
    }

    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UtilityCell.self, forCellReuseIdentifier: "UtilityCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func loadUtilities() {
        utilities = [
            ("Cache Utilities", "Cache management helpers"),
            ("File Utilities", "File system helpers"),
            ("String Utilities", "String manipulation"),
            ("Date Utilities", "Date formatting and parsing"),
            ("Number Utilities", "Number formatting"),
            ("Validation Utilities", "Input validation")
        ]
    }
}

extension UtilsShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview: return 1
        case .utilities: return utilities.count
        case .actions: return 2
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .overview: return "Overview"
        case .utilities: return "Utility Helpers"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "UtilityCell", for: indexPath) as! UtilityCell
            cell.configure(name: "Utils Module", description: "Common utility functions for cache, file I/O, and data validation.")
            return cell

        case .utilities:
            let cell = tableView.dequeueReusableCell(withIdentifier: "UtilityCell", for: indexPath) as! UtilityCell
            let (name, description) = utilities[indexPath.row]
            cell.configure(name: name, description: description)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("Test Utilities", .primary, { [weak self] in self?.testUtilities() }),
                ("View Cache Stats", .secondary, { [weak self] in self?.viewCacheStats() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class UtilityCell: UITableViewCell {
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

extension UtilsShowcaseViewController {
    private func testUtilities() {
        let alert = UIAlertController(title: "Utilities Test", message: "Testing utility functions...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func viewCacheStats() {
        Task { @MainActor in
            let (mem, disk) = await CacheManager.shared.getStatistics()
            let message = "Memory Cache: \(mem.totalEntries) entries\nDisk Cache: \(disk.totalEntries) entries"
            let alert = UIAlertController(title: "Cache Stats", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
