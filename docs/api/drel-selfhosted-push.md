# Drel 自托管推送 API

此 API 是 Drel 的可选自托管推送路径。它直接使用部署者**私有且已获该 App topic 授权**
的 APNs 投递材料，不调用 `api.drel.app`。默认是可读的直接投递；发送侧端到端加密是
额外可选模式，适合验证码等不希望被自建服务器读取的内容。Drel 不公开它自己的 APNs
私钥；使用已上架 Drel App 的第三方无法凭自己的 Apple team 直接签发
`com.webbridgekit.superapp` 的投递权限。

`deviceKey` 是一个可投递能力地址，不是可公开索引的用户 ID；只发送给可信的发送端。

## 默认：直接推送

配对后，Drel 会显示一个简短的兼容地址。它可直接从浏览器、脚本或自动化调用：

```bash
curl -G 'https://push.example.com/<deviceKey>/Build%20ready/Inspect%20the%20result' \
  --data-urlencode 'url=https://drel.app/' \
  --data-urlencode 'mode=immersive'
```

也可使用 JSON，适合自动化程序：

```http
POST /push
Content-Type: application/json

{
  "deviceKey": "…",
  "title": "Build ready",
  "body": "Inspect the result",
  "url": "https://drel.app/",
  "mode": "immersive"
}
```

`POST /push` 的 JSON 使用与官方 Drel 相同的可移植消息字段：`schema`、`type`、
`subtitle`、`category`、`markdown`、`sound`、`badge`、`icon`、`image`、`group`、
`threadId`、`url`、`copy`、`isArchive`、`level`、`volume`、`call`、`autoCopy`、
`appId`、`route`、`mode`、`display`、`verificationCode`、`expiresAt`、`ttl`、`id`、
`delete`、`actionState`、`requestId`、`contentType`、`qrPayload`、`statePath`、
`revision`、`params`、`presentation` 和 `approval`。

短 URL 形式支持其中所有**标量**字段作为查询参数；`params` 和 `approval` 是嵌套 JSON，
只能通过 `POST /push` 传入。这样不会把一个无法解析的嵌套对象伪装成可用 URL 参数。
例如 `mode=immersive` 会原样随 APNs 投递：当用户点按通知后，Drel 会以全屏容器打开
`url`。iOS 不允许通知强行把正在前台的 App 自动切到全屏，这不是该参数失效。
`drelSourceChannel` 是例外：它由中继从自身地址生成，发送端不能设置或伪造。

直接模式由自建服务器构造普通 APNs 通知；它可以读取标题、正文和 URL，因而不能被
表述为端到端加密。它不会向 `api.drel.app` 发送这些字段。

自建中继还会从**自身的公开 HTTPS 地址**派生一个内部来源标签，随 APNs 一起交给
Drel，用于在客户端切换“官方 / 自建”通道时筛选本地历史。该标签不属于 API 参数，发送
方不能指定或伪造它；旧登记在中继升级后也会按当前服务地址补齐，不需要重新配对。

## 可选：端到端加密

## 配对后发现接收方公钥

```http
GET /self-hosted/recipients/{deviceKey}
```

成功响应：

```json
{
  "schema": "drel.self-hosted-recipient.v1",
  "deviceKey": "…",
  "encryptionPublicKey": "base64url-32-byte-X25519-public-key",
  "pushPath": "/push",
  "envelopeSchema": "drel.push-envelope.v1"
}
```

该响应不包含 APNs device token、配对令牌、私钥或服务端 provider 凭据。未配对或已
撤销的 key 返回 `404`。

## 发送端信封

1. 本地生成 UUID `messageId`，以及 `createdAt`、最多 **10 分钟**后的 `expiresAt`。
2. 生成一次性 X25519 密钥对，并与 `encryptionPublicKey` 协商共享密钥。
3. 用 HKDF-SHA256 派生 32-byte AES key：
   `sharedInfo = drel.push-envelope.v1|{messageId}|{createdAt}|{expiresAt}`。
4. 用 AES-256-GCM 加密内部 `PushPayload` JSON。`ciphertext` 是
   `nonce(12 bytes) || ciphertext || authenticationTag(16 bytes)` 的 base64url 编码。
5. 将下面的 JSON 信封整体再做 base64url，作为 `drelEnvelope`。

```json
{
  "schema": "drel.push-envelope.v1",
  "messageID": "UUID",
  "createdAt": 1700000000,
  "expiresAt": 1700003600,
  "ephemeralPublicKey": "base64url-32-byte-X25519-public-key",
  "ciphertext": "base64url(nonce|ciphertext|tag)"
}
```

内部 JSON 是正常的 Drel `PushPayload`，例如：

```json
{
  "title": "Build finished",
  "body": "Code 482901",
  "messageId": "同一个 UUID",
  "url": "https://drel.app/"
}
```

## 投递

```http
POST /push
Content-Type: application/json

{
  "deviceKey": "…",
  "title": "",
  "body": "",
  "drelEnvelope": "base64url(JSON envelope)"
}
```

服务端验证信封结构、期限、大小和算法版本，但不解密。为避免发送端误以为外层字段会
生效，它会**拒绝**同时携带标题、正文、`mode` 或其他业务字段的加密请求；成功请求只把
通用占位通知、`mutable-content`、`messageId` 和信封交给 APNs。Drel 的通知扩展在设备
上解密后再显示真实内容。

可直接使用 [Node 发送参考](../../Server/examples/drel-encrypt-and-push.mjs)。该工具不
依赖第三方包。

## 撤销与重置

设备移除自托管服务器或点击“重置推送地址”时，会调用：

```http
POST /unregister
Content-Type: application/json

{ "deviceToken": "…", "key": "<deviceKey>" }
```

服务端仅在这两个值与同一条登记完全一致时删除记录。重置会生成新 `deviceKey` 和新的
本机 X25519 identity，旧地址随即不能继续投递。撤销返回后，`POST /push` 和兼容 URL
对旧地址均返回 `404`。

## 信任边界

`/<deviceKey>/<title>/<body>` 等 Bark 兼容 URL 是直接/便利模式，发送内容先到达自建
服务器；它们不是针对自建服务器运营者的端到端保密模式。只有 `drelEnvelope` 路径会
把内容留在发送方与 iPhone 之间。

严格模式仍要求信任部署者正确保护其 APNs 凭据和注册库：拥有凭据的一方可能伪造
“来自此 App”的通知，但不能从发送侧信封恢复内容。
