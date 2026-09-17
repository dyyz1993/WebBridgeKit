import CryptoKit
import SwiftUI
import UIKit
import WebBridgeKit

/// Displays the verified Web App Manifest icon when available. Successfully
/// loaded icons are retained in Application Support so the installed app list
/// keeps its identity in airplane mode. Missing or invalid icons degrade to a
/// deterministic monogram instead of a misleading generic product glyph.
struct PWAAppIconView: View {
    let iconURL: URL?
    let cacheKey: String
    let fallbackInitial: String
    let tint: UIColor

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(tint).opacity(0.12)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Text(fallbackInitial)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(tint))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.CornerRadius.md))
        .task(id: cacheKey) {
            image = nil
            guard let iconURL else { return }
            guard let data = await PWAAppIconLoader.shared.data(for: iconURL, cacheKey: cacheKey),
                  let decoded = UIImage(data: data) else { return }
            image = decoded
        }
        .accessibilityHidden(true)
    }
}

actor PWAAppIconLoader {
    static let shared = PWAAppIconLoader()

    private let fileManager: FileManager
    private let root: URL
    private let maximumBytes = 2 * 1_024 * 1_024

    init(fileManager: FileManager = .default, root: URL? = nil) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.root = root ?? applicationSupport.appendingPathComponent("WebBridgeKit/AppIcons", isDirectory: true)
    }

    func data(for url: URL, cacheKey: String) async -> Data? {
        let destination = root.appendingPathComponent(Self.stableID("\(cacheKey)|\(url.absoluteString)"))
        if let cached = try? Data(contentsOf: destination),
           cached.count <= maximumBytes,
           UIImage(data: cached) != nil {
            return cached
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count <= maximumBytes,
              UIImage(data: data) != nil else { return nil }

        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableRoot = root
            try? mutableRoot.setResourceValues(values)
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
        } catch {
            // The icon remains usable for this presentation even if the
            // best-effort durable cache cannot be written.
        }
        return data
    }

    private static func stableID(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
