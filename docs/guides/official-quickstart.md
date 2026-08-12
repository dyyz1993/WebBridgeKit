# 官方版快速开始

官方版面向普通使用者：安装后直接使用通知与应用中心，不需要部署网关、扫描网关二维码或填写服务地址。

首次打开“应用”时，客户端会自动连接 WebBridgeKit 官方服务，校验 HTTPS 端点、已签名应用清单与 Ed25519 公钥，然后显示可用 PWA。这个过程不导入设备 Key、APNs Token、API Secret 或私钥。

## 发送一条通知

在客户端的口令管理中创建或查看设备 Key 后，业务端只需调用 Push v2：

```bash
curl -X POST https://wbk.shanbox.19930810.xyz:8443/push \
  -H 'Content-Type: application/json' \
  -d '{
    "schema": "webbridgekit.message.v1",
    "type": "plain",
    "deviceKey": "YOUR_DEVICE_KEY",
    "title": "部署完成",
    "body": "生产环境已更新到 2.4.0"
  }'
```

验证码、Markdown、聊天、二维码和审批的字段见 [消息类型 v1](../api/message-types-v1.md)。审批协议及状态、回调语义见 [Approval v1](../api/approval-v1.md)。

官方服务暂时不可用时，应用中心会给出可点击重试；通知历史与已安装能力不会因此要求用户改配自部署网关。

## 何时需要自部署

只有需要自管 PWA 网关、密钥或服务端的团队，才需要走 [自部署网关导入](self-hosted-gateway-import.md)。该流程由部署者提供一次二维码或配置文本，终端用户导入、验证并确认即可。
