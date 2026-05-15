import Foundation
import WebKit

public class MarkdownRenderer {
    
    public static func renderHTML(title: String, markdown: String, theme: String = "light") -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <style>
                :root {
                    --bg-primary: #F2F2F6;
                    --bg-secondary: #FFFFFF;
                    --text-primary: #000000;
                    --text-secondary: #8E8E93;
                    --text-tertiary: #C7C7CC;
                    --border-color: #C6C6C8;
                    --code-bg: #F5F5F5;
                    --code-border: #E0E0E0;
                    --link-color: #007AFF;
                    --link-visited: #5856D6;
                }
                
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg-primary: #000000;
                        --bg-secondary: #26262B;
                        --text-primary: #EBEDF0;
                        --text-secondary: #8E8E93;
                        --text-tertiary: #48484A;
                        --border-color: #38383A;
                        --code-bg: #1E1E1E;
                        --code-border: #2C2C2C;
                        --link-color: #0A84FF;
                        --link-visited: #5E5CE6;
                    }
                }
                
                * {
                    box-sizing: border-box;
                    margin: 0;
                    padding: 0;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: var(--text-primary);
                    background-color: var(--bg-primary);
                    padding: 16px;
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    line-height: 1.3;
                    margin-top: 24px;
                    margin-bottom: 12px;
                    color: var(--text-primary);
                }
                
                h1 { font-size: 28px; }
                h2 { font-size: 24px; }
                h3 { font-size: 20px; }
                h4 { font-size: 18px; }
                h5 { font-size: 16px; }
                h6 { font-size: 14px; }
                
                h1:first-child, h2:first-child, h3:first-child {
                    margin-top: 0;
                }
                
                p {
                    margin-bottom: 16px;
                    color: var(--text-secondary);
                }
                
                a {
                    color: var(--link-color);
                    text-decoration: none;
                    word-break: break-word;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                a:active {
                    color: var(--link-visited);
                }
                
                code {
                    font-family: "SF Mono", "Menlo", "Monaco", "Courier New", monospace;
                    font-size: 14px;
                    background-color: var(--code-bg);
                    border: 1px solid var(--code-border);
                    border-radius: 4px;
                    padding: 2px 6px;
                    color: var(--text-primary);
                }
                
                pre {
                    background-color: var(--code-bg);
                    border: 1px solid var(--code-border);
                    border-radius: 6px;
                    padding: 12px;
                    overflow-x: auto;
                    margin-bottom: 16px;
                }
                
                pre code {
                    background: none;
                    border: none;
                    padding: 0;
                    font-size: 13px;
                    line-height: 1.5;
                }
                
                blockquote {
                    border-left: 4px solid var(--link-color);
                    background-color: var(--bg-secondary);
                    padding: 12px 16px;
                    margin-bottom: 16px;
                    border-radius: 0 4px 4px 0;
                }
                
                blockquote p {
                    margin-bottom: 0;
                    color: var(--text-secondary);
                }
                
                ul, ol {
                    padding-left: 24px;
                    margin-bottom: 16px;
                    color: var(--text-secondary);
                }
                
                li {
                    margin-bottom: 6px;
                }
                
                ul ul, ol ol, ul ol, ol ul {
                    margin-top: 6px;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid var(--border-color);
                    margin: 24px 0;
                }
                
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-bottom: 16px;
                    font-size: 14px;
                }
                
                th, td {
                    border: 1px solid var(--border-color);
                    padding: 8px 12px;
                    text-align: left;
                }
                
                th {
                    background-color: var(--bg-secondary);
                    font-weight: 600;
                    color: var(--text-primary);
                }
                
                td {
                    color: var(--text-secondary);
                }
                
                tr:nth-child(even) {
                    background-color: var(--bg-secondary);
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 6px;
                    margin-bottom: 16px;
                }
                
                strong {
                    font-weight: 600;
                }
                
                em {
                    font-style: italic;
                }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <script>
                const markdown = \(escapeJS(markdown));
                document.getElementById('content').innerHTML = marked.parse(markdown);
                
                document.addEventListener('click', function(e) {
                    const link = e.target.closest('a');
                    if (link && link.getAttribute('href')) {
                        e.preventDefault();
                        const url = link.getAttribute('href');
                        window.webkit.messageHandlers.linkHandler.postMessage({url: url});
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    private static func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private static func escapeJS(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "`\(escaped)`"
    }
}
