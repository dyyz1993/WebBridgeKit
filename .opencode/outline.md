# WebBridgeKit 项目大纲

## 会话信息
- **创建时间**: 2026-05-05
- **最后更新**: 2026-05-05 (Phase 3 进行中, 90% 完成)
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

| Phase | 内容 | 状态 | Commit |
|-------|------|------|--------|
| 1 | 基础设施（日志+诊断）| ✅ 已完成 | 69bdaf8 |
| 2 | Bridge 重构（协议+注册+异常）| ✅ 已完成 | f92a885 |
| 3 | Debug 面板（自动发现+一键测试）| 🔄 进行中 | 5a14d1d, fc4f136 |
| 4 | Cache 独立（接口+测试套件）| ⏳ 待开始 | |
| 4.5 | Message 引擎（推送+路由+Bark）| ⏳ 待开始 | |
| 5 | AI 接口（HTTP API + MCP）| ⏳ 待开始 | |
| 6 | 脚手架升级（主题+示例+Skill）| ⏳ 待开始 | |
| 7 | SuperApp 开发（完整业务）| ⏳ 待开始 | |

## Phase 1 — 基础设施 ✅ 已完成

**Commit**: `69bdaf8` · 12 files · +2216 lines

### 1.1 结构化日志系统
- Sources/Infrastructure/Logging/LogEntry.swift — LogLevel、LogCategory(12种)、结构化条目
- Sources/Infrastructure/Logging/LogPipeline.swift — 4种输出管道：ConsolePipeline / MemoryPipeline / FilePipeline / CallbackPipeline
- Sources/Infrastructure/Logging/StructuredLogger.swift — 单例引擎，多管道组合，查询/过滤/measure()

### 1.2 诊断系统
- Sources/Infrastructure/Diagnostic/EnvironmentInfo.swift — 设备/内存/磁盘/网络快照
- Sources/Infrastructure/Diagnostic/ErrorContext.swift — 错误上下文捕获 + 最近日志 + 环境
- Sources/Infrastructure/Diagnostic/DiagnosticEngine.swift — 健康检查 + 诊断报告生成

### 1.3 兼容层
- Sources/Infrastructure/Compatibility/LogCompatibility.swift — LogCompatibility 桥接旧 WebBridgeLogger，渐进式迁移

### 1.4 测试
- Tests/LoggingTests.swift — 日志系统完整测试
- Tests/DiagnosticTests.swift — 诊断系统完整测试

## Phase 2 — Bridge 重构 ✅ 已完成

**Commit**: `f92a885` · 6 files · +1016 lines

### 2.1 Handler 元数据
- Sources/BridgeEngine/HandlerMeta.swift — 12个分类、ParamDef、ReturnDef、HandlerMetadata 结构

### 2.2 Handler 注册表
- Sources/BridgeEngine/HandlerRegistry.swift — 线程安全注册、按分类查询、文档生成（JSON + Markdown）

### 2.3 Handler 元数据声明
- Sources/BridgeEngine/HandlerMetaRegistry.swift — 34个 Handler 的元数据声明（参数/返回值/分类/文档）

### 2.4 统一异常体系
- Sources/BridgeEngine/BridgeError.swift — 8种错误类型，含错误码、修复建议、debugInfo、jsErrorDict()

### 2.5 测试
- Tests/HandlerRegistryTests.swift — HandlerRegistry 注册/查询/文档生成测试

## Phase 3 — Debug 面板 🔄 进行中 (90% 完成)

**Commits**: `5a14d1d`, `fc4f136`, + URL Scheme & DEBUG enforcement

### 3.1 已完成功能
- **Debug Panel UI**: AppTemplate/Sources/Debug/DebugPanelViewController.swift
  - 按分类显示所有 Handler（基于 HandlerRegistry 自动发现）
  - 一键测试功能（弹窗选择 Handler → 执行 → 显示结果）
  - Handler 元数据展示（名称/描述/分类标签）

- **TabBarController**: AppTemplate/Sources/TabBarController.swift
  - 5 个 Tab：Web / Handlers / Logs / Diagnostics / Settings（DEBUG 模式）
  - Release 模式：仅 Web Tab（DEBUG 模式强制限制）
  - 导航栏配置（大标题 + 外观设置）
  - 集成到 AppTemplate 作为根控制器

- **Debug Trigger**: AppTemplate/Sources/Debug/DebugTrigger.swift
  - 摇一摇触发显示 Debug Panel（模态弹窗）
  - URL Scheme 触发：`app://debug`, `webbridgekit://debug`
  - 支持从任意视图控制器启动
  - DEBUG 模式强制限制

- **Logs Tab**: AppTemplate/Sources/Debug/LogViewerViewController.swift
  - 实时日志展示（基于 StructuredLogger）
  - 按分类过滤
  - 错误过滤
  - 一键复制全部日志
  - 导出 JSON

- **Diagnostics Tab**: AppTemplate/Sources/Debug/DiagnosticViewController.swift
  - 诊断报告展示（基于 DiagnosticEngine）
  - 健康检查
  - 一键复制报告

- **Settings Tab**: AppTemplate/Sources/Debug/EnvironmentViewController.swift
  - 环境信息展示（基于 EnvironmentInfo）
  - 一键复制全部信息

- **测试套件**: Tests/Infrastructure/DebugPanelTests.swift
  - DebugPanel 初始化测试
  - TabBarController 结构测试（5 个 Tab 验证）
  - Handler 列表展示测试
  - 一键测试功能测试

### 3.2 待完成功能
- **长按 Logo 3 秒触发** - 需要在 Logo 添加长按手势（可选）

### 3.3 验收标准 (对照计划)
- [x] Debug Panel 自动列出所有 35 个 Handler ✅
- [x] 每个 Handler 可以直接测试（填参数 → 执行 → 看结果）✅
- [x] 新增 Handler 后 Debug Panel 自动出现，零维护 ✅
- [x] 摇一摇触发 ✅
- [ ] 长按 Logo 3 秒触发 ❌（可选）
- [x] URL Scheme: `app://debug` 触发 ✅
- [x] 日志可以实时查看和搜索 ✅
- [ ] 消息引擎状态可查看和调试 ❌（Phase 4.5）
- [x] 所有结果/错误都可以一键复制 ✅
- [x] Release 模式下 Debug Panel 自动隐藏 ✅

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
