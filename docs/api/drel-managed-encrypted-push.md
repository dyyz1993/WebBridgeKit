# Drel 托管加密推送协议（V2，未启用）

> 这是给 **App Store 版 Drel** 准备的后续协议，当前没有在 `api.drel.app`
> 启用，也没有进入已提交的 Store build。它与“自建服务器直连 APNs”是两条明确
> 分开的路线。

## 它解决什么问题

Apple 的 APNs provider key 必须由有权为 `com.webbridgekit.superapp` 签名的
运营方保管；因此第三方自建服务器无法为原版 Drel App 直接签发 APNs。

此协议让发送端在上传前使用每台 iPhone 的 X25519 公钥加密消息。Drel 托管的
签名服务只看到：

- APNs device token（投递所必需）；
- `deviceKey`（可撤销的推送能力）；
- 接收端 X25519 **公钥**；
- 不可解密的 `drelEnvelope` 及投递时间、状态等元数据。

它不会收到标题、正文、URL、验证码、图片地址或解密私钥；私钥只存在于该 iPhone
受保护的 App Group 数据中。它不是“消息完全不经过 Drel 基础设施”：APNs 投递元数据
仍会经过 Drel 的签名服务。

## 服务端开关

托管签名服务只能由 Drel 的受控运营环境启用。实现可以开源；生产签名权限不能开源：

```dotenv
# APNS_* 指向仅运营方可读的 topic-specific provider credential。
DREL_MANAGED_PUSH_ENABLED=1
DREL_MANAGED_PUSH_NAME="Drel Managed Encrypted Push"
DREL_MANAGED_PUSH_PUBLIC_BASE_URL=https://api.drel.app
# 每个 deviceKey 的默认 APNs 签名上限。
DREL_MANAGED_PUSH_MAX_DELIVERIES_PER_MINUTE=60
```

不要在第三方自建 Docker/Go relay 设置这个开关，也不要复制或要求 Drel 的 `.p8`。
未启用时，路由根本不会注册；开关已打开但 signer 不可用时，进程会拒绝启动，
不会留下可注册却永远无法投递的半启用入口。

Cloudflare 生产实现位于 `infra/cloudflare/drel-api-proxy/`：已有
`api.drel.app` Worker 仅截取此协议的路径，其余 API 继续反代。配对和注册状态
进入同一个 Durable Object，以保证一次性票据的原子消费；不使用最终一致的 KV。
GitHub Actions 只持有受限的 Cloudflare 部署 token。`APNS_AUTH_KEY_P8`、key id、team id、
topic 和启用开关只能作为 Cloudflare Worker Secret 运行时注入，绝不放进 GitHub Actions
secrets 或仓库。服务默认未启用。

## 配对与注册

1. Drel App 从 `POST /managed-push/pairings` 获得一次性、短时 pairing token。
2. App 向 `POST /managed-push/register` 发送 APNs token、随机 `deviceKey`、X25519
   公钥与 pairing token。
3. 发送方使用 `GET /managed-push/recipients/{deviceKey}` 取得**仅公钥**的收件人材料。
4. 删除或重置地址时，App 以 token + `deviceKey` 调用
   `POST /managed-push/unregister`；该地址立即不再可发现、不可投递。

持久化的 pairing store 只保存 ticket 的 SHA-256 摘要，不能从磁盘恢复可兑换 token。

`GET /managed-push/health` 返回 `apnsReady`；App 只应在其为 `true` 后创建/轮换本地
X25519 身份或消耗 pairing ticket。descriptor 新增 `healthPath`，值为该地址。

## 严格投递请求

发送方按现有 `drel.push-envelope.v1` 规范（X25519 + HKDF-SHA256 + AES-256-GCM）
构造信封，然后只发送一个 JSON 字段：

```http
POST /managed-push/deliveries/{deviceKey}
Content-Type: application/json

{"drelEnvelope":"<base64url envelope>"}
```

该端点拒绝所有额外字段（包括 `title`、`body`、`url`）；不会“宽容地忽略”意外
明文。签名服务验证信封版本、期限及大小后，将空白外层通知、`messageId` 与信封交给
APNs。NSE 在 iPhone 本地解密并替换占位内容。

每个 `deviceKey` 默认限制 60 次/分钟，防止被泄露的可写地址成为无限 APNs 发送器。
限速不是机密性控制；应在 App 内“重置推送地址”以彻底失效旧能力。

## 与直接自建的区别

| 模式 | APNs provider key | 消息明文到哪 | 原版 Drel App 可用 |
| --- | --- | --- | --- |
| 直连自建 | 自建者自己授权、自己保管 | 自建者可见（除非发送端额外加密） | 仅拥有独立签名 App/topic 的高级部署 |
| 托管加密签名 | Drel 运营方私有保管 | 仅 iPhone；签名服务为不透明信封 | 是，计划 V2 |

`/<deviceKey>/<title>/<body>` 等 Bark 兼容 URL 保持便利模式；它们不适用于该托管加密
接口，因为路径本身会暴露标题和正文。
