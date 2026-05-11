//
//  CacheSubsystemDetailViewController.swift
//  SuperApp
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit
import WebBridgeKit

class CacheSubsystemDetailViewController: UIViewController {

    var subsystemID: SubsystemID
    private var stats: SubsystemStats?
    fileprivate let disposeBag = DisposeBag()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = ThemeTokens.Color.background
        tv.delegate = self
        tv.dataSource = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.register(DetailMetricCell.self, forCellReuseIdentifier: DetailMetricCell.reuseIdentifier)
        tv.register(DetailActionCell.self, forCellReuseIdentifier: DetailActionCell.reuseIdentifier)
        return tv
    }()

    private let headerView: DetailHeaderView = {
        let v = DetailHeaderView()
        return v
    }()

    var customActions: [(title: String, iconName: String, action: () -> Void)] {
        return [
            (title: "刷新", iconName: "refresh", action: { [weak self] in self?.refreshStats() }),
            (title: "清除", iconName: "trash", action: { [weak self] in self?.clearSubsystem() }),
        ]
    }

    var extraDataRows: [(label: String, value: String)] { [] }

    init(subsystemID: SubsystemID) {
        self.subsystemID = subsystemID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = subsystemID.nameZh
        view.backgroundColor = ThemeTokens.Color.background

        setupUI()
        refreshStats()
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        headerView.configure(
            name: subsystemID.nameZh,
            nameEn: subsystemID.name,
            iconName: subsystemID.iconName
        )
        let headerFrame = CGRect(x: 0, y: 0, width: 0, height: 120)
        headerView.frame = headerFrame
        tableView.tableHeaderView = headerView

        if !customActions.isEmpty {
            let actionBar = UIStackView()
            actionBar.axis = .horizontal
            actionBar.distribution = .fillEqually
            actionBar.spacing = ThemeTokens.Spacing.md

            for action in customActions {
                let btn = UIButton(type: .system)
                btn.setImage(UIImage(lucideId: action.iconName), for: .normal)
                btn.setTitle(" \(action.title)", for: .normal)
                btn.titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
                btn.setTitleColor(ThemeTokens.Color.primary, for: .normal)
                btn.layer.cornerRadius = ThemeTokens.CornerRadius.md
                btn.backgroundColor = ThemeTokens.Color.surface
                btn.layer.borderWidth = 1
                btn.layer.borderColor = ThemeTokens.Color.border.cgColor
                btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
                btn.rx.tap.subscribe(onNext: { _ in action.action() }).disposed(by: disposeBag)
                actionBar.addArrangedSubview(btn)
            }

            let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 52))
            container.addSubview(actionBar)
            actionBar.snp.makeConstraints { make in
                make.leading.trailing.equalTo(container).inset(16)
                make.centerY.equalTo(container)
                make.height.equalTo(40)
            }
            tableView.tableFooterView = container
        }
    }

    func refreshStats() {
        stats = CacheStatsAggregator.shared.collectStats(for: subsystemID)
        headerView.updateStatus(stats?.status ?? .unknown)
        tableView.reloadData()
    }

    func clearSubsystem() {
        let alert = UIAlertController(
            title: "清除 \(subsystemID.nameZh)",
            message: "确定要清除该子系统的所有缓存数据吗？\n注意：置顶的 URL 不会受影响。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive, handler: { [weak self] _ in
            self?.performClear()
        }))
        present(alert, animated: true)
    }

    func performClear() {
        switch subsystemID {
        case .manifestCache:
            ManifestCacheManager.shared.clearAll()
        case .webResourceCache:
            WebResourceCacheManager.shared.clearAll()
        case .webCompressedCache:
            WebCompressedCacheStore.shared.clearAll()
        case .webcacheWKWebView:
            WebCacheManager.shared.clearAllCache()
        case .systemURLCache:
            SystemURLCacheManager.shared.removeAllCachedResponses()
        case .offlinePageCache:
            WebPageOfflineCacheManager.shared.clearAllCache()
        case .pageCacheRule:
            PageCacheRuleManager.shared.clearAllRules()
        default:
            break
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshStats()
        }
    }

    static func create(for id: SubsystemID) -> CacheSubsystemDetailViewController {
        switch id {
        case .manifestCache:       return ManifestCacheDetailVC(subsystemID: id)
        case .webResourceCache:    return WebResourceCacheDetailVC(subsystemID: id)
        case .webCompressedCache:  return CompressedCacheDetailVC(subsystemID: id)
        case .webcacheWKWebView:   return WKWebViewCacheDetailVC(subsystemID: id)
        case .systemURLCache:      return SystemURLCacheDetailVC(subsystemID: id)
        case .offlinePageCache:    return OfflinePageCacheDetailVC(subsystemID: id)
        case .pageCacheRule:       return PageCacheRuleDetailVC(subsystemID: id)
        case .genericCacheManager: return GenericCacheDetailVC(subsystemID: id)
        case .memoryCacheRule:     return MemoryRuleDetailVC(subsystemID: id)
        case .userdefaultsMessageStore: return MessageStoreDetailVC(subsystemID: id)
        case .resourceCacheLRU:    return ResourceCacheDetailVC(subsystemID: id)
        }
    }
}

