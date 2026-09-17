# Drel 外部应用拉起链接（drel://app）v1

> 状态：v1（随 1.4.0 (75) 发布）。其他 App、快捷指令、二维码都可以用它
> 直接拉起 Drel 里一个**已注册**的 HTML 应用并携带参数。

## 链接格式

```
drel://app?app_id=<必填>&route=<可选>&param_<name>=<值>...
```

| 字段 | 说明 |
|---|---|
| `app_id` | 应用 ID（如 `dev.drel.data-template`）。必须在接收设备的**受信注册表**中已注册（经网关导入或推送激活），否则 fail-closed 弹「应用未注册」 |
| `route` | 可选。应用的逻辑路由（须匹配 manifest 声明的 routes）；缺省用入口路由 |
| `param_<name>` | 可选，可多个。字符串参数，经 `drel_param_<name>` 查询参数送达页面（与推送/模板契约同一条通道），页面用 `URLSearchParams` 读取 |

示例（拉起数据模板并渲染标题）：

```
drel://app?app_id=dev.drel.data-template&route=/test/template/v1/index.html&param_title=%E5%A4%96%E9%83%A8%E6%8B%89%E8%B5%B7
```

## 行为

- **呈现**：与推送打开一致——沉浸式全屏（无导航栏），左侧边缘有退出控件。
- **冷启动**：支持（链接在 UI 就绪后处理，并抑制本次启动的会话恢复）。
- **离线**：目标应用若已下载离线包，参数照常送达本地入口。

## 安全边界（为什么没有 url= 参数）

本链接**刻意不提供任意 URL 直通**——只接受 appId+route，且必须命中网关
签名的受信注册表（`HTMLAppLaunchResolver`，fail-closed）。未注册的 appId
只会得到解释性弹窗，不会打开任何浏览器。这是它与被否决的
`webbridgekit://open?url=` 的本质区别，也是 App Review 安全立场的延续。

参数值是远程不可信数据：模板页必须只用 `textContent` 渲染（见
[drel-offline-template.md](drel-offline-template.md)）。

## 其他 drel:// host

- `drel://self-hosted-push?...` / `drel://managed-encrypted-push?...`：
  自托管推送配置码。经系统入口打开时复制到剪贴板并引导到
  设置 → 推送通道 粘贴导入（不静默自动配对）。

## 参考

- 解析器：`Sources/Runtime/DrelExternalAppLink.swift`（纯函数，有单测）。
- 处理器：`SuperApp/Sources/AppDelegate.swift` `handleDrelExternalURL`。
- 回归测试：`SuperAppUITests/DeepVerificationTests/`
  `testExternalAppLinkOpensRegisteredAppImmersive` /
  `testExternalAppLinkFailsClosedForUnregisteredApp`。
- scheme 注册：`SuperApp/Sources/Info.plist` CFBundleURLSchemes。
