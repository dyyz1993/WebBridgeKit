import Foundation

/// Parses push notification payloads into MutableMessageContent
/// Compatible with Bark server API format
public struct PushPayloadParser: Sendable {
    
    public init() {}
    
    /// Parse from APNs userInfo dictionary
    public func parse(userInfo: [AnyHashable: Any]) -> MutableMessageContent {
        var content = MutableMessageContent(userInfo: userInfo)
        
        if content.title.isEmpty, let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                if content.title.isEmpty { content.title = alert["title"] as? String ?? "" }
                if content.body.isEmpty { content.body = alert["body"] as? String ?? "" }
            }
        }
        
        if content.targetURL == nil, let url = userInfo["url"] as? String {
            content.targetURL = url
        }
        
        return content
    }
    
    /// Parse from Bark URL format: /:key/:title/:body
    public func parseBarkURL(path: String, query: [String: String]) -> MutableMessageContent {
        let components = path.split(separator: "/").map(String.init)
        
        var content = MutableMessageContent()
        
        if components.count >= 2 {
            if components.count == 2 {
                content.body = components[1]
            } else if components.count == 3 {
                content.title = components[1]
                content.body = components[2]
            } else if components.count >= 4 {
                content.title = components[1]
                content.subtitle = components[2]
                content.body = components[3]
            }
        }
        
        if let url = query["url"] { content.targetURL = url }
        if let group = query["group"] { content.group = group }
        if let icon = query["icon"] { content.iconURL = icon }
        if let sound = query["sound"] { content.sound = sound }
        if let image = query["image"] { content.imageURL = image }
        if let copy = query["copy"] { content.copyText = copy }
        
        if query["call"] == "1" { content.isCall = true }
        if query["isArchive"] == "1" { content.isArchive = true }
        if query["automaticallyCopy"] == "1" || query["autoCopy"] == "1" { content.isAutoCopy = true }
        if query["markdown"] == "1" { content.bodyType = .markdown }
        
        if let level = query["level"] {
            content.level = MessageInterruptionLevel(rawValue: level) ?? .active
        }
        if let badge = query["badge"], let badgeInt = Int(badge) {
            content.badge = badgeInt
        }
        if let volume = query["volume"], let volumeDouble = Double(volume) {
            content.volume = min(max(volumeDouble, 0), 10)
        }
        
        return content
    }
}
