//
//  NotificationDebugViewController.swift
//  SuperApp
//
//  Created on 2026-05-07.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift

class NotificationDebugViewController: UIViewController {

    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let mainStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        return sv
    }()

    private let titleInput = makeTextField(placeholder: "标题")
    private let subtitleInput = makeTextField(placeholder: "副标题")
    private let bodyInput: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 14)
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 8
        tv.heightAnchor.constraint(equalToConstant: 80).isActive = true
        return tv
    }()
    private let markdownSwitch = UISwitch()

    private let levelSegment = UISegmentedControl(items: ["active", "timeSensitive", "passive", "critical"])
    private let volumeSlider: UISlider = {
        let s = UISlider()
        s.minimumValue = 0
        s.maximumValue = 10
        s.value = 5
        s.isHidden = true
        return s
    }()
    private let soundInput = makeTextField(placeholder: "声音")
    private let callSwitch = UISwitch()
    private let badgeInput = makeTextField(placeholder: "角标数字")

    private let iconInput = makeTextField(placeholder: "Icon URL")
    private let imageInput = makeTextField(placeholder: "Image URL")
    private let imagePreview: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 8
        iv.backgroundColor = .tertiarySystemGroupedBackground
        return iv
    }()

    private let urlInput = makeTextField(placeholder: "跳转 URL")
    private let groupInput = makeTextField(placeholder: "分组")
    private let autocopySwitch = UISwitch()
    private let archiveSwitch = UISwitch()

    private let notifIdInput = makeTextField(placeholder: "通知 ID")

    private let methodSegment = UISegmentedControl(items: ["GET", "POST"])
    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("发送", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        return btn
    }()

    private let responseView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.isEditable = false
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 8
        tv.heightAnchor.constraint(equalToConstant: 120).isActive = true
        tv.text = "等待发送..."
        tv.textColor = .secondaryLabel
        return tv
    }()

    private let sounds = ["alarm", "anticipation", "bell", "birdsong", "bloom", "calypso", "chime", "choochoo", "descent", "electronic", "fanfare", "glass", "horn", "lapis", "minuet", "multiway", "newmail", "noire", "paper", "payment", "pop", "pow", "promotion", "rings", "sencha", "sherwood", "silo", "stargate", "synthesis", "telegraph", "tidings", "tumble", "update", "vibra", "whistle"]
    private let soundPicker = UIPickerView()

    private static func makeTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.borderStyle = .roundedRect
        tf.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return tf
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "调试面板"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        setupPicker()
        setupTemplates()
        setupImagePreview()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(mainStack)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        mainStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
            make.width.equalTo(view).offset(-32)
            make.bottom.equalToSuperview().offset(-32)
        }

        addSection(title: "内容", views: [
            makeRow(label: "标题", view: titleInput),
            makeRow(label: "副标题", view: subtitleInput),
            makeVerticalRow(label: "正文", view: bodyInput),
            makeRow(label: "Markdown", view: markdownSwitch)
        ])

        addSection(title: "行为", views: [
            makeVerticalRow(label: "中断级别", view: levelSegment),
            makeRow(label: "音量", view: volumeSlider),
            makeRow(label: "声音", view: soundInput),
            makeRow(label: "电话模式", view: callSwitch),
            makeRow(label: "角标", view: badgeInput)
        ])

        addSection(title: "视觉", views: [
            makeRow(label: "Icon", view: iconInput),
            makeRow(label: "图片", view: imageInput),
            imagePreview
        ])

        addSection(title: "操作", views: [
            makeRow(label: "URL", view: urlInput),
            makeRow(label: "分组", view: groupInput),
            makeRow(label: "自动复制", view: autocopySwitch),
            makeRow(label: "归档", view: archiveSwitch)
        ])

        addSection(title: "高级", views: [
            makeRow(label: "通知 ID", view: notifIdInput)
        ])

        addSection(title: "发送", views: [
            makeVerticalRow(label: "方法", view: methodSegment),
            sendButton
        ])

        addSection(title: "响应", views: [
            responseView
        ])

        addSection(title: "模板", views: [
            makeTemplateGrid()
        ])

        sendButton.addTarget(self, action: #selector(sendNotification), for: .touchUpInside)
        levelSegment.addTarget(self, action: #selector(levelChanged), for: .valueChanged)
    }

    private func addSection(title: String, views: [UIView]) {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16

        let header = UILabel()
        header.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        header.textColor = .secondaryLabel
        header.text = title

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 10

        card.addSubview(header)
        card.addSubview(stack)

        header.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.left.right.equalToSuperview().inset(16)
        }
        stack.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-14)
        }

        mainStack.addArrangedSubview(card)
    }

    private func makeRow(label: String, view: UIView) -> UIStackView {
        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .label
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.widthAnchor.constraint(equalToConstant: 72).isActive = true

        let row = UIStackView(arrangedSubviews: [lbl, view])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    private func makeVerticalRow(label: String, view: UIView) -> UIStackView {
        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .label

        let row = UIStackView(arrangedSubviews: [lbl, view])
        row.axis = .vertical
        row.spacing = 6
        return row
    }

    private func makeTemplateGrid() -> UIStackView {
        let templates: [(String, String, String, String, String, String, String, Bool)] = [
            ("简单通知", "测试通知", "这是一条测试通知", "", "active", "", "", false),
            ("图片通知", "图片通知", "查看图片", "https://via.placeholder.com/300", "active", "", "", false),
            ("紧急通知", "紧急通知", "请立即查看!", "", "timeSensitive", "alarm", "", false),
            ("Markdown", "Markdown", "# Hello\n- Item 1\n- Item 2", "", "active", "", "", true),
            ("链接通知", "链接", "点击打开", "", "active", "", "https://example.com", false),
            ("加密通知", "加密通知", "encrypted content", "", "active", "", "", false)
        ]

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 8

        for i in stride(from: 0, to: templates.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually

            for j in i..<min(i + 2, templates.count) {
                let t = templates[j]
                let btn = UIButton(type: .system)
                btn.setTitle(t.0, for: .normal)
                btn.layer.cornerRadius = 8
                btn.layer.borderWidth = 1
                btn.layer.borderColor = UIColor.systemBlue.cgColor
                btn.tag = j
                btn.addTarget(self, action: #selector(applyTemplate(_:)), for: .touchUpInside)
                row.addArrangedSubview(btn)
            }
            outerStack.addArrangedSubview(row)
        }
        return outerStack
    }

    private func setupPicker() {
        soundPicker.dataSource = self
        soundPicker.delegate = self
        soundInput.inputView = soundPicker

        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(pickerDone))
        ]
        toolbar.sizeToFit()
        soundInput.inputAccessoryView = toolbar
    }

    private func setupImagePreview() {
        imagePreview.snp.makeConstraints { make in
            make.height.equalTo(120)
        }
        imageInput.addTarget(self, action: #selector(imageURLChanged), for: .editingDidEnd)
    }

    private func setupTemplates() {
        let templates: [(String, String, String, String, String, String, String, Bool)] = [
            ("简单通知", "测试通知", "这是一条测试通知", "", "active", "", "", false),
            ("图片通知", "图片通知", "查看图片", "https://via.placeholder.com/300", "active", "", "", false),
            ("紧急通知", "紧急通知", "请立即查看!", "", "timeSensitive", "alarm", "", false),
            ("Markdown", "Markdown", "# Hello\n- Item 1\n- Item 2", "", "active", "", "", true),
            ("链接通知", "链接", "点击打开", "", "active", "", "https://example.com", false),
            ("加密通知", "加密通知", "encrypted content", "", "active", "", "", false)
        ]
        objc_setAssociatedObject(self, "templates", templates, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc private func applyTemplate(_ sender: UIButton) {
        guard let templates = objc_getAssociatedObject(self, "templates") as? [(String, String, String, String, String, String, String, Bool)] else { return }
        guard sender.tag < templates.count else { return }
        let t = templates[sender.tag]
        titleInput.text = t.1
        bodyInput.text = t.2
        imageInput.text = t.3
        let levels = ["active", "timeSensitive", "passive", "critical"]
        if let idx = levels.firstIndex(of: t.4) { levelSegment.selectedSegmentIndex = idx }
        soundInput.text = t.5
        urlInput.text = t.6
        markdownSwitch.isOn = t.7
        if t.7 { bodyInput.text = t.2 }
    }

    @objc private func levelChanged() {
        volumeSlider.isHidden = levelSegment.selectedSegmentIndex != 3
    }

    @objc private func pickerDone() {
        let row = soundPicker.selectedRow(inComponent: 0)
        soundInput.text = sounds[row]
        soundInput.resignFirstResponder()
    }

    @objc private func imageURLChanged() {
        guard let urlStr = imageInput.text, let url = URL(string: urlStr), !urlStr.isEmpty else {
            imagePreview.image = nil
            return
        }
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                DispatchQueue.main.async { self.imagePreview.image = img }
            }
        }
    }

    @objc private func sendNotification() {
        let server = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.server") ?? "https://api.day.app"
        let key = UserDefaults.standard.string(forKey: "com.webbridgekit.bark.key") ?? ""
        guard !key.isEmpty else {
            responseView.text = "错误: Bark Key 未配置\n请在设置中配置密钥"
            responseView.textColor = .systemRed
            return
        }

        let title = titleInput.text ?? ""
        let body = bodyInput.text ?? ""
        guard !title.isEmpty else {
            responseView.text = "错误: 标题不能为空"
            responseView.textColor = .systemRed
            return
        }

        let isPost = methodSegment.selectedSegmentIndex == 1
        let level = ["active", "timeSensitive", "passive", "critical"][levelSegment.selectedSegmentIndex]
        let sound = soundInput.text ?? ""
        let badge = badgeInput.text ?? ""
        let icon = iconInput.text ?? ""
        let image = imageInput.text ?? ""
        let url = urlInput.text ?? ""
        let group = groupInput.text ?? ""
        let notifId = notifIdInput.text ?? ""

        responseView.text = "发送中..."
        responseView.textColor = .secondaryLabel

        if isPost {
            sendPOST(server: server, key: key, title: title, body: body, level: level, sound: sound, badge: badge, icon: icon, image: image, url: url, group: group, notifId: notifId)
        } else {
            sendGET(server: server, key: key, title: title, body: body, level: level, sound: sound, badge: badge, icon: icon, image: image, url: url, group: group, notifId: notifId)
        }
    }

    private func sendGET(server: String, key: String, title: String, body: String, level: String, sound: String, badge: String, icon: String, image: String, url: String, group: String, notifId: String) {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? body
        var path = "\(server)/\(key)/\(encodedTitle)/\(encodedBody)"

        var items: [URLQueryItem] = []
        if !level.isEmpty && level != "active" { items.append(URLQueryItem(name: "level", value: level)) }
        if !sound.isEmpty { items.append(URLQueryItem(name: "sound", value: sound)) }
        if !badge.isEmpty, let b = Int(badge) { items.append(URLQueryItem(name: "badge", value: "\(b)")) }
        if !icon.isEmpty { items.append(URLQueryItem(name: "icon", value: icon)) }
        if !image.isEmpty { items.append(URLQueryItem(name: "img", value: image)) }
        if !url.isEmpty { items.append(URLQueryItem(name: "url", value: url)) }
        if !group.isEmpty { items.append(URLQueryItem(name: "group", value: group)) }
        if autocopySwitch.isOn { items.append(URLQueryItem(name: "copyable", value: "1")) }
        if archiveSwitch.isOn { items.append(URLQueryItem(name: "isArchive", value: "1")) }
        if !notifId.isEmpty { items.append(URLQueryItem(name: "id", value: notifId)) }

        if !items.isEmpty {
            var comps = URLComponents(string: path)
            comps?.queryItems = items
            path = comps?.string ?? path
        }

        guard let requestURL = URL(string: path) else {
            responseView.text = "错误: URL 构建失败"
            responseView.textColor = .systemRed
            return
        }

        let startTime = Date()
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startTime))
            DispatchQueue.main.async {
                self?.handleResponse(data: data, response: response, error: error, elapsed: elapsed)
            }
        }.resume()
    }

    private func sendPOST(server: String, key: String, title: String, body: String, level: String, sound: String, badge: String, icon: String, image: String, url: String, group: String, notifId: String) {
        guard let requestURL = URL(string: "\(server)/\(key)") else {
            responseView.text = "错误: URL 构建失败"
            responseView.textColor = .systemRed
            return
        }

        var bodyDict: [String: Any] = [
            "title": title,
            "body": body
        ]
        if !level.isEmpty { bodyDict["level"] = level }
        if !sound.isEmpty { bodyDict["sound"] = sound }
        if !badge.isEmpty, let b = Int(badge) { bodyDict["badge"] = b }
        if !icon.isEmpty { bodyDict["icon"] = icon }
        if !image.isEmpty { bodyDict["img"] = image }
        if !url.isEmpty { bodyDict["url"] = url }
        if !group.isEmpty { bodyDict["group"] = group }
        if autocopySwitch.isOn { bodyDict["copyable"] = "1" }
        if archiveSwitch.isOn { bodyDict["isArchive"] = "1" }
        if !notifId.isEmpty { bodyDict["id"] = notifId }
        if callSwitch.isOn { bodyDict["call"] = "1" }
        if markdownSwitch.isOn { bodyDict["ismarkdown"] = "1" }
        if level == "critical" { bodyDict["volume"] = Int(volumeSlider.value) }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        let startTime = Date()
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startTime))
            DispatchQueue.main.async {
                self?.handleResponse(data: data, response: response, error: error, elapsed: elapsed)
            }
        }.resume()
    }

    private func handleResponse(data: Data?, response: URLResponse?, error: Error?, elapsed: String) {
        if let error = error {
            responseView.text = "请求失败 (\(elapsed)s)\n\n错误: \(error.localizedDescription)"
            responseView.textColor = .systemRed
            return
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(空)"

        if (200...299).contains(statusCode) {
            responseView.text = "成功 (\(elapsed)s)\n状态码: \(statusCode)\n\n\(bodyStr)"
            responseView.textColor = .systemGreen
        } else {
            responseView.text = "失败 (\(elapsed)s)\n状态码: \(statusCode)\n\n\(bodyStr)"
            responseView.textColor = .systemRed
        }
    }
}

extension NotificationDebugViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { sounds.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { sounds[row] }
}
