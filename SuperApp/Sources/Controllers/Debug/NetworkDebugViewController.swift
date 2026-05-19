//
//  NetworkDebugViewController.swift
//  SuperApp
//
//  Created on 2026-05-19.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import WebBridgeKit

#if DEBUG

class NetworkDebugViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var requests: [NetworkRequest] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "网络请求"
        view.backgroundColor = ThemeTokens.Color.background

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(NetworkRequestCell.self, forCellReuseIdentifier: "RequestCell")
        tableView.contentInsetAdjustmentBehavior = .never

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "清除",
            style: .plain,
            target: self,
            action: #selector(clearRequests)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRequests()
    }

    private func refreshRequests() {
        requests = MockNetworkRequestStore.shared.getRecentRequests()
        tableView.reloadData()
    }

    @objc private func clearRequests() {
        requests.removeAll()
        MockNetworkRequestStore.shared.clearRequests()
        tableView.reloadData()
    }
}

extension NetworkDebugViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RequestCell", for: indexPath) as! NetworkRequestCell
        let request = requests[indexPath.row]
        cell.configure(with: request)
        return cell
    }
}

extension NetworkDebugViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return requests.isEmpty ? nil : "最近请求"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return requests.isEmpty ? "暂无网络请求记录" : nil
    }
}

struct NetworkRequest {
    let id: String
    let url: String
    let method: String
    let statusCode: Int
    let duration: TimeInterval
    let timestamp: Date
}

final class NetworkRequestCell: UITableViewCell {
    static let reuseIdentifier = "NetworkRequestCell"

    private let urlLabel = UILabel()
    private let statusLabel = UILabel()
    private let methodLabel = UILabel()
    private let durationLabel = UILabel()
    private let stackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center

        methodLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        methodLabel.textColor = ThemeTokens.Color.primary
        methodLabel.textAlignment = .center
        methodLabel.setContentHuggingPriority(.required, for: .horizontal)

        statusLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        statusLabel.textAlignment = .center
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)

        urlLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        urlLabel.textColor = ThemeTokens.Color.text

        durationLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        durationLabel.textColor = ThemeTokens.Color.textSecondary
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)

        stackView.addArrangedSubview(methodLabel)
        stackView.addArrangedSubview(statusLabel)

        contentView.addSubview(urlLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(stackView)

        [urlLabel, durationLabel, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            urlLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            urlLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            urlLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),

            durationLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stackView.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func configure(with request: NetworkRequest) {
        urlLabel.text = request.url
        methodLabel.text = request.method
        statusLabel.text = "\(request.statusCode)"
        durationLabel.text = String(format: "%.0fms", request.duration * 1000)

        statusLabel.textColor = statusCodeColor(request.statusCode)
    }

    private func statusCodeColor(_ code: Int) -> UIColor {
        switch code {
        case 200..<300:
            return ThemeTokens.Color.success
        case 300..<400:
            return ThemeTokens.Color.warning
        case 400..<500:
            return ThemeTokens.Color.error
        case 500..<600:
            return ThemeTokens.Color.error
        default:
            return ThemeTokens.Color.textSecondary
        }
    }
}

class MockNetworkRequestStore {
    static let shared = MockNetworkRequestStore()
    private var requests: [NetworkRequest] = []

    private init() {
        generateMockData()
    }

    private func generateMockData() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        requests = [
            NetworkRequest(
                id: UUID().uuidString,
                url: "https://api.example.com/manifest",
                method: "GET",
                statusCode: 200,
                duration: 0.245,
                timestamp: Date()
            ),
            NetworkRequest(
                id: UUID().uuidString,
                url: "https://cdn.example.com/style.css",
                method: "GET",
                statusCode: 200,
                duration: 0.089,
                timestamp: Date().addingTimeInterval(-1)
            ),
            NetworkRequest(
                id: UUID().uuidString,
                url: "https://api.example.com/push",
                method: "POST",
                statusCode: 201,
                duration: 0.512,
                timestamp: Date().addingTimeInterval(-2)
            ),
            NetworkRequest(
                id: UUID().uuidString,
                url: "https://cdn.example.com/app.js",
                method: "GET",
                statusCode: 200,
                duration: 1.234,
                timestamp: Date().addingTimeInterval(-3)
            ),
            NetworkRequest(
                id: UUID().uuidString,
                url: "https://api.example.com/command",
                method: "POST",
                statusCode: 404,
                duration: 0.312,
                timestamp: Date().addingTimeInterval(-4)
            ),
            NetworkRequest(
                id: UUID().uuidString,
                url: "https://cdn.example.com/image.png",
                method: "GET",
                statusCode: 200,
                duration: 0.156,
                timestamp: Date().addingTimeInterval(-5)
            )
        ]
    }

    func getRecentRequests() -> [NetworkRequest] {
        return requests
    }

    func clearRequests() {
        requests.removeAll()
    }
}

#endif
