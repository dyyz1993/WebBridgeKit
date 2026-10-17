# Drel next release — What's New

Approved copy for the next editable App Store version. The 1.4.0 version is
already `READY_FOR_SALE`, so its locked `whatsNew` cannot be replaced.

## zh-Hans

```text
Drel 1.4.0 更新

• 收藏夹：常用页面一键收藏，支持置顶、时间排序、整滑置顶/取消置顶，以及从收藏夹重新全屏打开
• 收件箱：搜索、分组、未读与置顶能力更完整，通知管理更清晰
• 可信 HTML 应用：可导入你自己信任的网关配置，应用信息来自 Ed25519 签名 manifest，并声明可用路由与离线包
• 强离线模式：应用资源按 SHA-256 校验后保存在本地，断网时也能启动
• 通知头像：推送可携带 HTTPS 图片地址，以发送者头像形式显示在通知中
• drel://app 深层链接：可打开已注册的可信应用指定路由；不支持任意 URL 透传
• 安全与稳定性：远程页面不会获得 JavaScript 到原生 Bridge，多项消息、收藏和通知流程问题已修复
```

## en-US

```text
What's new in Drel 1.4.0

• Favorites: save frequently used pages, pin and unpin with a full swipe, keep pinned and recent items organized, and reopen saved apps in fullscreen
• Inbox: clearer search, grouping, unread, and pinned-message management
• Trusted HTML apps: import gateway configurations you trust; app metadata comes from Ed25519-signed manifests with declared routes and optional offline packages
• Strong offline mode: app resources are verified with SHA-256 and stored locally so they can launch without a network
• Notification avatars: pushes can include an HTTPS image URL shown as the sender avatar
• drel://app deep links: open a specific route in a registered trusted app; arbitrary URL passthrough is not supported
• Security and stability: remote pages still do not receive a JavaScript-to-native Bridge, with fixes for messaging, favorites, and notification flows
```

Before the next submission, update the version heading from `1.4.0` to the
actual App Store version and re-check whether any newer features should be
added to the list.
