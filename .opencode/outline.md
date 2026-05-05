# WebBridgeKit 项目大纲

## 会话信息
- **创建时间**: 2026-05-05
- **最后更新**: 2026-05-05
- **仓库**: github.com/dyyz1993/WebBridgeKit

## 当前架构（四层 + 基础设施）

```
SuperApp（业务层）→ AppTemplate（脚手架）→ Bridge引擎 + Cache引擎 + Message引擎 → Infrastructure（基础设施）
```

## 已完成的重构

### 仓库清理 (commits 27d4360, 04fe179)
- 删除 20 个 AI 垃圾文档 (-15,993 行)
- 修复 .gitignore（287→100 行）
- 移动 5 个 App Manager 从框架到 DemoApp（现 SuperApp）
- 删除死代码（TabConfigurationManager, RealmConfiguration）
- 添加 GitHub Actions CI

### 三层架构重构 (commit 06b32c6)
- DemoApp → SuperApp 重命名
- 创建 AppTemplate 脚手架（AppDelegate + RootViewController）
- 添加 Push 模块骨架（PushRouter, PushPayload, PushNotificationManager）
- 更新 project.yml / Podfile / CI workflows
- 4 个 target: WebBridgeKit / AppTemplate / SuperApp / SuperAppUITests

### CI 流水线
- 编译检查 + SwiftLint + 并行 UI 测试（Smoke先行）
- 打 tag 自动构建 IPA
- macos-15 runner, iPhone 16 simulator
- 截图 + 测试报告上传

## 实施计划 (.opencode/plan.md)

8 个阶段，6-10 周：

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | 基础设施（日志+诊断）| 🔄 进行中 |
| 2 | Bridge 重构（协议+注册+异常）| ⏳ 待开始 |
| 3 | Debug 面板（自动发现+一键测试）| ⏳ 待开始 |
| 4 | Cache 独立（接口+测试套件）| ⏳ 待开始 |
| 4.5 | Message 引擎（推送+路由+Bark）| ⏳ 待开始 |
| 5 | AI 接口（HTTP API + MCP）| ⏳ 待开始 |
| 6 | 脚手架升级（主题+示例+Skill）| ⏳ 待开始 |
| 7 | SuperApp 开发（完整业务）| ⏳ 待开始 |

## Phase 1 进度

### 1.1 结构化日志系统 ✅
已创建文件：
- Sources/Infrastructure/Logging/LogEntry.swift — 日志级别(LogLevel)、分类(LogCategory 12种)、结构化条目
- Sources/Infrastructure/Logging/LogPipeline.swift — 4种输出：Console/Memory/File/Callback
- Sources/Infrastructure/Logging/StructuredLogger.swift — 单例引擎，多管道，查询，measure()

### 1.2 诊断系统 ✅
已创建文件：
- Sources/Infrastructure/Diagnostic/EnvironmentInfo.swift — 设备/内存/磁盘/网络快照
- Sources/Infrastructure/Diagnostic/ErrorContext.swift — 错误上下文捕获+最近日志+环境
- Sources/Infrastructure/Diagnostic/DiagnosticEngine.swift — 健康检查+诊断报告

### 1.3 替换现有 WebBridgeLogger ⏳
- 需要创建兼容层，让现有代码逐步迁移

### 1.4 编译验证 + 测试 + 提交 ⏳

## 关键文件位置

| 文件 | 路径 |
|------|------|
| 实施计划 | .opencode/plan.md |
| 项目大纲 | .opencode/outline.md |
| 项目配置 | project.yml |
| 依赖管理 | Podfile |
| CI 配置 | .github/workflows/ci.yml, build-ipa.yml |
| 代码规范 | .swiftlint.yml |

## 三大引擎定位

### Bridge 引擎
- JS ↔ Native 通信
- 35+ Handler
- 注册发现机制（待重构）
- 统一异常处理（待重构）

### Cache 引擎
- ManifestCache 离线缓存
- ResourceCache 资源管理
- 规则引擎
- 历史记录
- 独立模块，不依赖 Bridge

### Message 引擎（新增）
- 推送通知（APNs）
- 消息路由（appid→缓存/url→浏览器/mode→样式）
- Bark 服务端集成
- 独立模块，有自己协议和存储

## 注意事项

- 所有新模块都要有对应的测试
- 测试要推到 Git
- Handler 自动发现机制是 Phase 2 的核心
- Debug Panel 基于 Handler Meta 自动生成，零维护
- AI 接口通过 localhost:8765 暴露，仅 DEBUG 模式
- 主题系统在脚手架层定义
