import Foundation
import WebBridgeKit

enum WebCacheMode: String, CaseIterable, Identifiable {
    case online
    case cacheFirst
    case fullOffline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .online:
            return "在线"
        case .cacheFirst:
            return "缓存优先"
        case .fullOffline:
            return "完全离线"
        }
    }

    var subtitle: String {
        switch self {
        case .online:
            return "强制走网络，适合验证首开"
        case .cacheFirst:
            return "优先读取缓存，失败再回源"
        case .fullOffline:
            return "验证 manifest/offline package"
        }
    }
}

enum WebCacheHomeAction {
    case openCacheDashboard
    case openCacheManagement
}

final class WebCacheHomeViewModel: ObservableObject {
    @Published var urlText = "http://localhost:8081/test_resources/cache-demo.html"
    @Published var selectedMode: WebCacheMode = .cacheFirst
    @Published var resultState: ResultPanel.State = .idle
    @Published var resultDetail = ""
    @Published var showingClearAllConfirmation = false

    @Published var totalSize = "--"
    @Published var totalEntries = "--"
    @Published var activeSystems = "--"
    @Published var pinnedCount = "--"
    @Published var summaryText = "等待加载缓存统计"

    private let dashboard = CacheDashboardViewModelObservable()

    func refreshStats() {
        dashboard.loadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            self.totalSize = dashboard.summaryValues.totalSize
            self.totalEntries = dashboard.summaryValues.totalEntries
            self.activeSystems = dashboard.summaryValues.activeSystems
            self.pinnedCount = dashboard.summaryValues.pinnedCount
            self.summaryText = dashboard.summaryText
        }
    }

    func normalizedURL() -> URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    func markOpenStarted() {
        resultState = .loading("正在按 \(selectedMode.title) 模式打开页面")
        resultDetail = """
        {
          "url": "\(urlText)",
          "mode": "\(selectedMode.rawValue)"
        }
        """
    }

    func markOpenResult(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            resultState = .success("页面打开请求已发送")
        case .failure(let error):
            resultState = .failure(error.localizedDescription)
        }
    }

    func markInvalidURL() {
        resultState = .failure("URL 无效，请输入完整 URL 或域名")
        resultDetail = """
        {
          "input": "\(urlText)"
        }
        """
    }

    func clearAllCache() {
        resultState = .loading("正在清理所有 Web 缓存")
        WebCacheManager.shared.clearAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.resultState = .success("已触发全部缓存清理")
            self.resultDetail = """
            {
              "operation": "clearAll",
              "source": "WebCacheManager"
            }
            """
            self.refreshStats()
        }
    }
}
