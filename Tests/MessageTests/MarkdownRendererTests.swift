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
}
