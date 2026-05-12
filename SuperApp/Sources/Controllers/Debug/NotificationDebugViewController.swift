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
import WebBridgeKit

private struct NotificationParams {
    let server: String
    let key: String
    let title: String
    let body: String
    let level: String
    let sound: String
    let badge: String
    let icon: String
    let image: String
    let url: String
    let group: String
    let notifId: String
}

class NotificationDebugViewController: UIViewController {

    private let disposeBag = DisposeBag()

    private let scrollView = UIScrollView()
    private let mainStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = ThemeTokens.Spacing.md
        return sv
    }()

    private let titleInput = makeTextField(placeholder: L10n.tr("notif_debug.field.title"))
    private let subtitleInput = makeTextField(placeholder: L10n.tr("notif_debug.field.subtitle"))
    private let bodyInput: UITextView = {
        let tv = UITextView()
        tv.font = ThemeTokens.Typography.body
        tv.layer.borderColor = ThemeTokens.Color.border.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = ThemeTokens.CornerRadius.sm
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
    private let soundInput = makeTextField(placeholder: L10n.tr("notif_debug.field.sound"))
    private let callSwitch = UISwitch()
    private let badgeInput = makeTextField(placeholder: L10n.tr("notif_debug.field.badge_number"))

    private let iconInput = makeTextField(placeholder: L10n.tr("notif_debug.field.icon_url"))
    private let imageInput = makeTextField(placeholder: L10n.tr("notif_debug.field.image"))
    private let imagePreview: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = ThemeTokens.CornerRadius.md
        iv.backgroundColor = ThemeColors.current.surface
        return iv
    }()

    private let urlInput = makeTextField(placeholder: L10n.tr("notif_debug.field.url"))
    private let groupInput = makeTextField(placeholder: L10n.tr("notif_debug.field.group"))
    private let autocopySwitch = UISwitch()
    private let archiveSwitch = UISwitch()

    private let notifIdInput = makeTextField(placeholder: L10n.tr("notif_debug.field.notif_id"))

    private let methodSegment = UISegmentedControl(items: ["GET", "POST"])
    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L10n.tr("notif_debug.button.send"), for: .normal)
        btn.titleLabel?.font = ThemeTokens.Typography.title3
        btn.backgroundColor = ThemeColors.current.primary
        btn.setTitleColor(ThemeColors.current.surface, for: .normal)
        btn.layer.cornerRadius = ThemeTokens.CornerRadius.lg
        return btn
    }()

    private let responseView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.isEditable = false
        tv.layer.borderColor = ThemeTokens.Color.border.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = ThemeTokens.CornerRadius.sm
        tv.heightAnchor.constraint(equalToConstant: 120).isActive = true
        tv.text = L10n.tr("notif_debug.waiting")
        tv.textColor = ThemeTokens.Color.textSecondary
        return tv
    }()

    private let sounds = [
        "alarm", "anticipation", "bell", "birdsong", "bloom", "calypso", "chime",
        "choochoo", "descent", "electronic", "fanfare", "glass", "horn", "lapis",
        "minuet", "multiway", "newmail", "noire", "paper", "payment", "pop", "pow",
        "promotion", "rings", "sencha", "sherwood", "silo", "stargate", "synthesis",
        "telegraph", "tidings", "tumble", "update", "vibra", "whistle"
    ]
    private let soundPicker = UIPickerView()

    private static func makeTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = ThemeTokens.Typography.body
        tf.borderStyle = .roundedRect
        tf.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return tf
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("notif_debug.title")
        view.backgroundColor = ThemeColors.current.background
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

        addSection(title: L10n.tr("notif_debug.section.content"), views: [
            makeRow(label: L10n.tr("notif_debug.field.title"), view: titleInput),
            makeRow(label: L10n.tr("notif_debug.field.subtitle"), view: subtitleInput),
            makeVerticalRow(label: L10n.tr("notif_debug.field.body"), view: bodyInput),
            makeRow(label: L10n.tr("notif_debug.field.markdown"), view: markdownSwitch)
        ])

        addSection(title: L10n.tr("notif_debug.section.behavior"), views: [
            makeVerticalRow(label: L10n.tr("notif_debug.field.interruption_level"), view: levelSegment),
            makeRow(label: L10n.tr("notif_debug.field.volume"), view: volumeSlider),
            makeRow(label: L10n.tr("notif_debug.field.sound"), view: soundInput),
            makeRow(label: L10n.tr("notif_debug.field.phone_mode"), view: callSwitch),
            makeRow(label: L10n.tr("notif_debug.field.badge"), view: badgeInput)
        ])

        addSection(title: L10n.tr("notif_debug.section.visual"), views: [
            makeRow(label: L10n.tr("notif_debug.field.icon"), view: iconInput),
            makeRow(label: L10n.tr("notif_debug.field.image"), view: imageInput),
            imagePreview
        ])

        addSection(title: L10n.tr("notif_debug.section.action"), views: [
            makeRow(label: L10n.tr("notif_debug.field.url"), view: urlInput),
            makeRow(label: L10n.tr("notif_debug.field.group"), view: groupInput),
            makeRow(label: L10n.tr("notif_debug.field.auto_copy"), view: autocopySwitch),
            makeRow(label: L10n.tr("notif_debug.field.archive"), view: archiveSwitch)
        ])

        addSection(title: L10n.tr("notif_debug.section.advanced"), views: [
            makeRow(label: L10n.tr("notif_debug.field.notif_id"), view: notifIdInput)
        ])

        addSection(title: L10n.tr("notif_debug.section.send"), views: [
            makeVerticalRow(label: L10n.tr("notif_debug.field.method"), view: methodSegment),
            sendButton
        ])

        addSection(title: L10n.tr("notif_debug.section.response"), views: [
            responseView
        ])

        addSection(title: L10n.tr("notif_debug.section.template"), views: [
            makeTemplateGrid()
        ])

        sendButton.addTarget(self, action: #selector(sendNotification), for: .touchUpInside)
        levelSegment.addTarget(self, action: #selector(levelChanged), for: .valueChanged)

        sendButton.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }

    private func addSection(title: String, views: [UIView]) {
        let card = UIView()
        card.backgroundColor = ThemeColors.current.cardBackground
        card.layer.cornerRadius = ThemeTokens.CornerRadius.lg

        let header = UILabel()
        header.font = ThemeTokens.Typography.footnote
        header.textColor = ThemeColors.current.textSecondary
        header.text = title

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = ThemeTokens.Spacing.sm
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
        lbl.font = ThemeTokens.Typography.subheadline
        lbl.textColor = ThemeColors.current.text
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.widthAnchor.constraint(equalToConstant: 72).isActive = true

        let row = UIStackView(arrangedSubviews: [lbl, view])
        row.axis = .horizontal
        row.spacing = ThemeTokens.Spacing.md
        row.alignment = .center
        return row
    }

    private func makeVerticalRow(label: String, view: UIView) -> UIStackView {
        let lbl = UILabel()
        lbl.text = label
        lbl.font = ThemeTokens.Typography.subheadline
        lbl.textColor = ThemeColors.current.text

        let row = UIStackView(arrangedSubviews: [lbl, view])
        row.axis = .vertical
        row.spacing = ThemeTokens.Spacing.sm
        return row
    }

    private func makeTemplateGrid() -> UIStackView {
        let templateDisplayNames = [
            L10n.tr("notif_debug.template.simple"),
            L10n.tr("notif_debug.template.image"),
            L10n.tr("notif_debug.template.urgent"),
            "Markdown",
            L10n.tr("notif_debug.template.link"),
            L10n.tr("notif_debug.template.encrypted")
        ]

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = ThemeTokens.Spacing.sm

        for i in stride(from: 0, to: templateDisplayNames.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = ThemeTokens.Spacing.sm
            row.distribution = .fillEqually

            for j in i..<min(i + 2, templateDisplayNames.count) {
                let btn = UIButton(type: .system)
                btn.setTitle(templateDisplayNames[j], for: .normal)
                btn.titleLabel?.font = ThemeTokens.Typography.footnote
                btn.layer.cornerRadius = ThemeTokens.CornerRadius.sm
                btn.layer.borderWidth = 1
                btn.layer.borderColor = ThemeColors.current.primary.cgColor
                btn.tag = j
                btn.addTarget(self, action: #selector(applyTemplate(_:)), for: .touchUpInside)
                btn.snp.makeConstraints { make in
                    make.height.equalTo(44)
                }
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
            UIBarButtonItem(title: L10n.tr("notif_debug.button.done"), style: .done, target: self, action: #selector(pickerDone))
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
            (L10n.tr("notif_debug.template.simple"), L10n.tr("notif_debug.template.test_title"), L10n.tr("notif_debug.template.test_body"), "", "active", "", "", false),
            (L10n.tr("notif_debug.template.image"), L10n.tr("notif_debug.template.image_title"), L10n.tr("notif_debug.template.image_body"), "https://via.placeholder.com/300", "active", "", "", false),
            (L10n.tr("notif_debug.template.urgent"), L10n.tr("notif_debug.template.urgent_title"), L10n.tr("notif_debug.template.urgent_body"), "", "timeSensitive", "alarm", "", false),
            ("Markdown", "Markdown", "# Hello\n- Item 1\n- Item 2", "", "active", "", "", true),
            (L10n.tr("notif_debug.template.link"), L10n.tr("notif_debug.template.link_title"), L10n.tr("notif_debug.template.link_body"), "", "active", "", "https://example.com", false),
            (L10n.tr("notif_debug.template.encrypted"), L10n.tr("notif_debug.template.encrypted_title"), "encrypted content", "", "active", "", "", false)
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
            responseView.text = L10n.tr("notif_debug.error_no_key")
            responseView.textColor = ThemeTokens.Color.error
            return
        }

        let title = titleInput.text ?? ""
        let body = bodyInput.text ?? ""
        guard !title.isEmpty else {
            responseView.text = L10n.tr("notif_debug.error_no_title")
            responseView.textColor = ThemeTokens.Color.error
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

        responseView.text = L10n.tr("notif_debug.sending")
        responseView.textColor = ThemeTokens.Color.textSecondary

        let params = NotificationParams(
            server: server, key: key, title: title, body: body,
            level: level, sound: sound, badge: badge, icon: icon,
            image: image, url: url, group: group, notifId: notifId
        )

        if isPost {
            sendPOST(params: params)
        } else {
            sendGET(params: params)
        }
    }

    private func sendGET(params: NotificationParams) {
        let encodedTitle = params.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? params.title
        let encodedBody = params.body.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? params.body
        var path = "\(params.server)/\(params.key)/\(encodedTitle)/\(encodedBody)"

        var items: [URLQueryItem] = []
        if !params.level.isEmpty && params.level != "active" { items.append(URLQueryItem(name: "level", value: params.level)) }
        if !params.sound.isEmpty { items.append(URLQueryItem(name: "sound", value: params.sound)) }
        if !params.badge.isEmpty, let b = Int(params.badge) { items.append(URLQueryItem(name: "badge", value: "\(b)")) }
        if !params.icon.isEmpty { items.append(URLQueryItem(name: "icon", value: params.icon)) }
        if !params.image.isEmpty { items.append(URLQueryItem(name: "img", value: params.image)) }
        if !params.url.isEmpty { items.append(URLQueryItem(name: "url", value: params.url)) }
        if !params.group.isEmpty { items.append(URLQueryItem(name: "group", value: params.group)) }
        if autocopySwitch.isOn { items.append(URLQueryItem(name: "copyable", value: "1")) }
        if archiveSwitch.isOn { items.append(URLQueryItem(name: "isArchive", value: "1")) }
        if !params.notifId.isEmpty { items.append(URLQueryItem(name: "id", value: params.notifId)) }

        if !items.isEmpty {
            var comps = URLComponents(string: path)
            comps?.queryItems = items
            path = comps?.string ?? path
        }

        guard let requestURL = URL(string: path) else {
            responseView.text = L10n.tr("notif_debug.error_url_failed")
            responseView.textColor = ThemeTokens.Color.error
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

    private func sendPOST(params: NotificationParams) {
        guard let requestURL = URL(string: "\(params.server)/\(params.key)") else {
            responseView.text = L10n.tr("notif_debug.error_url_failed")
            responseView.textColor = ThemeTokens.Color.error
            return
        }

        var bodyDict: [String: Any] = [
            "title": params.title,
            "body": params.body
        ]
        if !params.level.isEmpty { bodyDict["level"] = params.level }
        if !params.sound.isEmpty { bodyDict["sound"] = params.sound }
        if !params.badge.isEmpty, let b = Int(params.badge) { bodyDict["badge"] = b }
        if !params.icon.isEmpty { bodyDict["icon"] = params.icon }
        if !params.image.isEmpty { bodyDict["img"] = params.image }
        if !params.url.isEmpty { bodyDict["url"] = params.url }
        if !params.group.isEmpty { bodyDict["group"] = params.group }
        if autocopySwitch.isOn { bodyDict["copyable"] = "1" }
        if archiveSwitch.isOn { bodyDict["isArchive"] = "1" }
        if !params.notifId.isEmpty { bodyDict["id"] = params.notifId }
        if callSwitch.isOn { bodyDict["call"] = "1" }
        if markdownSwitch.isOn { bodyDict["ismarkdown"] = "1" }
        if params.level == "critical" { bodyDict["volume"] = Int(volumeSlider.value) }

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
            responseView.text = L10n.tr("notif_debug.error_request_failed_format", elapsed, error.localizedDescription)
            responseView.textColor = ThemeTokens.Color.error
            return
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? L10n.tr("notif_debug.empty_response")

        if (200...299).contains(statusCode) {
            responseView.text = L10n.tr("notif_debug.success_format", elapsed, "\(statusCode)", bodyStr)
            responseView.textColor = ThemeTokens.Color.success
        } else {
            responseView.text = L10n.tr("notif_debug.error_request_failed_format", elapsed, "HTTP \(statusCode)\n\n\(bodyStr)")
            responseView.textColor = ThemeTokens.Color.error
        }
    }
}

extension NotificationDebugViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { sounds.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { sounds[row] }
}
