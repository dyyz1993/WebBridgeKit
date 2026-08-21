# App Store 审核材料

## Review Notes（提交审核时粘贴到 App Review Information → Notes）

```
This app is a developer tool for web bridge capabilities. It embeds a
WebView where developers can load their own web pages and call native
APIs (camera, location, clipboard, etc.) through a JavaScript bridge.

Key points:
- All native API access requires explicit user consent through an
  in-app permission dialog (similar to how Safari asks for camera or
  location permission per website)
- Permission grants are stored locally on the device only
- No data is collected or transmitted to third parties
- Push notifications are opt-in and used for the app's core function
  (Bark-compatible push notification client)
```

## App Privacy 标签（App Store Connect → App Privacy）

选择：**我们不从此 App 收集数据**

理由：
- 授权记录仅存本机 UserDefaults
- 推送消息仅经服务器中转，不落库（MESSAGE_HISTORY_ENABLED=false）
- 无用户账号系统、无分析 SDK、无广告追踪

## 权限用途声明（Info.plist 已配置）

| 权限 | Info.plist 文案 |
|------|----------------|
| 相机 | 允许你授权的网页应用使用相机拍照和扫码 |
| 蓝牙 | 允许你授权的 PWA 扫描附近的蓝牙低功耗设备 |
| 照片 | 允许你授权的网页应用选择和保存照片 |
| 通讯录 | 允许你授权的网页应用读取你选择的联系人 |
| 位置 | 允许你授权的网页应用获取你的大致位置 |
| 麦克风 | 允许你授权的网页应用使用麦克风录音和语音识别 |
| 语音识别 | 允许你授权的网页应用将你的语音转为文字 |
| 运动 | 允许你授权的网页应用读取设备运动数据 |
| FaceID | 允许你授权的网页应用使用面容 ID 进行身份验证 |

## 审核注意事项

1. **避免的用词**（在 App 描述和截图里）：
   - ❌ "app store"、"应用商店"、"分发应用"
   - ❌ "下载应用"、"安装应用"
   - ✅ "web page"、"网页"、"shortcut"、"快捷方式"、"developer tool"

2. **审核心态**：定位为「开发者工具」（类 Postman/Charles），不是平台
3. **演示**：审核员打开后看到的是通知工具+内置浏览器，Bridge 能力需要主动加载网页才会触发
