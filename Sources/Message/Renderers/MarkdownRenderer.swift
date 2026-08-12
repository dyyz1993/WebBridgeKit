import Foundation

/// Renders notification Markdown into a self-contained HTML document.
///
/// The renderer intentionally does not load a CDN parser. Push content must remain
/// readable when the device is offline, and raw HTML from a message is always escaped.
public enum MarkdownRenderer {

    public static func renderHTML(title: String, markdown: String, theme: String = "light") -> String {
        var document = OfflineMarkdownDocument(markdown: markdown)
        let body = document.render()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https:; style-src 'unsafe-inline'">
            <title>\(escapeHTML(title))</title>
            <style>
                :root {
                    color-scheme: light dark;
                    --surface: #FFFFFF;
                    --surface-muted: #F4F5F8;
                    --surface-quote: #EEF3FF;
                    --text: #1D2333;
                    --text-secondary: #5F6B85;
                    --border: #E3E7EF;
                    --accent: #4E73FF;
                    --code: #192033;
                    --code-text: #EAF0FF;
                }

                @media (prefers-color-scheme: dark) {
                    :root {
                        --surface: #1D2230;
                        --surface-muted: #262D3D;
                        --surface-quote: #222D4A;
                        --text: #F3F6FF;
                        --text-secondary: #B7C1D8;
                        --border: #39435A;
                        --accent: #91A7FF;
                        --code: #111722;
                        --code-text: #EAF0FF;
                    }
                }

                * { box-sizing: border-box; }

                html, body {
                    margin: 0;
                    padding: 0;
                    background: transparent;
                }

                body {
                    color: var(--text);
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", "Helvetica Neue", sans-serif;
                    font-size: 17px;
                    line-height: 1.7;
                    -webkit-font-smoothing: antialiased;
                    text-rendering: optimizeLegibility;
                    overflow-wrap: anywhere;
                }

                article { padding: 2px 0 8px; }
                h1, h2, h3, h4, h5, h6 {
                    color: var(--text);
                    font-weight: 700;
                    letter-spacing: -0.02em;
                    line-height: 1.28;
                    margin: 28px 0 12px;
                }
                h1 { font-size: 28px; }
                h2 { font-size: 23px; }
                h3 { font-size: 20px; }
                h4, h5, h6 { font-size: 18px; }
                h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
                p { color: var(--text-secondary); margin: 0 0 16px; }
                strong { color: var(--text); font-weight: 700; }
                a { color: var(--accent); font-weight: 600; text-decoration: none; }
                hr { border: 0; border-top: 1px solid var(--border); margin: 28px 0; }
                ul, ol { color: var(--text-secondary); margin: 0 0 18px; padding-left: 24px; }
                li { margin: 7px 0; padding-left: 3px; }
                .task-list { list-style: none; padding-left: 0; }
                .task-list-item { display: flex; gap: 9px; align-items: flex-start; }
                .task-checkbox { appearance: none; width: 18px; height: 18px; flex: 0 0 18px; margin: 5px 0 0; border: 1.5px solid var(--border); border-radius: 5px; background: var(--surface); }
                .task-checkbox:checked { border-color: var(--accent); background: var(--accent); }
                .task-checkbox:checked::after { content: "✓"; display: block; color: white; font-size: 13px; font-weight: 800; line-height: 16px; text-align: center; }
                blockquote { margin: 0 0 18px; padding: 13px 15px; border-left: 3px solid var(--accent); border-radius: 0 12px 12px 0; background: var(--surface-quote); }
                blockquote p { color: var(--text); margin: 0; }
                code { background: var(--surface-muted); border: 1px solid var(--border); border-radius: 6px; color: var(--text); font-family: "SF Mono", Menlo, Monaco, monospace; font-size: 0.84em; padding: 2px 5px; }
                pre { background: var(--code); border-radius: 14px; color: var(--code-text); margin: 0 0 18px; overflow-x: auto; padding: 15px; -webkit-overflow-scrolling: touch; }
                pre code { background: transparent; border: 0; color: inherit; display: block; font-size: 13px; line-height: 1.6; padding: 0; white-space: pre; }
                .table-wrap { border: 1px solid var(--border); border-radius: 12px; margin: 0 0 18px; overflow: hidden; overflow-x: auto; }
                table { border-collapse: collapse; min-width: 100%; width: max-content; }
                th, td { border-bottom: 1px solid var(--border); padding: 10px 12px; text-align: left; white-space: nowrap; }
                th { background: var(--surface-muted); color: var(--text); font-size: 14px; font-weight: 700; }
                td { color: var(--text-secondary); font-size: 14px; }
                tr:last-child td { border-bottom: 0; }
                img { background: var(--surface-muted); border-radius: 12px; display: block; height: auto; margin: 0 0 18px; max-width: 100%; }
            </style>
        </head>
        <body>
            <article>\(body)</article>
        </body>
        </html>
        """
    }
}

private struct OfflineMarkdownDocument {
    private let lines: [String]
    private var index = 0

    init(markdown: String) {
        lines = markdown.components(separatedBy: .newlines)
    }

    mutating func render() -> String {
        var blocks: [String] = []

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                index += 1
            } else if isFence(line) {
                blocks.append(renderCodeBlock())
            } else if let heading = heading(line) {
                blocks.append("<h\(heading.level)>\(inlineHTML(heading.text))</h\(heading.level)>")
                index += 1
            } else if isHorizontalRule(line) {
                blocks.append("<hr>")
                index += 1
            } else if isQuote(line) {
                blocks.append(renderQuote())
            } else if isTableStart(at: index) {
                blocks.append(renderTable())
            } else if unorderedItem(line) != nil || orderedItem(line) != nil {
                blocks.append(renderList())
            } else {
                blocks.append(renderParagraph())
            }
        }

        return blocks.joined(separator: "\n")
    }

    private mutating func renderCodeBlock() -> String {
        let opening = lines[index].trimmingCharacters(in: .whitespaces)
        let fence = String(opening.prefix(3))
        let language = String(opening.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        index += 1

        var code: [String] = []
        while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
            code.append(lines[index])
            index += 1
        }
        if index < lines.count { index += 1 }

        let languageClass = safeCSSIdentifier(language)
        let classAttribute = languageClass.isEmpty ? "" : " class=\"language-\(languageClass)\""
        return "<pre><code\(classAttribute)>\(escapeHTML(code.joined(separator: "\n")))</code></pre>"
    }

    private mutating func renderQuote() -> String {
        var quoteLines: [String] = []
        while index < lines.count, isQuote(lines[index]) {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            quoteLines.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            index += 1
        }

        var quote = OfflineMarkdownDocument(markdown: quoteLines.joined(separator: "\n"))
        return "<blockquote>\(quote.render())</blockquote>"
    }

    private mutating func renderTable() -> String {
        let headers = tableCells(lines[index])
        let alignments = tableCells(lines[index + 1]).map(tableAlignment)
        index += 2

        var rows: [[String]] = []
        while index < lines.count, lines[index].contains("|"), !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            rows.append(tableCells(lines[index]))
            index += 1
        }

        func cell(_ value: String, alignment: String, tag: String) -> String {
            let alignmentAttribute = alignment.isEmpty ? "" : " style=\"text-align:\(alignment)\""
            return "<\(tag)\(alignmentAttribute)>\(inlineHTML(value))</\(tag)>"
        }

        let headerHTML = headers.enumerated().map { offset, value in
            cell(value, alignment: offset < alignments.count ? alignments[offset] : "", tag: "th")
        }.joined()
        let rowHTML = rows.map { row in
            let cells = row.enumerated().map { offset, value in
                cell(value, alignment: offset < alignments.count ? alignments[offset] : "", tag: "td")
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined()

        return "<div class=\"table-wrap\"><table><thead><tr>\(headerHTML)</tr></thead><tbody>\(rowHTML)</tbody></table></div>"
    }

    private mutating func renderList() -> String {
        let ordered = orderedItem(lines[index]) != nil
        var items: [String] = []
        var containsTasks = false

        while index < lines.count {
            let item = ordered ? orderedItem(lines[index]) : unorderedItem(lines[index])
            guard let raw = item else { break }
            index += 1

            if let task = taskItem(raw) {
                containsTasks = true
                let checked = task.checked ? " checked" : ""
                items.append("<li class=\"task-list-item\"><input class=\"task-checkbox\" type=\"checkbox\" disabled\(checked)><span>\(inlineHTML(task.text))</span></li>")
            } else {
                items.append("<li>\(inlineHTML(raw))</li>")
            }
        }

        let tag = ordered ? "ol" : "ul"
        let classAttribute = containsTasks ? " class=\"task-list\"" : ""
        return "<\(tag)\(classAttribute)>\(items.joined())</\(tag)>"
    }

    private mutating func renderParagraph() -> String {
        var paragraph: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            if !paragraph.isEmpty && startsNewBlock(at: index) { break }
            paragraph.append(line.trimmingCharacters(in: .whitespaces))
            index += 1
        }
        return "<p>\(paragraph.map(inlineHTML).joined(separator: "<br>"))</p>"
    }

    private func startsNewBlock(at position: Int) -> Bool {
        let line = lines[position]
        return isFence(line)
            || heading(line) != nil
            || isHorizontalRule(line)
            || isQuote(line)
            || isTableStart(at: position)
            || unorderedItem(line) != nil
            || orderedItem(line) != nil
    }

    private func isTableStart(at position: Int) -> Bool {
        guard position + 1 < lines.count, lines[position].contains("|") else { return false }
        let separator = tableCells(lines[position + 1])
        return !separator.isEmpty && separator.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            return trimmed.range(of: "^:?-{3,}:?$", options: .regularExpression) != nil
        }
    }

    private func heading(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let marks = trimmed.prefix { $0 == "#" }
        guard !marks.isEmpty, marks.count <= 6 else { return nil }
        let remainder = String(trimmed.dropFirst(marks.count))
        guard remainder.first == " " else { return nil }
        return (marks.count, remainder.trimmingCharacters(in: .whitespaces))
    }

    private func isFence(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        return Set(trimmed) == Set("-") || Set(trimmed) == Set("*") || Set(trimmed) == Set("_")
    }

    private func isQuote(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private func unorderedItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            return String(trimmed.dropFirst(marker.count))
        }
        return nil
    }

    private func orderedItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let range = trimmed.range(of: "^[0-9]+\\.\\s+", options: .regularExpression) else { return nil }
        return String(trimmed[range.upperBound...])
    }

    private func taskItem(_ value: String) -> (checked: Bool, text: String)? {
        let lowercased = value.lowercased()
        if lowercased.hasPrefix("[x] ") { return (true, String(value.dropFirst(4))) }
        if lowercased.hasPrefix("[ ] ") { return (false, String(value.dropFirst(4))) }
        return nil
    }

    private func tableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
    }

    private func tableAlignment(_ cell: String) -> String {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(":"), trimmed.hasSuffix(":") { return "center" }
        if trimmed.hasSuffix(":") { return "right" }
        if trimmed.hasPrefix(":") { return "left" }
        return ""
    }
}

private func inlineHTML(_ source: String) -> String {
    var output = escapeHTML(source)

    output = replaceMatches(in: output, pattern: "!\\[([^\\]]*)\\]\\(([^\\s)]+)(?:\\s+\\\"[^\\\"]*\\\")?\\)") { groups in
        guard groups.count == 2, let url = safeURL(groups[1], image: true) else { return groups.first ?? "" }
        return "<img src=\"\(url)\" alt=\"\(groups[0])\">"
    }
    output = replaceMatches(in: output, pattern: "\\[([^\\]]+)\\]\\(([^\\s)]+)(?:\\s+\\\"[^\\\"]*\\\")?\\)") { groups in
        guard groups.count == 2, let url = safeURL(groups[1], image: false) else { return groups.first ?? "" }
        return "<a href=\"\(url)\">\(groups[0])</a>"
    }
    output = replaceMatches(in: output, pattern: "`([^`]+)`") { groups in
        "<code>\(groups.first ?? "")</code>"
    }
    output = replaceMatches(in: output, pattern: "\\*\\*([^*]+)\\*\\*") { groups in
        "<strong>\(groups.first ?? "")</strong>"
    }
    output = replaceMatches(in: output, pattern: "~~([^~]+)~~") { groups in
        "<del>\(groups.first ?? "")</del>"
    }
    output = replaceMatches(in: output, pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)") { groups in
        "<em>\(groups.first ?? "")</em>"
    }

    return output
}

private func replaceMatches(in source: String, pattern: String, transform: ([String]) -> String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
    let range = NSRange(source.startIndex..., in: source)
    let matches = regex.matches(in: source, range: range)
    var output = source

    for match in matches.reversed() {
        let groups = (1 ..< match.numberOfRanges).compactMap { index -> String? in
            guard let range = Range(match.range(at: index), in: source) else { return nil }
            return String(source[range])
        }
        guard let replacementRange = Range(match.range, in: output) else { continue }
        output.replaceSubrange(replacementRange, with: transform(groups))
    }

    return output
}

private func safeURL(_ escapedURL: String, image: Bool) -> String? {
    let rawURL = escapedURL.replacingOccurrences(of: "&amp;", with: "&")
    guard let components = URLComponents(string: rawURL), let scheme = components.scheme?.lowercased() else { return nil }

    let allowedSchemes: Set<String> = image ? ["https"] : ["https", "http", "mailto"]
    guard allowedSchemes.contains(scheme) else { return nil }
    return escapeHTML(rawURL)
}

private func safeCSSIdentifier(_ value: String) -> String {
    value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
}

private func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
