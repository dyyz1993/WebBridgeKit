#if DEBUG
import Foundation
import UIKit
import WebBridgeKit

enum BridgeLabAction {
    case openLegacyShowcase
    case openDebugLogs
}

struct BridgeCommand: Identifiable, Equatable {
    let id: String
    let title: String
    let handler: String
    let summary: String
    let samplePayload: String
}

struct BridgeCommandGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: LucideIcon
    let commands: [BridgeCommand]
}

final class BridgeLabViewModel: ObservableObject {
    @Published var groups: [BridgeCommandGroup] = BridgeLabViewModel.makeGroups()
    @Published var selectedGroupID = "cache"
    @Published var selectedCommandID = "cache.stats"
    @Published var parameterText = BridgeLabViewModel.makeGroups().first?.commands.first?.samplePayload ?? "{}"
    @Published var resultState: ResultPanel.State = .idle
    @Published var resultDetail = ""

    var selectedGroup: BridgeCommandGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    var selectedCommand: BridgeCommand? {
        selectedGroup?.commands.first { $0.id == selectedCommandID }
    }

    func selectGroup(_ group: BridgeCommandGroup) {
        selectedGroupID = group.id
        selectedCommandID = group.commands.first?.id ?? ""
        parameterText = group.commands.first?.samplePayload ?? "{}"
        resultState = .idle
        resultDetail = ""
    }

    func selectCommand(_ command: BridgeCommand) {
        selectedCommandID = command.id
        parameterText = command.samplePayload
        resultState = .idle
        resultDetail = ""
    }

    func executeSelectedCommand() {
        guard let command = selectedCommand else {
            resultState = .failure("请选择一个 JSBridge 命令")
            return
        }

        guard let data = parameterText.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(jsonObject) else {
            resultState = .failure("参数不是合法 JSON")
            resultDetail = parameterText
            return
        }

        resultState = .success("命令已完成结构化校验，等待接入真实 WebView 执行器")
        resultDetail = """
        {
          "command": "\(command.id)",
          "handler": "\(command.handler)",
          "status": "validated",
          "next": "wire to Resources/WebBridge.js test page"
        }
        """
    }

    func copyResult() {
        UIPasteboard.general.string = resultDetail.isEmpty ? parameterText : resultDetail
    }

    private static func makeGroups() -> [BridgeCommandGroup] {
        [
            BridgeCommandGroup(
                id: "cache",
                title: "Cache",
                icon: .hardDrive,
                commands: [
                    BridgeCommand(
                        id: "cache.stats",
                        title: "读取缓存统计",
                        handler: "WebCacheDebugHandler",
                        summary: "读取 cache subsystem 状态和资源统计",
                        samplePayload: #"{"method":"getStats"}"#
                    ),
                    BridgeCommand(
                        id: "cache.clear",
                        title: "清理页面缓存",
                        handler: "WebPageCacheHandler",
                        summary: "触发页面缓存清理并返回 cleared 状态",
                        samplePayload: #"{"method":"clear","pageKey":"demo"}"#
                    )
                ]
            ),
            BridgeCommandGroup(
                id: "navigation",
                title: "Navigation",
                icon: .link,
                commands: [
                    BridgeCommand(
                        id: "navigation.open",
                        title: "打开页面",
                        handler: "WebOpenPageHandler",
                        summary: "从 JSBridge 打开指定 URL",
                        samplePayload: #"{"url":"https://example.com","mode":"normal"}"#
                    ),
                    BridgeCommand(
                        id: "navigation.back",
                        title: "返回",
                        handler: "WebGoBackHandler",
                        summary: "请求 WebView 或原生导航返回",
                        samplePayload: #"{"animated":true}"#
                    )
                ]
            ),
            BridgeCommandGroup(
                id: "device",
                title: "Device",
                icon: .server,
                commands: [
                    BridgeCommand(
                        id: "device.info",
                        title: "系统信息",
                        handler: "WebSystemInfoHandler",
                        summary: "读取设备、系统、App 环境信息",
                        samplePayload: #"{}"#
                    ),
                    BridgeCommand(
                        id: "device.haptic",
                        title: "触觉反馈",
                        handler: "WebHapticHandler",
                        summary: "触发原生 haptic feedback",
                        samplePayload: #"{"style":"medium"}"#
                    )
                ]
            ),
            BridgeCommandGroup(
                id: "interaction",
                title: "Interaction",
                icon: .clipboard,
                commands: [
                    BridgeCommand(
                        id: "interaction.clipboard",
                        title: "剪贴板",
                        handler: "WebClipboardHandler",
                        summary: "读取或写入剪贴板内容",
                        samplePayload: #"{"action":"write","text":"hello"}"#
                    ),
                    BridgeCommand(
                        id: "interaction.share",
                        title: "分享",
                        handler: "WebShareHandler",
                        summary: "调起系统分享面板",
                        samplePayload: #"{"title":"WebBridgeKit","url":"https://example.com"}"#
                    )
                ]
            ),
            BridgeCommandGroup(
                id: "permission",
                title: "Permission",
                icon: .shield,
                commands: [
                    BridgeCommand(
                        id: "permission.status",
                        title: "权限状态",
                        handler: "WebPermissionStatusHandler",
                        summary: "查询相机、定位、通知等权限状态",
                        samplePayload: #"{"permission":"camera"}"#
                    )
                ]
            )
        ]
    }
}

#endif
