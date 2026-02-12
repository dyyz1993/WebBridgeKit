# WebBridgeKit Manifest 缓存功能测试文档索引

## 文档概述

本目录包含 WebBridgeKit Manifest 缓存功能的完整测试方案和执行指南。

## 文档结构

```
WebBridgeKit/
├── MANIFEST_CACHE_TEST_PLAN.md      # 完整测试计划（10个章节）
├── TEST_EXECUTION_MANUAL.md         # 测试执行手册（详细步骤）
├── run_tests.sh                     # 测试执行脚本
└── test-server/                    # 测试数据服务器
    └── lazy-test/                  # Lazy 模式测试页面
        ├── manifest.json
        ├── index.html
        ├── style.css
        ├── script.js
        └── logo.svg
```

---

## 快速开始

### 一键启动测试环境

```bash
cd /Users/xuyingzhou/Project/temporary/WebBridgeKit
./run_tests.sh all
```

这将自动：
1. 检查依赖
2. 编译 Demo App
3. 启动测试服务器 (端口 8080)
4. 启动 iOS 模拟器
5. 安装并启动应用

### 手动分步执行

```bash
# 1. 启动测试服务器
cd test-server
python3 -m http.server 8080

# 2. 验证服务器
open http://localhost:8080/lazy-test/

# 3. 编译并运行应用（在 Xcode 中）
# 打开 WebBridgeKit.xcworkspace
# 选择 DemoApp scheme
# 运行到模拟器
```

---

## 文档导航

### 1. [MANIFEST_CACHE_TEST_PLAN.md](MANIFEST_CACHE_TEST_PLAN.md)
**完整的测试计划文档**

包含以下章节：
- 测试概述（目标、范围、环境）
- 测试用例设计（30+ 详细测试用例）
- 测试执行命令
- 测试数据准备
- 验证点清单
- 回归测试清单
- 测试报告模板
- 自动化测试建议
- 常见问题排查
- 测试完成标准

**适用人群：** 测试经理、开发人员、QA 工程师

### 2. [TEST_EXECUTION_MANUAL.md](TEST_EXECUTION_MANUAL.md)
**详细的测试执行手册**

包含以下内容：
- 快速开始指南
- 5 个阶段的详细测试步骤
- 每个测试用例的操作步骤和预期结果
- 日志验证命令
- 问题排查指南
- 测试结果记录表
- 回归测试清单
- 报告模板

**适用人群：** 测试执行人员、QA 工程师

### 3. [run_tests.sh](run_tests.sh)
**自动化测试执行脚本**

功能：
- 自动检查依赖（xcodebuild、xcrun）
- 编译 Demo App
- 启动 Python 测试服务器
- 启动 iOS 模拟器
- 安装并启动应用
- 显示测试分类指南
- 提供日志监控命令

使用方式：
```bash
# 执行所有测试
./run_tests.sh all

# 执行基础功能测试
./run_tests.sh basic

# 执行 Manifest 测试
./run_tests.sh manifest

# 执行显示模式测试
./run_tests.sh display
```

---

## 测试用例总览

### 核心功能测试（P0 优先级）

| 用例编号 | 测试名称 | 描述 |
|---------|---------|------|
| TC-UNI-001 | openBrowser() 基本功能 | 验证统一入口方法正常工作 |
| TC-UNI-002 | forceRefresh=false 正常缓存 | 验证缓存命中机制 |
| TC-UNI-003 | forceRefresh=true 绕过缓存 | 验证强制刷新功能 |
| TC-MAN-001 | Lazy 模式自动检测 | 验证懒加载模式 |
| TC-MAN-002 | Persistent 模式自动检测 | 验证持久化模式 |
| TC-MAN-003 | 缓存命中状态标签 | 验证状态标签显示 |
| TC-MAN-004 | forceRefresh 绕过缓存 | 验证 Manifest 级别强制刷新 |
| TC-DISP-001 | Normal 模式 | 验证标准显示模式 |
| TC-DISP-002 | Immersive 模式 | 验证全屏沉浸式模式 |

### 详细用例列表

完整用例列表请查看 [MANIFEST_CACHE_TEST_PLAN.md](MANIFEST_CACHE_TEST_PLAN.md) 第 2 节。

---

## 测试数据说明

### Lazy 模式测试页面

**位置：** `test-server/lazy-test/`

**文件说明：**
- `manifest.json` - Manifest 清单（persistent: false）
- `index.html` - 测试页面 HTML
- `style.css` - 样式文件
- `script.js` - JavaScript 脚本（包含 JS Bridge 检测）
- `logo.svg` - 应用图标

**测试 URL：** `http://localhost:8080/lazy-test/`

**预期行为：**
1. 立即下载并解析 manifest.json
2. 立即加载 HTML 显示页面
3. 后台异步下载所有资源
4. 资源请求被 `custom://` URL Scheme 拦截
5. 从缓存提供资源

