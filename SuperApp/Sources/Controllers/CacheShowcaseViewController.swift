import UIKit
import WebBridgeKit
import SnapKit

class CacheShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var memoryStats = SystemCacheStatistics()
    private var diskStats = SystemCacheStatistics()
    private var globalStats = SystemCacheStatistics()
    private var logEntries: [LogEntry] = []

    private enum Section: Int, CaseIterable {
        case stats, activity, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "缓存"
        view.backgroundColor = ThemeColors.current.background

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StatCell.self, forCellReuseIdentifier: "StatCell")
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        loadStats()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadStats()
    }

    private func loadStats() {
        Task { @MainActor in
            async let stats = CacheManager.shared.getStatistics()
            async let global = CacheManager.shared.getGlobalStatistics()
            let (mem, disk) = await stats
            let g = await global
            self.memoryStats = mem
            self.diskStats = disk
            self.globalStats = g
            self.logEntries = StructuredLogger.shared.query(category: .cache, limit: 20)
            self.tableView.reloadData()
        }
    }

    private func clearAll() {
        Task { @MainActor in
            await CacheManager.shared.clearAll()
            loadStats()
        }
    }

    private func addTestEntry() {
        Task { @MainActor in
            let key = "test_\(Int(Date().timeIntervalSince1970))"
            await CacheManager.shared.set("TestValue_\(key)", for: key)
            StructuredLogger.shared.info("Added test cache entry: \(key)", category: .cache)
            loadStats()
        }
    }

    private func resetStats() {
        Task { @MainActor in
            await CacheManager.shared.resetStatistics()
            loadStats()
        }
    }
}

extension CacheShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .stats: return 6
        case .activity: return max(logEntries.count, 1)
        case .actions: return 3
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .stats: return "Cache Statistics"
        case .activity: return "Recent Activity (\(logEntries.count))"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .stats:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatCell", for: indexPath) as! StatCell
            let stats: [(String, String)] = [
                ("Memory Entries", "\(memoryStats.totalEntries)"),
                ("Disk Entries", "\(diskStats.totalEntries)"),
                ("Memory Hit Rate", memoryStats.formattedHitRate),
                ("Disk Hit Rate", diskStats.formattedHitRate),
                ("Total Cache Size", globalStats.formattedCacheSize),
                ("Total Requests", "\(globalStats.totalRequests)")
            ]
            let (label, value) = stats[indexPath.row]
            cell.configure(label: label, value: value)
            return cell

        case .activity:
            if logEntries.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell", for: indexPath) as! ActivityCell
                cell.configure(text: "No cache activity yet")
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell", for: indexPath) as! ActivityCell
            let entry = logEntries[indexPath.row]
            cell.configure(text: entry.consoleString)
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
            let actions: [(String, () -> Void)] = [
                ("Clear All Cache", { [weak self] in self?.clearAll() }),
                ("Add Test Entry", { [weak self] in self?.addTestEntry() }),
                ("Reset Statistics", { [weak self] in self?.resetStats() })
            ]
            let (title, action) = actions[indexPath.row]
            cell.configure(title: title, style: indexPath.row == 0 ? .secondary : .primary) { action() }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .actions: return 50
        default: return UITableView.automaticDimension
        }
    }
}

private class StatCell: UITableViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.textSecondary
        return label
    }()
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.headline
        label.textColor = ThemeColors.current.text
        label.textAlignment = .right
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.left.greaterThanOrEqualTo(titleLabel.snp.right).offset(8)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(label: String, value: String) {
        titleLabel.text = label
        valueLabel.text = value
    }
}

private class ActivityCell: UITableViewCell {
    private let label: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(text: String) {
        label.text = text
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
