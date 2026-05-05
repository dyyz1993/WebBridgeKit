//
//  PassphraseManager.swift
//  SuperApp
//
//  Created on 2026-02-07.
//

import Foundation
import UIKit
import WebBridgeKit

/// 口令识别管理器
/// 负责在应用进入前台时识别剪贴板中的口令，并根据口令获取配置或打开应用
class PassphraseManager {

    static let shared = PassphraseManager()

    private init() {}

    /// 检查并处理剪贴板中的口令
    func checkClipboard(from viewController: UIViewController) {
        guard let clipboardString = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardString.isEmpty else {
            return
        }

        // 识别格式，例如：bark://{code} 或者特定的识别码
        if clipboardString.hasPrefix("bark://") {
            let code = clipboardString.replacingOccurrences(of: "bark://", with: "")
            handlePassphrase(code, from: viewController)
            // 处理完后清空剪贴板，避免重复弹出（可选）
            // UIPasteboard.general.string = ""
        } else if isPotentialPassphrase(clipboardString) {
            // 如果符合某种口令格式（如 6 位字母数字）
            showRecognitionAlert(for: clipboardString, from: viewController)
        }
    }

    private func isPotentialPassphrase(_ string: String) -> Bool {
        // 简单的正则表达式：6-12位字母数字
        let pattern = "^[a-zA-Z0-9]{6,12}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }

    private func showRecognitionAlert(for code: String, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "检测到口令",
            message: "是否识别口令: \(code) ?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "识别", style: .default) { [weak self] _ in
            self?.handlePassphrase(code, from: viewController)
        })

        viewController.present(alert, animated: true)
    }

    private func handlePassphrase(_ code: String, from viewController: UIViewController) {
        print("🔍 [Passphrase] Handling code: \(code)")

        guard let config = ServerConfigManager.shared.getActiveConfig() else {
            print("❌ [Passphrase] No active server config found")
            return
        }

        let baseURL = config.baseURL ?? ""
        let apiEndpoint = config.apiEndpoint ?? ""

        let urlString = "\(baseURL)\(apiEndpoint)/passphrase/resolve?code=\(code)"
        guard let url = URL(string: urlString) else { return }

        // 显示加载中
        // SVProgressHUD.show(withStatus: "正在识别口令...")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // 如果有永久密钥，带上认证
        let permanentKey = APIKeyManager.shared.getPermanentKey()
        request.addValue("Bearer \(permanentKey.value)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                // SVProgressHUD.dismiss()

                if let error = error {
                    self?.showAlert(title: "识别失败", message: error.localizedDescription, from: viewController)
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let result = json["data"] as? [String: Any] else {
                    self?.showAlert(title: "识别失败", message: "服务器返回数据格式错误", from: viewController)
                    return
                }

                self?.processResolutionResult(result, from: viewController)
            }
        }.resume()
    }

    private func processResolutionResult(_ result: [String: Any], from viewController: UIViewController) {
        let type = result["type"] as? String // "url", "app", "config"

        if type == "url" || type == "app", let urlString = result["url"] as? String, let url = URL(string: urlString) {
            let params = result["params"] as? [String: Any]
            let stringParams = params?.compactMapValues { "\($0)" }
            let browserParams = WebBrowserParams(payload: stringParams)
            WebBrowserManager.shared.openBrowser(url: url, params: browserParams, from: viewController)
        } else if type == "config", result["config"] is [String: Any] {
            // 处理配置更新（例如自动配置服务器地址）
            self.showAlert(title: "配置更新", message: "识别到服务器配置，是否立即应用？", from: viewController) {
                // 应用配置逻辑
            }
        } else {
            self.showAlert(title: "识别成功", message: "口令解析成功，但未关联任何已知操作。", from: viewController)
        }
    }

    private func showAlert(title: String, message: String, from viewController: UIViewController, action: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            action?()
        })
        viewController.present(alert, animated: true)
    }
}