extension CacheSubsystemDetailViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 3 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 4
        case 1: return max(extraDataRows.count, 1)
        case 2: return customActions.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return basicMetricCell(tableView, at: indexPath)
        case 1:
            return extraDataCell(tableView, at: indexPath)
        case 2:
            return actionCell(tableView, at: indexPath)
        default:
            return UITableViewCell()
        }
    }

    private func basicMetricCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DetailMetricCell.reuseIdentifier, for: indexPath) as! DetailMetricCell

        guard let stats else {
            cell.configure(label: "--", value: "--")
            return cell
        }

        switch indexPath.row {
        case 0:
            cell.configure(label: "条目数量", value: "\(stats.totalEntries)")
        case 1:
            cell.configure(label: "占用空间", value: stats.formattedSize)
        case 2:
            cell.configure(label: "命中率", value: stats.formattedHitRate ?? "N/A")
        case 3:
            cell.configure(label: "状态", value: stats.status.displayText)
        default:
            cell.configure(label: "", value: "")
        }

        return cell
    }

    private func extraDataCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DetailMetricCell.reuseIdentifier, for: indexPath) as! DetailMetricCell

        if indexPath.row < extraDataRows.count {
            let row = extraDataRows[indexPath.row]
            cell.configure(label: row.label, value: row.value)
        } else {
            cell.configure(label: "暂无额外数据", value: "-")
        }

        return cell
    }

    private func actionCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DetailActionCell.reuseIdentifier, for: indexPath) as! DetailActionCell

        if indexPath.row < customActions.count {
            let action = customActions[indexPath.row]
            cell.configure(title: action.title, iconName: action.iconName, action: action.action)
        }

        return cell
    }
}

extension CacheSubsystemDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "基础指标"
        case 1: return "详细信息"
        case 2: return "快捷操作"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2, indexPath.row < customActions.count {
            customActions[indexPath.row].action()
        }
    }
}

class DetailHeaderView: UIView {
    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.xxl
        v.clipsToBounds = true
        return v
    }()
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        return iv
    }()
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .title2)
        l.textColor = ThemeTokens.Color.text
        return l
    }()
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textColor = ThemeTokens.Color.textSecondary
        return l
    }()
    private let statusBadge: UIView = {
        let v = UIView()
        v.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        v.clipsToBounds = true
        return v
    }()
    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = ThemeTokens.Typography.caption2
        l.textColor = .white
        return l
    }()

    init() {
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        iconContainer.addSubview(iconImageView)
        statusBadge.addSubview(statusLabel)
        addSubview(iconContainer)
        addSubview(nameLabel)
        addSubview(subtitleLabel)
        addSubview(statusBadge)

        [iconContainer, iconImageView, nameLabel, subtitleLabel, statusBadge, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 26),
            iconImageView.heightAnchor.constraint(equalToConstant: 26),

            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            statusBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            statusBadge.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            statusBadge.heightAnchor.constraint(equalToConstant: 24),
        ])

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: statusBadge.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
        ])
    }

    func configure(name: String, nameEn: String, iconName: String) {
        nameLabel.text = name
        subtitleLabel.text = nameEn
        iconImageView.image = UIImage(lucideId: iconName)
        iconContainer.backgroundColor = ThemeTokens.Color.primary
    }

    func updateStatus(_ status: SubsystemStatus) {
        statusLabel.text = status.displayText
        switch status {
        case .active: statusBadge.backgroundColor = ThemeTokens.Color.success
        case .empty: statusBadge.backgroundColor = ThemeTokens.Color.textTertiary
        case .error: statusBadge.backgroundColor = ThemeTokens.Color.error
        case .unknown: statusBadge.backgroundColor = ThemeTokens.Color.textTertiary
        }
    }
}

class DetailMetricCell: UITableViewCell {
    static let reuseIdentifier = "DetailMetricCell"

    private let labelLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .body)
        l.textColor = ThemeTokens.Color.textSecondary
        return l
    }()
    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        l.textColor = ThemeTokens.Color.text
        l.textAlignment = .right
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(labelLabel)
        contentView.addSubview(valueLabel)

        [labelLabel, valueLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            labelLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            labelLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(label: String, value: String) {
        labelLabel.text = label
        valueLabel.text = value
    }
}

class DetailActionCell: UITableViewCell {
    static let reuseIdentifier = "DetailActionCell"

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ThemeTokens.Color.primary
        return iv
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .body)
        l.textColor = ThemeTokens.Color.primary
        return l
    }()

    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)

        [iconView, titleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, iconName: String, action: @escaping () -> Void) {
        iconView.image = UIImage(lucideId: iconName)
        titleLabel.text = title
        onTap = action
    }
}

class ManifestCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class WebResourceCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class CompressedCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class WKWebViewCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class SystemURLCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class OfflinePageCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class PageCacheRuleDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class GenericCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class MemoryRuleDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class MessageStoreDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
class ResourceCacheDetailVC: CacheSubsystemDetailViewController {
    override init(subsystemID: SubsystemID) { super.init(subsystemID: subsystemID) }
    required init?(coder: NSCoder) { fatalError() }
}
