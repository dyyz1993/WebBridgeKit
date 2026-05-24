// sync-design-tokens.swift — Entry point for token sync
// Run via: bash tools/sync-tokens.sh

import Foundation

@main
struct TokenSyncMain {
    static func main() {
        let projectRoot = FileManager.default.currentDirectoryPath
        let tokensPath = projectRoot + "/docs/design-tokens.json"
        let swiftOutputPath = projectRoot + "/Sources/Theme/ThemeTokens.swift"
        let cssOutputPath = projectRoot + "/docs/prototype/design-tokens.css"
        let kotlinOutputPath = projectRoot + "/tools/output/android/ThemeTokens.kt"
        let androidResDir = projectRoot + "/tools/output/android/res"

        guard let tokens = loadTokens(from: tokensPath) else {
            print("Failed to load tokens. Exiting.")
            return
        }

        print("Loaded design-tokens.json v\(tokens.version)")

        let swiftCode = generateSwift(tokens)
        let swiftDir = (swiftOutputPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: swiftDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: swiftOutputPath, contents: swiftCode.data(using: .utf8))
        print("Written: \(swiftOutputPath)")

        let cssCode = generateCSS(tokens)
        let cssDir = (cssOutputPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: cssDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: cssOutputPath, contents: cssCode.data(using: .utf8))
        print("Written: \(cssOutputPath)")

        let kotlinCode = generateKotlin(tokens)
        let kotlinDir = (kotlinOutputPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: kotlinDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: kotlinOutputPath, contents: kotlinCode.data(using: .utf8))
        print("Written: \(kotlinOutputPath)")

        let xmlFiles = generateAndroidXML(tokens)
        for (relativePath, content) in xmlFiles.sorted(by: { $0.key < $1.key }) {
            let fullPath = androidResDir + "/" + relativePath
            let dir = (fullPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: fullPath, contents: content.data(using: .utf8))
            print("Written: \(fullPath)")
        }

        printValidationReport(tokens)

        print("===========================================================")
        print("  Sync complete.")
        print("===========================================================")
    }
}
