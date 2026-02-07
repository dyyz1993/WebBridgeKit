# WebBridgeKit E2E Tests

End-to-end tests for WebBridgeKit using Vitest and @playwright/test.

## 测试框架配置

### 核心配置

- **并发限制**: `workers: 3` - 最多同时创建3个浏览器实例
- **运行模式**: `headless: true` - 强制启用无头浏览器模式
- **超时设置**: 单个测试 60 秒，钩子 60 秒

### 钩子用法

#### 全局级别 (所有测试共享)

- **启动**: `global-setup.ts` - 启动测试服务器 (端口 8080)
- **关闭**: `global-teardown.ts` - 通过端口号 kill 进程

#### 套件级别 (单个测试文件内共享)

- **启动**: `beforeAll()` - 安装并启动 DemoApp
- **关闭**: `afterAll()` - 终止 DemoApp

## 安装依赖

```bash
npm install
```

## 运行测试

### 运行所有 E2E 测试

```bash
npm run test:e2e
```

### 运行 Manifest Cache 测试

```bash
npm run test:manifest
```

### 使用 UI 模式运行测试

```bash
npm run test:e2e:ui
```

## 测试文件

### manifest-cache.spec.ts

测试 Manifest 缓存功能的核心场景：

1. **服务器验证** - 验证测试服务器和 manifest 文件可访问
2. **页面加载** - 验证 HTML 页面可以正常加载
3. **资源拦截** - 验证相对路径资源被正确拦截和加载
4. **控制台日志** - 验证 JavaScript 控制台日志输出
5. **缓存命中** - 验证资源被缓存后第二次加载使用缓存
6. **URL 映射** - 验证从 manifest.json 查找真实 URL
7. **错误处理** - 验证资源加载失败时的错误处理
8. **响应式设计** - 验证在不同视口大小下的表现
9. **性能测试** - 验证页面加载时间在可接受范围内
10. **网络错误** - 验证没有 404 或其他网络错误

## 测试资源

- **测试页面**: `/test_resources/manifest_test.html`
- **Manifest**: `/test_resources/manifest.json`
- **测试服务器**: `/scripts/test_server.py`

## 应用配置

- **模拟器 ID**: `21045190-6163-49E0-82AD-9E4CFD5E3C55` (iPhone 15)
- **Bundle ID**: `com.yourcompany.WebBridgeKitDemo`

## 故障排查

### 测试服务器无法启动

```bash
# 检查端口 8080 是否被占用
lsof -ti:8080

# 如果被占用，kill 进程
kill -9 $(lsof -ti:8080)
```

### 模拟器未运行

```bash
# 启动模拟器
xcrun simctl boot "iPhone 15"

# 打开模拟器应用
open -a Simulator
```

### 应用未安装

```bash
# 构建应用
xcodebuild -scheme DemoApp -sdk iphonesimulator -configuration Debug

# 检查构建产物
ls -la build/Build/Products/Debug-iphonesimulator/
```
