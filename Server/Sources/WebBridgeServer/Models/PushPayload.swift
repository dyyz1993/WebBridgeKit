import Foundation
import Hummingbird

struct PushPayload: Codable, Sendable {
    let schema: String?
    let type: String?
    let title: String
    let body: String
    let subtitle: String?
    let category: String?
    let markdown: String?
    let sound: String?
    let badge: Int?
    let icon: String?
    let image: String?
    let group: String?
    let threadID: String?
    let url: String?
    let copy: String?
    let isArchive: Bool?
    let level: String?
    let volume: Double?
    let isCall: Bool?
    let autoCopy: Bool?
    let appID: String?
    let route: String?
    let mode: String?
    let display: String?
    let verificationCode: String?
    let expiresAt: String?
    let ttl: TimeInterval?
    let replacementID: String?
    let isDeleted: Bool?
    let actionState: String?
    let requestID: String?
    let contentType: String?
    let qrPayload: String?
    let statePath: String?
    let revision: Int?
    let params: [String: String]?
    let presentation: String?
    let approval: ApprovalClientPayload?
    /// Server-assigned push id, embedded in the APNs payload as `messageId`
    /// so the tap path, NSE plist replay, and server history replay all
    /// reconstruct the message with the same id and dedupe against each other.
    var messageID: String?
    /// Opaque end-to-end encrypted payload passthrough. The server never
    /// sees the plaintext; the device NSE decrypts with the shared key.
    let ciphertext: String?

    enum CodingKeys: String, CodingKey {
        case schema, type, title, body, subtitle, category, markdown, sound, badge, icon, image
        case group, url, copy, level, volume, route, mode, display, verificationCode, expiresAt, ttl
        case actionState, contentType, qrPayload, statePath, revision, params, presentation, approval
        case messageID = "messageId"
        case ciphertext
        case threadID = "threadId"
        case isCall = "call"
        case autoCopy
        case appID = "appId"
        case replacementID = "id"
        case isDeleted = "delete"
        case requestID = "requestId"
        case isArchive = "isArchive"
    }

    init(
        schema: String? = nil,
        type: String? = nil,
        title: String,
        body: String,
        subtitle: String? = nil,
        category: String? = nil,
        markdown: String? = nil,
        sound: String? = nil,
        badge: Int? = nil,
        icon: String? = nil,
        image: String? = nil,
        group: String? = nil,
        threadID: String? = nil,
        url: String? = nil,
        copy: String? = nil,
        isArchive: Bool? = nil,
        level: String? = nil,
        volume: Double? = nil,
        isCall: Bool? = nil,
        autoCopy: Bool? = nil,
        appID: String? = nil,
        route: String? = nil,
        mode: String? = nil,
        display: String? = nil,
        verificationCode: String? = nil,
        expiresAt: String? = nil,
        ttl: TimeInterval? = nil,
        replacementID: String? = nil,
        isDeleted: Bool? = nil,
        actionState: String? = nil,
        requestID: String? = nil,
        contentType: String? = nil,
        qrPayload: String? = nil,
        statePath: String? = nil,
        revision: Int? = nil,
        params: [String: String]? = nil,
        presentation: String? = nil,
        approval: ApprovalClientPayload? = nil,
        messageID: String? = nil,
        ciphertext: String? = nil
    ) {
        self.schema = schema
        self.type = type
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.category = category
        self.markdown = markdown
        self.sound = sound
        self.badge = badge
        self.icon = icon
        self.image = image
        self.group = group
        self.threadID = threadID
        self.url = url
        self.copy = copy
        self.isArchive = isArchive
        self.level = level
        self.volume = volume
        self.isCall = isCall
        self.autoCopy = autoCopy
        self.appID = appID
        self.route = route
        self.mode = mode
        self.display = display
        self.verificationCode = verificationCode
        self.expiresAt = expiresAt
        self.ttl = ttl
        self.replacementID = replacementID
        self.isDeleted = isDeleted
        self.actionState = actionState
        self.requestID = requestID
        self.contentType = contentType
        self.qrPayload = qrPayload
        self.statePath = statePath
        self.revision = revision
        self.params = params
        self.presentation = presentation
        self.approval = approval
        self.messageID = messageID
        self.ciphertext = ciphertext
    }

    /// Assigns a push id if none exists yet. Reuses the approval identity
    /// when present so approval updates keep landing on the same message.
    mutating func ensureMessageID() {
        if messageID == nil {
            messageID = replacementID ?? requestID ?? UUID().uuidString
        }
    }

    /// Flat string form of the custom fields the client needs to rebuild the
    /// message outside the APNs pipeline (NSE plist replay, history fetch).
    /// Types are stringified because the payload mapper on the client parses
    /// numeric/boolean fields from strings as well.
    var customFields: [String: String] {
        var fields: [String: String] = [:]
        func put(_ key: String, _ value: String?) {
            if let value { fields[key] = value }
        }
        func putDouble(_ key: String, _ value: Double?) {
            if let value { fields[key] = String(value) }
        }
        func putInt(_ key: String, _ value: Int?) {
            if let value { fields[key] = String(value) }
        }
        func putBool(_ key: String, _ value: Bool?) {
            if let value { fields[key] = value ? "1" : "0" }
        }
        put("subtitle", subtitle)
        put("category", category)
        put("markdown", markdown)
        put("sound", sound)
        put("icon", icon)
        put("image", image)
        put("group", group)
        put("threadId", threadID)
        put("url", url)
        put("copy", copy)
        put("level", level)
        putDouble("volume", volume)
        putBool("isArchive", isArchive)
        putBool("call", isCall)
        putBool("autoCopy", autoCopy)
        put("appId", appID)
        put("route", route)
        put("mode", mode)
        put("display", display)
        put("verificationCode", verificationCode)
        put("expiresAt", expiresAt)
        putDouble("ttl", ttl)
        put("id", replacementID)
        putBool("delete", isDeleted)
        put("actionState", actionState)
        put("state", actionState)
        put("requestId", requestID)
        put("contentType", contentType)
        put("type", type)
        put("qrPayload", qrPayload)
        put("statePath", statePath)
        putInt("revision", revision)
        putInt("badge", badge)
        put("presentation", presentation)
        put("schema", schema)
        put("ciphertext", ciphertext)
        return fields
    }

    func updatingApprovalState(_ state: ApprovalState, revision: Int) -> PushPayload {
        PushPayload(
            schema: schema,
            type: type,
            title: title,
            body: body,
            subtitle: subtitle,
            category: category,
            markdown: markdown,
            sound: sound,
            badge: badge,
            icon: icon,
            image: image,
            group: group,
            threadID: threadID,
            url: url,
            copy: copy,
            isArchive: isArchive,
            level: level,
            volume: volume,
            isCall: isCall,
            autoCopy: autoCopy,
            appID: appID,
            route: route,
            mode: mode,
            display: display,
            verificationCode: verificationCode,
            expiresAt: expiresAt,
            ttl: ttl,
            replacementID: replacementID,
            isDeleted: isDeleted,
            actionState: state.rawValue,
            requestID: requestID,
            contentType: contentType,
            qrPayload: qrPayload,
            statePath: statePath,
            revision: revision,
            params: params,
            presentation: presentation,
            approval: approval,
            messageID: messageID,
            ciphertext: ciphertext
        )
    }
}

struct PushResponse: ResponseEncodable, Sendable {
    let code: Int
    let message: String
    let timestamp: Int
}
