//
//  PushRelayManager.swift
//  SuperApp
//

import Foundation
import UserNotifications
import WebBridgeKit

struct SSEPushPayload {
    let title: String
    let body: String
    let subtitle: String?
    let url: String
    let sound: String?
    let badge: Int
    let group: String?
    let category: String?
    let thread: String?
    let appid: String?
    let mode: String?
    let icon: String?
    let markdownBody: String?
    let level: String?
    let image: String?
    let action: [String: Any]?
    let copy: String?
    let autoCopy: String?
    let ciphertext: String?
    let iv: String?
    let call: String?

    init(data: [String: Any]) {
        title = data["title"] as? String ?? "通知"
        body = data["body"] as? String ?? ""
        subtitle = data["subtitle"] as? String
        url = data["url"] as? String ?? ""
        sound = data["sound"] as? String
        badge = data["badge"] as? Int ?? 0
        group = data["group"] as? String
        category = data["category"] as? String
        thread = data["thread"] as? String
        appid = data["appid"] as? String
        mode = data["mode"] as? String
        icon = data["icon"] as? String
        markdownBody = data["markdown"] as? String
        level = data["level"] as? String
        image = data["image"] as? String
        action = data["action"] as? [String: Any]
        copy = data["copy"] as? String
        autoCopy = data["autoCopy"] as? String
        ciphertext = data["ciphertext"] as? String
        iv = data["iv"] as? String
        call = data["call"] as? String
    }
}

final class PushRelayManager: NSObject, URLSessionDataDelegate {
    static let shared = PushRelayManager()

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var reconnectTimer: Timer?
    private var isConnected = false
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 10
    private var buffer = ""

    private let baseURL: String = {
        ServerConfigManager.shared.getActiveBaseURL()
            ?? "https://wbk.shanbox.19930810.xyz:8443"
    }()

    private override init() { super.init() }

    func connect() {
        guard !isConnected else { return }
        guard let url = URL(string: baseURL + "/ws/stream") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(INT_MAX)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
        isConnected = true
        reconnectAttempts = 0
        print("[PushRelay] SSE connecting: \(url)")
    }

    func disconnect() {
        reconnectTimer?.invalidate(); reconnectTimer = nil
        dataTask?.cancel(); dataTask = nil
        session?.invalidateAndCancel(); session = nil
        isConnected = false; buffer = ""
        print("[PushRelay] Disconnected")
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("[PushRelay] SSE connected, status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        while let range = buffer.range(of: "\n\n") {
            let eventText = String(buffer[..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            processSSE(eventText)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { print("[PushRelay] Stream ended: \(error.localizedDescription)") }
        scheduleReconnect()
    }

    // MARK: - SSE Processing

    private func processSSE(_ text: String) {
        for line in text.components(separatedBy: "\n") {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard let data = jsonStr.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { continue }
            if type == "connected" { print("[PushRelay] SSE connected"); continue }
            guard type == "push", let pushData = json["data"] as? [String: Any] else { continue }
            let payload = SSEPushPayload(data: pushData)
            showLocalNotification(payload)
        }
    }

    // MARK: - Notification Delivery

    private func showLocalNotification(_ p: SSEPushPayload) {
        let content = UNMutableNotificationContent()
        content.title = p.title

        if let markdown = p.markdownBody, !markdown.isEmpty {
            content.body = p.body.isEmpty ? p.title : p.body
        } else {
            content.body = p.body
        }

        if let subtitle = p.subtitle { content.subtitle = subtitle }

        if p.mode == "silent" || p.mode == "passive" {
            content.sound = nil
        } else if let sound = p.sound, !sound.isEmpty {
            if sound == "default" {
                content.sound = UNNotificationSound.default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            }
        } else {
            content.sound = UNNotificationSound.default
        }

        if p.badge > 0 { content.badge = NSNumber(value: p.badge) }

        var userInfo: [String: Any] = ["channel": "ws-push"]
        if !p.url.isEmpty { userInfo["url"] = p.url }
        if let appid = p.appid { userInfo["appid"] = appid }
        if let mode = p.mode { userInfo["mode"] = mode }
        if let md = p.markdownBody, !md.isEmpty { userInfo["markdown"] = md }
        if let level = p.level { userInfo["level"] = level }
        if let image = p.image { userInfo["image"] = image }
        if let action = p.action { userInfo["action"] = action }
        if let copy = p.copy { userInfo["copy"] = copy }
        if let autoCopy = p.autoCopy { userInfo["autoCopy"] = autoCopy }
        if let ciphertext = p.ciphertext { userInfo["ciphertext"] = ciphertext }
        if let iv = p.iv { userInfo["iv"] = iv }
        if let call = p.call { userInfo["call"] = call }
        content.userInfo = userInfo

        let threadId = p.thread ?? p.group
        if let tid = threadId, !tid.isEmpty {
            content.threadIdentifier = tid
            content.summaryArgument = p.title
        }
        if let category = p.category { content.categoryIdentifier = category }

        if let iconStr = p.icon, !iconStr.isEmpty, let iconURL = URL(string: iconStr) {
            deliverWithIcon(content: content, iconURL: iconURL)
        } else {
            deliverNow(content: content)
        }
    }

    private func deliverWithIcon(content: UNMutableNotificationContent, iconURL: URL) {
        URLSession.shared.downloadTask(with: iconURL) { tempURL, _, error in
            let finalContent = content
            defer { self.deliverNow(content: finalContent) }
            guard let tempURL = tempURL, error == nil else { return }
            let ext = iconURL.pathExtension.isEmpty ? "png" : iconURL.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("notif_icon_\(UUID().uuidString).\(ext)")
            do {
                try FileManager.default.moveItem(at: tempURL, to: dest)
                if let att = try? UNNotificationAttachment(identifier: "icon", url: dest, options: nil) {
                    finalContent.attachments = [att]
                }
            } catch { print("[PushRelay] Icon attach failed: \(error)") }
        }.resume()
    }

    private func deliverNow(content: UNMutableNotificationContent) {
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { err in
            if let err = err {
                print("[PushRelay] Failed: \(err)")
            } else {
                print("[PushRelay] ✅ Shown: \(content.title)")
            }
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[PushRelay] Max reconnect reached")
            disconnect(); return
        }
        isConnected = false
        reconnectAttempts += 1
        let delay = min(3.0 * Double(reconnectAttempts), 30.0)
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.disconnect(); self?.connect()
        }
        print("[PushRelay] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")
    }
}
