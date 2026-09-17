# Drel 离线模板数据契约 v1

> 状态：v1（随 1.4.0 (74) 发布）。参考实现：`dev.drel.data-template`，
> 页面 `https://drel.app/test/template/v1/index.html`。

## 目标

发送方推送一条带数据的消息，接收端（在线或离线）打开一个**模板 HTML 应用**，
模板读取推送数据渲染成卡片——「下载离线模板 + 推数据源 → 可视化推送」。
本契约定义推送参数如何到达模板页面。**不涉及 Bridge、不涉及授权**：
数据以 URL 查询参数送达，任何能读 `location.search` 的页面都能消费。

## 推送侧

JSON `POST /push` 携带 HTML 应用信封：

```json
{
  "device_key": "<推送标识>",
  "title": "构建完成",
  "body": "v1.2.3 已发布",
  "appId": "dev.drel.data-template",
  "route": "/test/template/v1/index.html",
  "params": {
    "title": "v1.2.3 发布",
    "body": "全部检查通过，已推送到生产。",
    "items": "新增离线模板"
  }
}
```

- `params` 的值必须是**标量**（字符串/数字/布尔）；容器会统一转成字符串。
  列表语义用重复键表达（GET URL 形态）或约定分隔符。

## 页面侧（契约核心）

客户端经签名 manifest 解析后，把参数以查询参数拼在入口 URL 上打开：

| 查询参数 | 含义 |
|---|---|
| `drel_app_id` | 命中的 HTML 应用 ID |
| `drel_route` | 验证过的逻辑路由（单页应用据此渲染） |
| `drel_source` | 打开来源（如 `notification`） |
| `drel_param_<name>` | 发送方 `params` 的每个键值，按键名排序 |

模板页用 `URLSearchParams` 读取：

```js
const params = new URLSearchParams(location.search);
const title = params.get("drel_param_title") ?? "";
const items = params.getAll("drel_param_items"); // 重复键 → 数组
```

**安全规则（强制）**：`drel_param_*` 全部是远程不可信数据。只能进
`textContent`，绝不许拼 HTML / `innerHTML` / `eval`。

### 离线行为

下载离线包后，`drel_*` 查询参数会拼在**本地包入口**（file://）上，行为一致；
`drel_route` 始终携带验证过的逻辑路由，页面离线也可按 route 渲染。

## 限制

- 参数只支持字符串；复杂结构请序列化（如 JSON 字符串）后自行解析。
- URL 长度实践上限：全部参数（编码后）建议 < 1KB，硬上限 8KB。
- 参数名经 `drel_param_` 前缀隔离，不会与宿主的展示策略参数
  （`mode`、`hideNavBar` 等）冲突。

## 参考

- 传递机制实现：`Sources/Runtime/HTMLAppLaunchRuntime.swift` 的
  `containerOnlyURL`（Store 容器构建即用此通道，无 Bridge）。
- 模板页面源码：`test_resources/data-template/v1/index.html`；
  站点构建：`tools/build-drel-data-template-site.sh`（产出 package.json /
  manifest.webmanifest / gateway-manifest.json）。
- 服务器种子：`POST /api/v1/html-apps`（Admin API key）持久化到
  `data/html-apps.json` 并即时签名。
