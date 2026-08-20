# WebBridgeKit PWA / Bridge 网页开发指南

面向要在 WebBridgeKit 运行时里开发「有 Bridge 能力的网页 / PWA」的开发者。
本文回答三件事：怎么接入、哪些能力**免授权**直接用、哪些能力**必须授权**才能用。

---

## 1. 三十秒理解模型

```
你的网页
   │  window.webkit.messageHandlers.BarkBridge.postMessage({action, params})
   │  （或 WebBridge.js 的 Promise 封装）
   ▼
WebBridgeKit 判定链（仅对"受保护能力"）
   ① 应用身份：必须在信任清单里（签名 manifest 注册过的 PWA）
   ② 能力声明：manifest 必须声明该能力
   ③ Origin 精确匹配（scheme://host:port，非泛域名）
   ④ iOS 系统层未拒绝
   ⑤ 本机授权账本查询（网关|appId|origin|能力 四元组）
   ⑥ 都没有 → 弹原生授权面板（仅这一次/本次使用期间/始终允许）
   ▼
Handler 执行 → receiveResult 回调回网页
```

- **普通网页**（未注册）也能用 Bridge，但只能用「免授权能力」（见 §3）
- **授权数据只存在用户设备本机**（UserDefaults，会话授权只在内存），服务器不存
- 网页**无法**枚举授权列表、无法撤销授权——查看/撤销只走原生 UI
  （设置 → 安全 → 网页授权管理；应用详情 → 权限与原生能力）

## 2. 接入方式

### 2.1 普通 Bridge 调用（任何页面可用）

页面加载时 `WebBridge.js` 已自动注入（documentStart）。

```js
// Promise 风格（推荐）
const info = await window.BarkBridge.call('getSystemInfo');

// 原始消息风格
window.webkit.messageHandlers.BarkBridge.postMessage({
    action: 'getSystemInfo',
    params: {}
});
// 结果经 window.BarkBridge.receiveResult({success, data, callbackId}) 回调
```

### 2.2 注册为 PWA（获得受保护能力的前提）

1. 准备 `manifest.json`（由网关签名分发），关键字段：
   - `appid`、`name`、`startURL`
   - `allowedOrigins`：允许的 origin 列表（精确匹配）
   - `capabilities`：声明要用哪些受保护能力（见 §4）
   - `routes`：应用内路由
2. 用户导入网关配置（扫码/粘贴）→ 验证签名 → 确认启用
3. 之后从「我的应用」启动的页面即具备应用身份

### 2.3 请求授权（运行时）

```js
// 网页只能"请求"；弹不弹面板、授不授，由原生决定
window.BarkBridge.call('requestPermission', { type: 'camera' })
    .then(r => console.log(r));   // 用户拒绝时收到 denied 错误
```

### 2.4 查询状态（只读、单能力三态）

```js
window.BarkBridge.call('getPermissionStatus');
// 返回系统层状态：authorized / denied / notDetermined / limited
// 注意：不含应用层授权（scope/账本），网页无权枚举
```

## 3. 免授权能力（默认直接可用）

以下 action 不在能力门控清单里，**任何页面无需注册、无需授权**即可调用：

| 分类 | action | 说明 |
|---|---|---|
| 设备信息 | `getSystemInfo` `getNetworkInfo` | 只读基本信息 |
| 页面导航 | `openPage` `closePage` `goBack` `setModal` `page` `layout`* | 容器内导航（*`layout`/`screen`/`gesture` 属设备控制组，见 §4） |
| 历史/上下文 | `getHistory` `getPayload` | 本页启动参数与历史 |
| 反馈 | `haptic` `vibrate` `tts` | 触感/振动/朗读 |
| 调试 | `cacheDebug` | 缓存调试（getInfo/listRules/clearAll 等） |
| 系统 | `openSettings` | 跳系统设置 |
| 权限查询 | `getPermissionStatus` | 只读三态，见 §2.4 |

## 4. 受保护能力（必须注册 + 声明 + 授权）

| 能力（capability） | 触发 action | 面板上显示名 |
|---|---|---|
| camera | `camera` `videoStream` | 相机 |
| microphone | `audioLevel` `speech` | 麦克风 |
| location | `getLocation` | 位置 |
| photoLibrary | `photo` `media(saveImage)` | 照片 |
| clipboard | `clipboard` | 剪贴板 |
| contacts | `contacts` | 通讯录 |
| scan | `scan` | 扫码 |
| share | `share` | 系统分享 |
| notification | `showNotification` `systemExtra(setBadge)` | 通知 |
| bluetooth | `bluetooth` | 蓝牙 |
| motion | `sensors` | 运动传感器 |
| deviceControl | `gesture` `layout` `screen` `systemExtra(其他)` | 设备控制 |
| displayStatus | `mirroring` | 投屏状态 |
| fileImport | `file` | 读取文件 |
| fileExport | `media(saveFile/uploadFile)` | 导出文件 |
| biometrics | `systemExtra(authenticate)` | 身份验证 |

规则：

1. manifest 的 `capabilities` 数组必须包含该能力，否则**连授权面板都不会弹**（直接拒）
2. 首次调用弹原生面板，用户选择授权范围：
   - **仅这一次**：本次调用有效，不落盘
   - **本次使用期间**：会话有效，页面关闭自动失效
   - **始终允许**：落盘持久，直到用户在原生界面撤销
3. iOS 系统层是第二道门（系统拒绝时面板无法翻案，会引导去系统设置）
4. 撤销授权后再次调用 → 面板重新弹出

## 5. 授权数据与撤销

- 存储：本机 `UserDefaults`（key `com.webbridgekit.html-app-runtime.permission-grants`）
- 身份四元组：`网关身份 | appID | origin | 能力`——换网关、换应用身份授权不跟随；
  origin 是 `scheme://host://port` 精确匹配（**非泛域名**，path 不参与）
- 用户查看/撤销入口（原生）：
  - 设置 → 安全 → **网页授权管理**（按网页域名维度）
  - 应用详情 → 权限与原生能力（按应用维度）

## 6. 常见问题

**Q: 我的页面调用 camera 没有任何反应？**
按判定链自查：① 页面是否以注册 PWA 身份打开（普通 URL 打开=无身份）；
② manifest 是否声明 camera；③ 是否曾拒绝（去原生页面撤销后重试）。

**Q: 能不能查"我都被授过什么权"？**
不能。安全设计：网页只能查单个能力的系统层三态，授权账本只对原生 UI 开放。

**Q: 授权能由网页主动放弃吗？**
不能。撤销只能由用户在原生界面操作，防止网页诱导性回收。

---

相关源码：`Sources/Runtime/HTMLAppBridgeCapabilityPolicy.swift`（能力映射表·权威来源）、
`Sources/Runtime/HTMLAppRuntime.swift`（判定链/账本）、
`SuperAppUITests/PWAPermissionTests.swift`（端到端行为参考）。
