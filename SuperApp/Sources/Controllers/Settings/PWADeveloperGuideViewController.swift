import UIKit
import WebBridgeKit

final class PWADeveloperGuideViewController: UITableViewController {
    private let sections: [(String, [String])] = [
        ("标准优先", [
            "保持标准 PWA：manifest、Service Worker、localStorage 和 IndexedDB 均可照常使用。",
            "网关清单只额外声明 appId、允许路由、原生能力和离线策略。"
        ]),
        ("可选增强", [
            "通知：APNs 参数只携带 appId、route 和参数，宿主验证后精确启动。",
            "离线：缓存优先可秒开并恢复状态；强离线使用签名、哈希校验和原子安装资源包。",
            "Bridge：WebBridgeKit.navigation.back() 返回宿主历史；WebBridgeKit.navigation.close() 退出当前 PWA。"
        ]),
        ("权限边界", [
            "PWA 先在自身 UI 发起能力请求，再由宿主展示原生授权；用户可在应用中心查看授权。",
            "通知只能导航，不能自动批准权限、支付、删除或其他敏感操作。"
        ])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "PWA 开发接入"
        tableView.accessibilityIdentifier = "pwaGuide.table"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "guide")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].1.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].0 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "guide", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = sections[indexPath.section].1[indexPath.row]
        content.textProperties.numberOfLines = 0
        cell.contentConfiguration = content
        return cell
    }
}
