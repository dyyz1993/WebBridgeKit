# 自部署网关导入

此流程只适用于部署开源版并运营自己网关的团队。官方版本安装后直接使用，不会要求普通用户先配置网关。

部署者完成网关部署后，向用户提供二维码或一段可粘贴配置。用户进入“自有服务/网关管理”，扫码或粘贴；客户端在同一页完成验证并展示报告，用户点击“启用此网关”后才会保存和切换。

## 可携带配置

二维码可承载以下 JSON，或等价的 `webbridgekit://gateway` URL：

```json
{
  "schemaVersion": "1",
  "id": "example-gateway",
  "displayName": "Example Team Gateway",
  "baseURL": "https://gateway.example.com",
  "healthEndpoint": "/health",
  "manifestEndpoint": "/api/v1/html-apps",
  "publicKeyId": "prod-ed25519-1",
  "publicKey": "BASE64_ED25519_PUBLIC_KEY"
}
```

生产环境必须是精确的 HTTPS Origin。仅开发构建允许 `localhost` HTTP；发布版不会静默接受普通 HTTP。

配置中只能出现公开的端点和 Ed25519 公钥。不得包含 APNs Token、设备 Key、API Secret、管理 Token、密码或私钥；客户端会在解析前主动拒绝这些字段。

## 客户端验证与切换

导入时，客户端依次验证：健康 JSON、最终响应来源、每一份应用清单、应用来源限制、公钥 ID 以及清单签名。报告会显示域名、所有端点、公钥 ID 和应用数量；失败停留在当前上下文，不保存配置。

点击启用时，网关配置、manifest 与授权边界作为一个事务替换。任何持久化失败都会保留原网关。切换 origin 或公钥身份、删除活动网关时会清除原网关已验证 PWA 的能力授权，避免把旧身份的权限带给新身份。

完整字段、错误语义、非法示例和 QR 生成命令见 [`docs/api/gateway-v1.md`](../api/gateway-v1.md)。