### Persistent 模式测试页面

需要创建 `test-server/persistent-test/` 目录，包含：
- `manifest.json`（persistent: true）
- 完整的页面资源

**预期行为：**
1. 显示下载进度弹窗
2. 下载所有资源后显示页面
3. 完全离线可用

---

## 执行测试的 3 种方式

### 方式 1：使用自动化脚本（推荐）

```bash
./run_tests.sh all
```

**优点：** 一键启动所有环境，适合快速验证

### 方式 2：手动逐步执行

参考 [TEST_EXECUTION_MANUAL.md](TEST_EXECUTION_MANUAL.md) 中的详细步骤

**优点：** 可以精确控制每一步，适合详细测试

### 方式 3：在 Xcode 中调试

1. 打开 `WebBridgeKit.xcworkspace`
2. 选择 `DemoApp` scheme
3. 在代码中设置断点
4. 运行到模拟器或真机

**优点：** 可以调试代码，查看变量值

---

## 日志监控

### 实时查看所有日志

```bash
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"'
```

### 过滤 Manifest 缓存相关日志

```bash
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep -E '\[LazyLoader\]|\[ManifestCache\]|\[Browser\]'
```

### 查看缓存命中通知

```bash
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep 'manifest-cache'
```

---

## 验证点清单

### 功能验证
- [ ] openBrowser() 方法成功打开浏览器
- [ ] forceRefresh=false 时使用缓存
- [ ] forceRefresh=true 时重新下载
- [ ] animated 参数控制动画效果
- [ ] 自动检测 manifest.json
- [ ] Lazy 模式立即显示 HTML
- [ ] Persistent 模式显示进度弹窗
- [ ] 缓存命中时显示正确状态标签
- [ ] Normal 模式显示导航栏
- [ ] Immersive 模式全屏显示
- [ ] Modal 模式弹窗显示

### UI 验证
- [ ] TabBar 在进入浏览器时隐藏
- [ ] TabBar 在退出浏览器时恢复
- [ ] 导航栏显示/隐藏正确
- [ ] 状态栏显示/隐藏正确
- [ ] WebView 约束正确
- [ ] 关闭/后退按钮状态正确

### 日志验证
- [ ] 缓存命中时输出日志
- [ ] 缓存未命中时输出日志
- [ ] 强制刷新时输出日志
- [ ] 错误时有详细日志

---

## 回归测试清单

### 冒烟测试（每次修改后执行）

1. **基础功能**
   - [ ] 打开任意 URL
   - [ ] 关闭浏览器
   - [ ] 再次打开同一 URL（验证缓存）

2. **显示模式**
   - [ ] Normal 模式打开
   - [ ] Immersive 模式打开
   - [ ] Modal 模式打开

3. **强制刷新**
   - [ ] forceRefresh=false 打开
   - [ ] forceRefresh=true 打开

### 完整回归测试（每次发布前执行）

- [ ] TC-UNI-001 到 TC-UNI-004
- [ ] TC-MAN-001 到 TC-MAN-006
- [ ] TC-DISP-001 到 TC-DISP-006
- [ ] TC-PARAM-001 到 TC-PARAM-004

---

## 常见问题

### Q1: 测试服务器无法启动

**问题：** 端口 8080 被占用

**解决方案：**
```bash
# 查看占用进程
lsof -i :8080

# 更换端口
python3 -m http.server 8081
```

### Q2: 模拟器无法启动

**问题：** 模拟器服务未响应

**解决方案：**
```bash
# 重启模拟器服务
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService
```

### Q3: 缓存未命中

**问题：** 第二次访问仍然从网络加载

**排查步骤：**
1. 检查 manifest.json 路径是否正确
2. 确认 AppID 解析是否正确
3. 验证 URLSchemeHandler 是否正确注册
4. 查看控制台错误日志

---

## 测试报告模板

### 测试执行记录

| 用例编号 | 用例名称 | 执行结果 | 备注 |
|---------|---------|---------|------|
| TC-UNI-001 | openBrowser() 基本功能 | PASS / FAIL | |
| ... | ... | ... | |

### 缺陷报告

| 编号 | 严重程度 | 问题描述 | 复现步骤 |
|-----|---------|---------|---------|
| 1 | P0 / P1 / P2 | | |

---

## 下一步

1. **准备测试环境**
   ```bash
   cd /Users/xuyingzhou/Project/temporary/WebBridgeKit
   ./run_tests.sh all
   ```

2. **阅读测试执行手册**
   打开 `TEST_EXECUTION_MANUAL.md` 查看详细步骤

3. **执行测试并记录结果**
   使用提供的验证点清单和测试结果记录表

4. **生成测试报告**
   使用报告模板生成最终测试报告

---

## 联系和支持

如有问题或建议，请：
- 查看项目文档
- 查看代码注释
- 联系开发团队

---

**最后更新：** 2026-02-12
**版本：** 1.0.0
