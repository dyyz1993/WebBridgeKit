# Drel 1.4 离线网络演示

## 目的

验证 Drel 的强离线包与普通 Web 网络能力可以同时工作，但不混淆它们的责任：

- 已校验的 HTML、CSS、JavaScript 在断网后仍从本地包启动；
- 联网时，页面通过标准 `fetch` 请求公网 IP 与天气；
- 断网时，页面只显示 WebView 可用的最近缓存结果，或清晰说明没有缓存；
- Drel 不把任意 API JSON 自动写入强离线包，也不会把过期数据表述为实时数据。

## 公开材料

- 页面：`https://drel.app/test/offline-network/`
- 应用 ID：`dev.drel.offline-network-demo`
- 路由：`/test/offline-network/v1/index.html`
- 资源清单：`https://drel.app/test/offline-network/package.json`
- 生成后的待签名父清单：`build/drel-site-staging/test/offline-network/gateway-manifest.json`
- 模拟推送：`test_resources/offline-network-demo/offline-network-notification.apns`

## 推送负载

在官方或已配置的自托管通道中，对当前设备的 Key 发送：

```json
{
  "deviceKey": "<当前通道的设备 Key>",
  "title": "离线网络演示",
  "body": "点击后从本地包打开，并获取实时 IP 与天气",
  "appId": "dev.drel.offline-network-demo",
  "route": "/test/offline-network/v1/index.html",
  "display": "full",
  "params": { "case": "offline-network-demo" }
}
```

`appId + route` 必须由网关签名并已在 App 中同步。未安装资源包时，Drel 打开在线页；用户主动下载包后，推送与收件箱打开都应解析为本地包入口。

## 真机验收

1. 联网导入应用并主动下载离线包；确认页面显示“已从 Drel 离线包启动”。
2. 联网点刷新；确认 IP 与深圳天气均出现，且有实时更新时间。
3. 通过 APNs 点击上述通知；确认进入同一个应用和同一全屏展示，而不是普通网页页。
4. 强制退出、开启飞行模式并关闭 Wi-Fi；重新从“我的应用”和 Inbox 打开。页面必须出现，网络状态必须是离线。
5. 离线点击刷新；不得白屏、崩溃或伪造实时数据。若之前有 WebView 缓存，应标为“最近缓存”；否则标明“尚无缓存”。
6. 恢复网络后刷新；应重新取得实时数据。

此演示不请求定位、不使用 Bridge、不需要原生权限。天气固定为深圳坐标，避免把定位权限混入离线/联网验证。
