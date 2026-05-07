//
//  GlobPattern.swift
//  WebBridgeKit
//
//  Created by Claude on 2025-01-23.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import Foundation

/// Glob 模式匹配工具
/// 支持通配符: *, **, ?, [abc], [!abc]
public struct GlobPattern {

    // MARK: - Public Methods

    /// 判断文本是否匹配 Glob 模式
    /// - Parameters:
    ///   - pattern: Glob 模式字符串（如 `https://example.com/*.js`）
    ///   - text: 待匹配的文本
    /// - Returns: 是否匹配
    public static func matches(_ pattern: String, against text: String) -> Bool {
        let regexPattern = convertGlobToRegex(pattern)
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// 批量过滤匹配的文本
    /// - Parameters:
    ///   - pattern: Glob 模式字符串
    ///   - texts: 待过滤的文本数组
    /// - Returns: 匹配的文本数组
    public static func filter(_ pattern: String, texts: [String]) -> [String] {
        return texts.filter { matches(pattern, against: $0) }
    }

    // MARK: - Private Methods

    /// 将 Glob 模式转换为正则表达式
    /// - Parameter glob: Glob 模式字符串
    /// - Returns: 正则表达式字符串
    private static func convertGlobToRegex(_ glob: String) -> String {
        var regex = glob

        // 1. 先用占位符保护通配符（避免被转义）
        regex = regex.replacingOccurrences(of: "**", with: "\u{FFFF}\u{FFFE}DOUBLE_WILDCARD\u{FFFE}\u{FFFF}")
        regex = regex.replacingOccurrences(of: "*", with: "\u{FFFF}\u{FFFE}SINGLE_WILDCARD\u{FFFE}\u{FFFF}")
        regex = regex.replacingOccurrences(of: "?", with: "\u{FFFF}\u{FFFE}QUESTION_MARK\u{FFFE}\u{FFFF}")

        // 1.5 提取字符集，用安全占位符替换
        var extractedClasses: [String] = []
        regex = extractCharacterClasses(from: regex, into: &extractedClasses)

        // 2. 转义正则表达式特殊字符
        let specialChars = CharacterSet(charactersIn: "\\^$|()+[].-")
        regex = regex.unicodeScalars.map { scalar in
            if specialChars.contains(scalar) {
                return "\\\(String(scalar))"
            }
            return String(scalar)
        }.joined()

        // 3. 恢复字符集为正则表达式字符类
        for (index, charClass) in extractedClasses.enumerated() {
            let placeholder = "\u{0001}CC\(index)\u{0002}"
            let regexClass: String
            if charClass.count > 2 && charClass[charClass.index(after: charClass.startIndex)] == "!" {
                regexClass = "[^" + String(charClass.dropFirst(2).dropLast()) + "]"
            } else {
                regexClass = charClass
            }
            regex = regex.replacingOccurrences(of: placeholder, with: regexClass)
        }

        // 4. 恢复并转换通配符为正则表达式
        regex = regex.replacingOccurrences(of: "\u{FFFF}\u{FFFE}DOUBLE_WILDCARD\u{FFFE}\u{FFFF}/", with: "(.*/)?")
        regex = regex.replacingOccurrences(of: "\u{FFFF}\u{FFFE}DOUBLE_WILDCARD\u{FFFE}\u{FFFF}", with: ".*")
        regex = regex.replacingOccurrences(of: "\u{FFFF}\u{FFFE}SINGLE_WILDCARD\u{FFFE}\u{FFFF}", with: "[^/]*")
        regex = regex.replacingOccurrences(of: "\u{FFFF}\u{FFFE}QUESTION_MARK\u{FFFE}\u{FFFF}", with: ".")

        // 5. 处理结尾的 /\.\* - 使其匹配带或不带尾部斜杠的 URL
        // 例如: https://github\.com/.* 应该变为 https://github\.com(/.*)?
        // 这样可以同时匹配 https://github.com 和 https://github.com/user
        // 注意: /.* 在字符串中是斜杠后跟点星号，共3个字符
        while regex.hasSuffix("/.*") {
            // 移除最后的 /.* 并添加 (/.*)?
            regex = String(regex.dropLast(3)) + "(/.*)?"
        }

        // 确保完全匹配
        return "^\(regex)$"
    }

    /// 提取字符集 [abc] 和 [!abc] 为占位符
    private static func extractCharacterClasses(from string: String, into classes: inout [String]) -> String {
        var result = ""
        var i = string.indices.makeIterator()

        while let index = i.next() {
            let char = string[index]

            if char == "[" {
                if let endIndex = string[index...].firstIndex(of: "]") {
                    let charClass = String(string[index...endIndex])
                    let placeholder = "\u{0001}CC\(classes.count)\u{0002}"
                    classes.append(charClass)
                    result.append(placeholder)
                    let offset = string.distance(from: index, to: endIndex)
                    for _ in 0..<offset {
                        _ = i.next()
                    }
                } else {
                    result.append(char)
                }
            } else {
                result.append(char)
            }
        }

        return result
    }
}

// MARK: - Tests

#if DEBUG

extension GlobPattern {

    /// 运行内置测试用例（开发调试用）
    public static func runTests() -> Bool {
        let tests: [(pattern: String, text: String, expected: Bool)] = [
            // 基础通配符测试
            ("*.js", "app.js", true),
            ("*.js", "app.css", false),
            ("file?.txt", "file1.txt", true),
            ("file?.txt", "file10.txt", false),

            // 路径通配符测试
            ("https://example.com/*.js", "https://example.com/app.js", true),
            ("https://example.com/*.js", "https://example.com/path/app.js", false),
            ("https://example.com/**", "https://example.com/path/to/file.js", true),
            ("https://example.com/images/*.png", "https://example.com/images/logo.png", true),
            ("https://example.com/images/*.png", "https://example.com/images/sub/logo.png", false),

            // 字符集测试
            ("file[123].txt", "file1.txt", true),
            ("file[123].txt", "file2.txt", true),
            ("file[123].txt", "file4.txt", false),
            ("file[!123].txt", "file1.txt", false),
            ("file[!123].txt", "file4.txt", true),

            // 复杂组合测试
            ("https://*.example.com/**", "https://api.example.com/v1/users", true),
            ("https://api.*.com/**", "https://api.example.com/v1/users", true),
            ("**/*.min.js", "path/to/jquery.min.js", true),

            // GitHub 相关测试（修复 ** 通配符 bug）
            ("https://github.com/**", "https://github.com", true),
            ("https://github.com/**", "https://github.com/user/repo", true),
            ("https://github.com/**", "https://github.com/user/repo/issues", true),

            // 边界情况
            ("", "", true),
            ("exact", "exact", true),
            ("exact", "notexact", false)
        ]

        var passed = 0
        var failed = 0

        for test in tests {
            let result = matches(test.pattern, against: test.text)
            if result == test.expected {
                passed += 1
            } else {
                failed += 1
                print("❌ Test failed: pattern='\(test.pattern)', text='\(test.text)', expected=\(test.expected), got=\(result)")
            }
        }

        print("🧪 GlobPattern Tests: \(passed) passed, \(failed) failed")

        return failed == 0
    }
}

#endif
