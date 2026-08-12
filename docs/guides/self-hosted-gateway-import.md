# 自部署网关导入

此流程只适用于部署开源版并运营自己网关的团队。部署者完成网关部署后，向用户提供二维码或一段可粘贴配置；用户在“应用”右上角“自有服务”中扫码或粘贴，客户端验证成功后显示确认页，用户确认才会保存并启用。

## 可携带配置

二维码可承载以下 JSON，或等价的 `webbridgekit://gateway` URL：

```json
{
  "id": "example-gateway",
  "name": "Example Team Gateway",
  "baseURL": "https://gateway.example.com",
  "healthPath": "/health",
  "manifestPath": "/api/v1/html-apps",
  "publicKeyID": "prod-ed25519-1",
  "publicKey": "BASE64_ED25519_PUBLIC_KEY"
}
```

生产环境必须是精确的 HTTPS Origin。仅开发构建允许 `localhost` HTTP；发布版不会静默接受普通 HTTP。

配置中只能出现公开的端点和 Ed25519 公钥。不得包含 APNs Token、设备 Key、API Secret 或私钥。

## 客户端验证与切换

导入时，客户端依次验证：健康检查、每一份应用清单、应用来源限制以及清单签名。确认页会显示域名和所有端点；失败不会保存配置。

切换或删除网关会把该网关已验证 PWA 的信任记录和能力授权一并移除，避免将旧网关的权限带给新身份。用户可随时再次编辑、切换或删除网关。
