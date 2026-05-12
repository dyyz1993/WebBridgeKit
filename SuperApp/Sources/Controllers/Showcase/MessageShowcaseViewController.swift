import UIKit
import WebBridgeKit
import SnapKit

class MessageShowcaseViewController: UIViewController {

    private var tableView: UITableView!
    private var statistics = MessageStatistics()
    private var channels: [String] = []
    private var messages: [StoredMessage] = []
    private var unreadCount: Int = 0

    private enum Section: Int, CaseIterable {
        case stats, messages, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = ThemeColors.current.background

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MessageStatCell.self, forCellReuseIdentifier: "MessageStatCell")
        tableView.register(MsgDetailCell.self, forCellReuseIdentifier: "MsgDetailCell")
        tableView.register(ActionCell.self, forCellReuseIdentifier: "MsgActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func loadData() {
        Task { @MainActor in
            statistics = await MessageEngine.shared.getStatistics()
            channels = await MessageEngine.shared.getRegisteredChannels()
            messages = await MessageEngine.shared.getMessages()
            unreadCount = await MessageEngine.shared.getUnreadCount()
            tableView.reloadData()
        }
    }

    private func sendTestPush() {
        Task { @MainActor in
            let payload = MessagePayload(
                title: "Test Push",
                body: "This is a test push from MessageShowcase at \(Date())",
                channel: "bark",
                group: "test"
            )
            do {
                let result = try await MessageEngine.shared.send(payload, through: "bark")
                let msg: String
                switch result {
                case .success(let id): msg = "Sent: \(id)"
                case .failed(let err): msg = "Failed: \(err.localizedDescription)"
                case .queued(let id): msg = "Queued: \(id)"
                }
                let alert = UIAlertController(title: "Push Result", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            } catch {
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    private func addTestMessage() {
        Task { @MainActor in
            let payload = MessagePayload(
                title: "Test Message \(Int(Date().timeIntervalSince1970))",
                body: "Body of test message from showcase",
                channel: "local"
            )
            try? await MessageEngine.shared.receive(payload)
            loadData()
        }
    }

    private func clearAll() {
        Task { @MainActor in
            await MessageEngine.shared.clearAllMessages()
            loadData()
        }
    }
}

extension MessageShowcaseViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .stats: return 5 + channels.count
        case .messages: return max(messages.count, 1)
        case .actions: return 3
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .stats: return "Statistics (Unread: \(unreadCount))"
        case .messages: return "Messages (\(messages.count))"
        case .actions: return "Actions"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .stats:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MessageStatCell", for: indexPath) as! MessageStatCell
            let baseStats: [(String, String)] = [
                ("Received", "\(statistics.totalReceived)"),
                ("Sent", "\(statistics.totalSent)"),
                ("Failed", "\(statistics.totalFailed)"),
                ("Queued", "\(statistics.totalQueued)"),
                ("Registered Channels", channels.joined(separator: ", "))
            ]
            if indexPath.row < baseStats.count {
                cell.configure(label: baseStats[indexPath.row].0, value: baseStats[indexPath.row].1)
            } else {
                let channelIdx = indexPath.row - baseStats.count
                let channelId = channels[channelIdx]
                let chStats = statistics.byChannel[channelId]
                cell.configure(label: "  \(channelId)", value: "r:\(chStats?.received ?? 0) s:\(chStats?.sent ?? 0) f:\(chStats?.failed ?? 0)")
            }
            return cell

        case .messages:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MsgDetailCell", for: indexPath) as! MsgDetailCell
            if messages.isEmpty {
                cell.configure(title: "No messages", body: "Send a test message to see it here", time: "")
                return cell
            }
            let msg = messages[indexPath.row]
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            cell.configure(title: msg.payload.title, body: msg.payload.body, time: formatter.string(from: msg.receivedAt))
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MsgActionCell", for: indexPath) as! ActionCell
            let actions: [(String, ThemeButtonStyle, () -> Void)] = [
                ("Send Test Push (Bark)", .primary, { [weak self] in self?.sendTestPush() }),
                ("Add Test Message", .secondary, { [weak self] in self?.addTestMessage() }),
                ("Clear All Messages", .ghost, { [weak self] in self?.clearAll() })
            ]
            let (title, style, action) = actions[indexPath.row]
            cell.configure(title: title, style: style) { action() }
            return cell
        }
    }
}

private class MessageStatCell: UITableViewCell {
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

private class MsgDetailCell: UITableViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.headline
        label.textColor = ThemeColors.current.text
        return label
    }()
    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.body
        label.textColor = ThemeColors.current.textSecondary
        label.numberOfLines = 2
        return label
    }()
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeTypography.current.caption1
        label.textColor = ThemeColors.current.textSecondary
        label.textAlignment = .right
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        contentView.addSubview(bodyLabel)
        contentView.addSubview(timeLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(16)
        }
        timeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(titleLabel)
        }
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, body: String, time: String) {
        titleLabel.text = title
        bodyLabel.text = body
        timeLabel.text = time
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
