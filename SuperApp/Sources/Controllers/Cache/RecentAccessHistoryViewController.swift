//
//  WebPageHistoryViewController.swift
//  SuperApp
//
//  Created on 2026-05-19.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit

/// Show recent page access history with time filters
final class RecentAccessHistoryViewController: UIViewController {
    let manager = WebPageHistoryManager.shared

    private var timeFilter: TimeFilter = .all

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var history: [WebPageHistory] = []

    private lazy var filterSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["全部", "今天", "7天"])
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        return sc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "最近访问"
        view.backgroundColor = ThemeTokens.Color.background

        setupUI()
        loadHistory()
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HistoryCell.self, forCellReuseIdentifier: "HistoryCell")

        navigationItem.titleView = filterSegmentedControl
        filterSegmentedControl.sizeToFit()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "清除",
            style: .plain,
            target: self,
            action: #selector(clearHistory)
        )
    }

    private func loadHistory() {
        Task { @MainActor in
            do {
                switch timeFilter {
                case .all:
                    history = try await manager.getAllHistories()
                case .today:
                    let today = Calendar.current.startOfDay(for: Date())
                    history = try await manager.getHistoriesSince(date: today)
                case .last7Days:
                    let sevenDaysAgo = Date().addingTimeInterval(-604800)
                    history = try await manager.getHistoriesSince(date: sevenDaysAgo)
                }
                tableView.reloadData()
            } catch {
                HUDService.shared.showError(withStatus: "加载失败: \(error.localizedDescription)")
            }
        }
    }

    @objc private func filterChanged() {
        timeFilter = TimeFilter(rawValue: filterSegmentedControl.selectedSegmentIndex) ?? .all
        loadHistory()
    }

    @objc private func clearHistory() {
        let alert = UIAlertController(
            title: "确认清除",
            message: "将清除所有访问历史记录",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                do {
                    try await self.manager.clearAllHistory()
                    self.history.removeAll()
                    self.tableView.reloadData()
                    HUDService.shared.showSuccess(withStatus: "历史已清除")
                } catch {
                    HUDService.shared.showError(withStatus: "清除失败: \(error.localizedDescription)")
                }
            }
        })
        present(alert, animated: true)
    }
}

extension RecentAccessHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! HistoryCell
        let entry = history[indexPath.row]
        cell.configure(with: entry)
        return cell
    }
}

extension RecentAccessHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = history[indexPath.row]
        guard let url = URL(string: entry.url) else { return }

        if let navigationController = navigationController {
            WebBrowserManager.shared.openBrowser(url: url, from: navigationController)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            let entry = self.history[indexPath.row]

            Task { @MainActor in
                do {
                    try await self.manager.deleteHistory(id: entry.id)
                    self.history.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    HUDService.shared.showSuccess(withStatus: "已删除")
                    completion(true)
                } catch {
                    HUDService.shared.showError(withStatus: "删除失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }

        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

enum TimeFilter: Int {
    case all = 0
    case today = 1
    case last7Days = 2
}

private class HistoryCell: UITableViewCell {
    static let reuseIdentifier = "HistoryCell"

    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(urlLabel)
        contentView.addSubview(timeLabel)

        [titleLabel, urlLabel, timeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -12),

            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])

        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = ThemeTokens.Color.text

        urlLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        urlLabel.textColor = ThemeTokens.Color.textSecondary

        timeLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        timeLabel.textColor = ThemeTokens.Color.textTertiary
    }

    func configure(with entry: WebPageHistory) {
        titleLabel.text = entry.title ?? URL(string: entry.url)?.host ?? entry.url
        urlLabel.text = entry.url

        let formatter = RelativeDateTimeFormatter()
        timeLabel.text = formatter.localizedString(for: entry.lastVisitDate, relativeTo: Date())
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        urlLabel.text = nil
        timeLabel.text = nil
    }
}

class RelativeDateTimeFormatter {
    private let calendar = Calendar.current
    private let dateComponents: Set<Calendar.Component> = [.day, .hour, .minute]

    func localizedString(for date: Date, relativeTo referenceDate: Date) -> String {
        let components = calendar.dateComponents(dateComponents, from: date, to: referenceDate)

        if let days = components.day, days > 0 {
            return "\(days)天前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)小时前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
}
