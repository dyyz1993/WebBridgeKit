# 问题文件索引

本文档提供所有问题的快速索引，方便查找和修复。

---

## 严重问题文件索引

### 问题 1：单例模式过度使用
**涉及文件：**
- `Sources/Core/WebBrowserManager.swift` (第 17-19 行)
- `Sources/Cache/ManifestCacheManager.swift` (第 20-22 行)
- `Sources/Cache/WebCacheManager.swift` (第 17-19 行)
- `Sources/Cache/WebPageHistoryManager.swift` (第 16-18 行)
- `Sources/Cache/ManifestStore.swift` (第 13 行)
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 150 行)
- `DemoApp/Sources/Controllers/MainViewController.swift` (第 60, 280 行)

### 问题 2：线程安全问题
**涉及文件：**
- `Sources/Cache/ManifestStore.swift` (第 120-145, 30-35 行)
- `Sources/Cache/ResourceCache.swift` (ManifestStore.swift 第 250-290 行)

### 问题 3：Realm 跨线程访问
**涉及文件：**
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 145-200 行)
- `Sources/Cache/WebPageHistoryManager.swift` (第 50-60, 80-95 行)

### 问题 4：内存泄漏风险
**涉及文件：**
- `DemoApp/Sources/Controllers/MainViewController.swift` (第 70-80, 420-430 行)
- `Sources/Cache/ManifestStore.swift` (第 40-50, 120-145 行)
- `Sources/Cache/ResourceCache.swift` (ManifestStore.swift 第 260-290 行)
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 170, 200-220 行)

### 问题 5：缺少错误处理和恢复机制
**涉及文件：**
- `Sources/Cache/ManifestCacheManager.swift` (第 80-100 行)
- `Sources/Core/WebBrowserManager.swift` (第 150-180 行)

### 问题 6：缺少缓存过期策略
**涉及文件：**
- `Sources/Cache/ManifestStore.swift` (第 60-70 行)
- `Sources/Cache/ResourceCache.swift` (ManifestStore.swift 第 240-250 行)

### 问题 7：通知机制缺少类型安全
**涉及文件：**
- `Sources/Cache/ManifestStore.swift` (第 45, 75, 95 行)
- `Sources/Cache/ManifestCacheManager.swift` (第 120 行)
- `DemoApp/Sources/Controllers/MainViewController.swift` (第 70-90 行)

### 问题 8：缺少日志和监控系统
**涉及文件：**
- 所有文件中的 `print()` 和 `NSLog()` 调用
- 主要在：
  - `Sources/Cache/ManifestCacheManager.swift`
  - `Sources/Core/WebBrowserManager.swift`
  - `DemoApp/Sources/Controllers/MainViewController.swift`
  - `DemoApp/Sources/ViewModels/MainViewModel.swift`

---

## 中等问题文件索引

### 问题 1：主线程阻塞
**涉及文件：**
- `Sources/Cache/WebPageHistoryManager.swift` (第 120-145 行)
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 145-200 行)

### 问题 2：N+1 查询问题
**涉及文件：**
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 160-180 行)

### 问题 3：内存缓存无限制增长
**涉及文件：**
- `Sources/Cache/ResourceCache.swift` (ManifestStore.swift 第 200-300 行)

### 问题 4：频繁的磁盘 I/O 操作
**涉及文件：**
- `Sources/Cache/ManifestStore.swift` (第 40-50, 60-70 行)

### 问题 5：魔法数字和硬编码
**涉及文件：**
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 165, 167 行)
- `Sources/Cache/ResourceCache.swift` (第 210 行)
- `Sources/Cache/WebCacheManager.swift` (第 85 行)

### 问题 6：过长的方法和类
**涉及文件：**
- `DemoApp/Sources/Controllers/MainViewController.swift` (600+ 行)
- `DemoApp/Sources/ViewModels/MainViewModel.swift` (第 145-200 行 loadHistories 方法)

### 问题 7：缺少输入验证
**涉及文件：**
- `Sources/Core/WebBrowserManager.swift` (第 40-50 行)
- `Sources/Cache/ManifestCacheManager.swift` (第 60-70 行)

### 问题 8：错误处理不一致
**涉及文件：**
- 整个项目中混用了多种错误处理方式

### 问题 9：URL 注入风险
**涉及文件：**
- `DemoApp/Sources/Controllers/QRScannerViewController.swift` (第 150-160 行)
- `DemoApp/Sources/Controllers/MainViewController.swift` (第 100-120 行)

### 问题 10：敏感数据存储不安全
**涉及文件：**
- `DemoApp/Sources/Managers/APIKeyManager.swift` (第 30-40 行)

### 问题 11：缺少单元测试
**涉及文件：**
- `Tests/` 目录几乎为空
- 需要为所有核心类添加测试

### 问题 12：API 文档不完整
**涉及文件：**
- 所有公开 API 都缺少详细文档
- 特别是：
  - `Sources/Core/WebBrowserManager.swift`
  - `Sources/Cache/ManifestCacheManager.swift`
  - `Sources/Cache/WebPageHistoryManager.swift`

---

## 修复优先级

### 🔴 立即修复（1-2周）
1. ✅ 问题 3：Realm 跨线程访问（可能崩溃）
2. ✅ 问题 2：线程安全问题（可能死锁）
3. ✅ 问题 4：内存泄漏风险（内存增长）
4. ✅ 问题 9：URL 注入风险（安全问题）

### 🟡 近期修复（2-4周）
5. ✅ 问题 1：主线程阻塞（用户体验）
6. ✅ 问题 2：N+1 查询（性能问题）
7. ✅ 问题 5：缺少错误处理（稳定性）
8. ✅ 问题 6：缺少缓存过期策略（数据一致性）

### 🟢 长期改进（1-2月）
9. ✅ 问题 1：单例模式重构（可测试性）
10. ✅ 问题 6：代码重构（可维护性）
11. ✅ 问题 11：添加单元测试（质量保证）
12. ✅ 问题 8：实现日志系统（可调试性）

---

## 快速修复指南

### 对于每个问题：
1. 查看对应的详细文档（CRITICAL_ISSUES_DETAILED.md 或 MODERATE_ISSUES_DETAILED.md）
2. 找到涉及的文件和行号
3. 阅读问题描述和影响分析
4. 参考修复方案
5. 编写测试验证修复
6. 提交代码审查

### 建议的工作流程：
```bash
# 1. 创建修复分支
git checkout -b fix/issue-3-realm-thread-safety

# 2. 修复问题
# 编辑相关文件...

# 3. 运行测试
./scripts/run_tests.sh

# 4. 提交
git add .
git commit -m "Fix: Realm 跨线程访问问题 (#3)"

# 5. 推送并创建 PR
git push origin fix/issue-3-realm-thread-safety
```

---

**文档版本：** 1.0  
**创建日期：** 2026-02-09  
**维护者：** WebBridgeKit Team
