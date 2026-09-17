import XCTest
@testable import WebBridgeKit

final class MarkdownRendererTests: XCTestCase {

    func testRendersCommonMessageMarkdownWithoutRemoteParser() {
        let markdown = """
        # 发布摘要

        > 发布前请确认回滚窗口。

        - [x] 数据库迁移
        - [ ] 灰度观察

        | 指标 | 当前值 |
        | --- | ---: |
        | 错误率 | 0.02% |

        `requestId` 已写入。

        ```bash
        wbk deploy --region cn
        ```

        [查看控制台](https://example.com/console)
        """

        let html = MarkdownRenderer.renderHTML(title: "发布完成", markdown: markdown)

        XCTAssertFalse(html.contains("cdn.jsdelivr.net"))
        XCTAssertFalse(html.contains("marked.min.js"))
        XCTAssertTrue(html.contains("<h1>发布摘要</h1>"))
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("task-list"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<code>requestId</code>"))
        XCTAssertTrue(html.contains("<pre><code class=\"language-bash\">"))
        XCTAssertTrue(html.contains("href=\"https://example.com/console\""))
    }

    func testEscapesRawHTMLAndUnsafeURLs() {
        let markdown = """
        <script>alert('unsafe')</script>
        [bad](javascript:alert(1))
        ![bad](data:text/html,unsafe)
        """

        let html = MarkdownRenderer.renderHTML(title: "安全测试", markdown: markdown)

        XCTAssertTrue(html.contains("&lt;script&gt;alert"))
        XCTAssertFalse(html.contains("href=\"javascript:"))
        XCTAssertFalse(html.contains("src=\"data:"))
    }

    func testRendersNestedGFMElementsAndKeepsEscapedTablePipes() {
        let markdown = """
        Release checklist
        =================

        3. **Deploy**
           - [x] Build `55`
           - [ ] Watch ==error rate==
             - Owner: _on-call_

        | Field | Value |
        | :--- | ---: |
        | Expression | `a\\|b` |

        <https://drel.app>
        <support@drel.app>
        """

        let html = MarkdownRenderer.renderHTML(title: "Release", markdown: markdown)
        XCTAssertTrue(html.contains("<h1>Release checklist</h1>"))
        XCTAssertTrue(html.contains("<ol start=\"3\">"))
        XCTAssertTrue(html.contains("<ul class=\"task-list\">"))
        XCTAssertTrue(html.contains("<mark>error rate</mark>"))
        XCTAssertTrue(html.contains("<em>on-call</em>"))
        XCTAssertTrue(html.contains("<code>a|b</code>"))
        XCTAssertTrue(html.contains("href=\"https://drel.app\""))
        XCTAssertTrue(html.contains("href=\"mailto:support@drel.app\""))
    }

    func testAutolinksBareURLsInParagraphsAndCode() {
        let markdown = """
        参考 https://example.com/docs?a=1&b=2。
        访问 (https://example.com/next) 或运行

        `curl https://api.example.com/v1/ping`

        ```bash
        open https://example.com/fenced
        ```
        """

        let html = MarkdownRenderer.renderHTML(title: "链接识别", markdown: markdown)

        // Sentence-final punctuation stays out of the href but in the text.
        XCTAssertTrue(html.contains("<a href=\"https://example.com/docs?a=1&amp;b=2\">https://example.com/docs?a=1&amp;b=2</a>。"))
        // An unbalanced closing paren is not part of the link.
        XCTAssertTrue(html.contains("<a href=\"https://example.com/next\">https://example.com/next</a>)"))
        // Inline code spans and fenced blocks both keep their URLs tappable.
        XCTAssertTrue(html.contains("<code>curl <a href=\"https://api.example.com/v1/ping\">"))
        XCTAssertTrue(html.contains("open <a href=\"https://example.com/fenced\">"))
    }

    func testAutolinkLeavesExplicitLinkSyntaxIntact() {
        let markdown = "[控制台](https://example.com/console) <https://example.com/angle> https://example.com/bare"

        let html = MarkdownRenderer.renderHTML(title: "t", markdown: markdown)

        XCTAssertEqual(html.components(separatedBy: "href=\"https://example.com/console\"").count - 1, 1)
        XCTAssertTrue(html.contains("<a href=\"https://example.com/angle\">https://example.com/angle</a>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com/bare\">https://example.com/bare</a>"))
        // The bare pass must not rewrap the visible URL of another anchor.
        XCTAssertFalse(html.contains("</a><a href=\"https://example.com/angle\">"))
    }

    func testAutolinkIgnoresNonWebSchemes() {
        let html = MarkdownRenderer.renderHTML(title: "t", markdown: "ftp://example.com/file")

        XCTAssertFalse(html.contains("href=\"ftp://"))
    }

    func testRendersDrelAppLinksInMarkdown() {
        let markdown = """
        裸链接 drel://app?app_id=dev.drel.data-template&param_title=Hi 也可以，
        或显式 [打开卡片](drel://app?app_id=a.b)。
        """

        let html = MarkdownRenderer.renderHTML(title: "t", markdown: markdown)

        XCTAssertTrue(html.contains("<a href=\"drel://app?app_id=dev.drel.data-template&amp;param_title=Hi\">drel://app?app_id=dev.drel.data-template&amp;param_title=Hi</a>"))
        XCTAssertTrue(html.contains("<a href=\"drel://app?app_id=a.b\">打开卡片</a>"))
    }
}
