# WebBridgeKit Manifest 缓存功能测试方案

## 1. 测试概述

### 1.1 测试目标
验证重构后的统一入口和 Manifest 缓存功能是否正常工作，包括：
- 统一入口 `openBrowser()` 方法的正确性
- Manifest 缓存的自动检测和加载
- 三种显示模式（Normal/Immersive/Modal）的正确展示
- 缓存命中时的状态标签显示
- `forceRefresh` 参数绕过缓存的功能

### 1.2 测试范围
| 测试类别 | 测试项 | 优先级 |
|---------|--------|--------|
| 统一入口验证 | openBrowser() 方法调用 | P0 |
| 统一入口验证 | forceRefresh 参数 | P0 |
| 统一入口验证 | animated 参数 | P1 |
| Manifest 缓存 | 自动检测 manifest.json | P0 |
| Manifest 缓存 | 缓存命中状态标签 | P0 |
| Manifest 缓存 | forceRefresh 绕过缓存 | P0 |
| 显示模式 | Normal 模式 | P0 |
| 显示模式 | Immersive 模式 | P0 |
| 显示模式 | Modal 模式 | P1 |

### 1.3 测试环境
- **项目路径**: `/Users/xuyingzhou/Project/temporary/WebBridgeKit`
- **Demo App**: `DemoApp`
- **测试设备**: iOS 模拟器或真机（iOS 14.0+）
- **网络环境**: 需要能够访问外部测试服务器

---

## 2. 测试用例设计

### 2.1 统一入口验证测试

#### TC-UNI-001: openBrowser() 基本功能
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 WebBrowserManager.openBrowser() 方法能够正确打开浏览器 |
| **前置条件** | Demo App 已启动，在主界面 |
| **测试步骤** | 1. 在 MainViewController 中点击任意 URL 测试按钮<br>2. 观察 WebView 是否正确加载<br>3. 检查导航栏是否正常显示 |
| **预期结果** | - WebView 成功加载目标 URL<br>- 导航栏正确显示标题<br>- TabBar 正确隐藏<br>- 关闭按钮可点击 |
| **验证点** | - URL 正确加载<br>- UI 状态正确<br>- 无控制台错误 |
| **优先级** | P0 |

#### TC-UNI-002: forceRefresh=false 正常缓存
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 forceRefresh=false 时使用缓存（如果存在） |
| **前置条件** | 已访问过测试 URL，缓存已建立 |
| **测试步骤** | 1. 第一次打开测试 URL（建立缓存）<br>2. 关闭浏览器<br>3. 再次打开同一 URL，forceRefresh=false<br>4. 观察缓存状态标签 |
| **预期结果** | - 第二次打开时缓存命中<br>- 缓存状态标签显示 "INTERCEPT" 或 "MANIFEST"<br>- 页面加载速度更快 |
| **验证点** | - 缓存命中通知发送<br>- 状态标签颜色正确<br>- 控制台有缓存命中日志 |
| **优先级** | P0 |

#### TC-UNI-003: forceRefresh=true 绕过缓存
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 forceRefresh=true 时绕过缓存，强制重新下载 |
| **前置条件** | 已访问过测试 URL，缓存已建立 |
| **测试步骤** | 1. 第一次打开测试 URL（建立缓存）<br>2. 关闭浏览器<br>3. 再次打开同一 URL，forceRefresh=true<br>4. 观察缓存状态标签 |
| **预期结果** | - 重新下载 manifest.json<br>- 重新下载 HTML 内容<br>- 缓存状态标签先显示 "CHECKING" 后显示来源<br>- 最终显示 "LIVE" 或新的缓存来源 |
| **验证点** | - 强制刷新日志输出<br>- 缓存被清除并重建<br>- 版本变化时正确更新 |
| **优先级** | P0 |

#### TC-UNI-004: animated 参数控制动画
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 animated 参数控制页面切换动画 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 调用 openBrowser(url, animated: false)<br>2. 观察页面切换是否有动画<br>3. 调用 openBrowser(url, animated: true)<br>4. 观察页面切换是否有动画 |
| **预期结果** | - animated=false 时无动画，页面立即出现<br>- animated=true 时有标准 push 动画 |
| **验证点** | - 动画效果符合参数值 |
| **优先级** | P1 |

---

### 2.2 Manifest 缓存验证测试

#### TC-MAN-001: 自动检测 manifest.json（Lazy 模式）
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 Normal/Immersive 模式自动检测并使用 manifest.json（persistent=false） |
| **前置条件** | 测试服务器已部署 manifest.json（persistent=false） |
| **测试步骤** | 1. 准备测试 URL，确保存在 manifest.json<br>2. 使用 Normal 模式打开 URL<br>3. 观察控制台日志<br>4. 检查页面是否立即显示 |
| **预期结果** | - 自动下载 manifest.json<br>- 日志显示 "选择懒加载模式"<br>- HTML 立即加载显示<br>- 资源在后台下载 |
| **验证点** | - manifest.json 成功下载<br>- 资源映射正确建立<br>- 资源请求被 custom:// 拦截<br>- 控制台有懒加载日志 |
| **优先级** | P0 |

#### TC-MAN-002: 自动检测 manifest.json（Persistent 模式）
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证自动检测并使用 manifest.json（persistent=true） |
| **前置条件** | 测试服务器已部署 manifest.json（persistent=true） |
| **测试步骤** | 1. 准备测试 URL，manifest.json 中 persistent=true<br>2. 打开 URL<br>3. 观察是否显示进度弹窗<br>4. 等待下载完成 |
| **预期结果** | - 显示下载进度弹窗<br>- 下载所有资源后显示页面<br>- 页面完全离线可用 |
| **验证点** | - 进度弹窗正确显示<br>- 所有资源成功下载<br>- 页面正常显示<br>- 离线状态下可访问 |
| **优先级** | P0 |

#### TC-MAN-003: 缓存命中状态标签
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证缓存命中时导航栏显示正确的状态标签 |
| **前置条件** | 已建立缓存，再次打开同一页面 |
| **测试步骤** | 1. 打开已缓存的页面<br>2. 观察导航栏标题旁的状态标签<br>3. 检查标签颜色和文本 |
| **预期结果** | - 状态标签显示 "INTERCEPT"（懒加载）或 "MANIFEST"（持久化）<br>- 标签背景色：绿色（INTERCEPT）或蓝色（MANIFEST）<br>- 标签清晰可见 |
| **验证点** | - 状态标签文本正确<br>- 状态标签颜色正确<br>- 状态标签位置正确（标题右侧） |
| **优先级** | P0 |

#### TC-MAN-004: forceRefresh=true 绕过缓存
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 forceRefresh=true 时清除旧缓存并重新下载 |
| **前置条件** | 已建立缓存 |
| **测试步骤** | 1. 修改服务器端 manifest.json 版本号<br>2. 使用 forceRefresh=true 打开页面<br>3. 观察是否重新下载<br>4. 检查缓存是否更新 |
| **预期结果** | - 清除旧缓存<br>- 重新下载 manifest.json<br>- 使用新的版本号<br>- 页面使用最新内容 |
| **验证点** | - 版本号正确更新<br>- 旧缓存被清除<br>- 控制台有强制刷新日志<br>- 页面内容是最新的 |
| **优先级** | P0 |

#### TC-MAN-005: manifest.json 不存在时回退
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 manifest.json 不存在时正确回退到普通加载 |
| **前置条件** | 测试 URL 没有 manifest.json |
| **测试步骤** | 1. 打开没有 manifest.json 的 URL<br>2. 观察控制台日志<br>3. 检查页面是否正常加载 |
| **预期结果** | - 回退到普通 WebView 加载<br>- 控制台输出 "未找到 manifest.json"<br>- 页面正常显示<br>- 状态标签显示 "LIVE" |
| **验证点** | - 回退逻辑正确执行<br>- 页面正常加载<br>- 无崩溃或错误 |
| **优先级** | P0 |

#### TC-MAN-006: 资源下载失败处理
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证资源下载失败时的错误处理 |
| **前置条件** | manifest.json 中有无效的资源 URL |
| **测试步骤** | 1. 准备包含无效资源 URL 的 manifest.json<br>2. 打开页面<br>3. 观察错误处理 |
| **预期结果** | - 显示友好的错误提示<br>- 不影响页面其他部分<br>- 控制台有详细错误日志 |
| **验证点** | - 错误提示清晰<br>- 无崩溃<br>- 错误日志完整 |
| **优先级** | P1 |

---

### 2.3 三种显示模式测试

#### TC-DISP-001: Normal 模式
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 Normal 模式下的页面显示 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 创建 WebBrowserParams，displayMode=.normal<br>2. 调用 openBrowser()<br>3. 观察 UI 状态 |
| **预期结果** | - 导航栏显示<br>- TabBar 隐藏<br>- 状态栏显示<br>- WebView 内容从导航栏下方开始<br>- 可以后退 |
| **验证点** | - 导航栏可见<br>- TabBar 不可见<br>- WebView 约束正确<br>- 后退按钮在有历史时显示 |
| **优先级** | P0 |

#### TC-DISP-002: Immersive 模式
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 Immersive 模式下的全屏沉浸式显示 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 创建 WebBrowserParams，displayMode=.immersive<br>2. 调用 openBrowser()<br>3. 观察 UI 状态 |
| **预期结果** | - 导航栏隐藏<br>- TabBar 隐藏<br>- 状态栏隐藏（如果配置）<br>- WebView 占满整个屏幕<br>- 点击底部区域可关闭 |
| **验证点** | - 完全全屏显示<br>- 无系统 UI 干扰<br>- 手势关闭功能正常 |
| **优先级** | P0 |

#### TC-DISP-003: Modal 模式
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 Modal 模式下的弹窗显示 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 创建 WebBrowserParams，displayMode=.modal<br>2. 调用 openBrowser()<br>3. 观察弹窗效果 |
| **预期结果** | - 以弹窗形式显示<br>- 背景有半透明遮罩<br>- 可以向下滑动关闭<br>- 弹窗大小正确 |
| **验证点** | - 弹窗动画正确<br>- 大小符合配置<br>- 关闭手势可用<br>- 背景页不可交互 |
| **优先级** | P1 |

#### TC-DISP-004: hideNavigationBar 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 hideNavigationBar 参数控制导航栏显示 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 创建 params，hideNavigationBar=true<br>2. 打开 Normal 模式页面<br>3. 观察导航栏 |
| **预期结果** | - 导航栏隐藏<br>- WebView 占满屏幕（除状态栏）<br>- 其他功能正常 |
| **验证点** | - 导航栏不可见<br>- WebView 约束更新<br>- 页面可正常交互 |
| **优先级** | P0 |

#### TC-DISP-005: hideStatusBar 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 hideStatusBar 参数控制状态栏显示 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 创建 params，hideStatusBar=true<br>2. 打开页面<br>3. 观察状态栏 |
| **预期结果** | - 状态栏隐藏<br>- 页面占满屏幕顶部<br>- 其他功能正常 |
| **验证点** | - 状态栏不可见<br>- 系统时间不显示<br>- 页面布局正确 |
| **优先级** | P1 |

#### TC-DISP-006: disableSwipeBack 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 disableSwipeBack 参数禁用侧滑返回 |
| **前置条件** | 页面在导航栈中，可以后退 |
| **测试步骤** | 1. 创建 params，disableSwipeBack=true<br>2. 打开页面<br>3. 尝试侧滑手势 |
| **预期结果** | - 侧滑手势无响应<br>- 只能通过关闭按钮返回<br>- 其他手势正常 |
| **验证点** | - 侧滑不触发<br>- 关闭按钮正常工作<br>- 用户体验符合预期 |
| **优先级** | P1 |

---

### 2.4 URL 参数测试

#### TC-PARAM-001: hideNavBar URL 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 URL 参数 ?hideNavBar=1 隐藏导航栏 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 打开 URL：https://example.com?hideNavBar=1<br>2. 观察导航栏 |
| **预期结果** | - 导航栏隐藏<br>- WebView 全屏显示 |
| **验证点** | - 参数解析正确<br>- UI 正确更新 |
| **优先级** | P1 |

#### TC-PARAM-002: hideStatusBar URL 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 URL 参数 ?hideStatusBar=1 隐藏状态栏 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 打开 URL：https://example.com?hideStatusBar=1<br>2. 观察状态栏 |
| **预期结果** | - 状态栏隐藏 |
| **验证点** | - 参数解析正确<br>- 状态栏正确隐藏 |
| **优先级** | P1 |

#### TC-PARAM-003: mode=immersive URL 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 URL 参数 ?mode=immersive 激活沉浸模式 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 打开 URL：https://example.com?mode=immersive<br>2. 观察 UI |
| **预期结果** | - 导航栏隐藏<br>- 状态栏隐藏<br>- 完全全屏 |
| **验证点** | - 参数解析正确<br>- 沉浸模式正确激活 |
| **优先级** | P0 |

#### TC-PARAM-004: orientation URL 参数
| 项目 | 内容 |
|-----|------|
| **测试描述** | 验证 URL 参数 ?orientation=landscape 强制横屏 |
| **前置条件** | Demo App 已启动 |
| **测试步骤** | 1. 打开 URL：https://example.com?orientation=landscape<br>2. 观察屏幕方向 |
| **预期结果** | - 屏幕旋转到横屏<br>- 页面横屏显示 |
| **验证点** | - 参数解析正确<br>- 屏幕方向正确 |
| **优先级** | P1 |

---

## 3. 测试执行命令

### 3.1 编译项目
```bash
# 进入项目目录
cd /Users/xuyingzhou/Project/temporary/WebBridgeKit

# 更新依赖
pod update

# 编译 Demo App
xcodebuild -workspace WebBridgeKit.xcworkspace \
           -scheme DemoApp \
           -configuration Debug \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           clean build
```

### 3.2 运行测试
```bash
# 使用模拟器运行
xcrun simctl boot "iPhone 15"

# 安装应用
xcrun simctl install "iPhone 15" \
    ~/Library/Developer/Xcode/DerivedData/WebBridgeKit-*/Build/Products/Debug-iphonesimulator/DemoApp.app

# 启动应用
xcrun simctl launch "iPhone 15" com.webbridgekit.demo
```

### 3.3 查看实时日志
```bash
# 过滤 Manifest 缓存相关日志
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep -E '\[LazyLoader\]|\[ManifestCache\]|\[Browser\]'

# 过滤缓存命中通知
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep 'manifest-cache.hit'
```

---

## 4. 测试数据准备

### 4.1 测试服务器结构
创建测试服务器目录结构：
```
test-server/
├── lazy-test/
│   ├── index.html
│   ├── manifest.json  (persistent: false)
│   ├── logo.png
│   └── style.css
├── persistent-test/
│   ├── index.html
│   ├── manifest.json  (persistent: true)
│   └── assets/
├── no-manifest-test/
│   └── index.html
└── invalid-manifest-test/
    ├── index.html
    └── manifest.json  (包含无效资源 URL)
```

### 4.2 manifest.json 示例（Lazy 模式）
```json
{
  "persistent": false,
  "version": "1.0.0",
  "resources": {
    "logo.png": "http://localhost:8080/lazy-test/logo.png",
    "style.css": "http://localhost:8080/lazy-test/style.css"
  }
}
```

### 4.3 manifest.json 示例（Persistent 模式）
```json
{
  "persistent": true,
  "version": "1.0.0",
  "appid": "com.test.persistent",
  "name": "Persistent Test App",
  "icon": "http://localhost:8080/persistent-test/icon.png",
  "resources": {
    "assets/logo.png": "http://localhost:8080/persistent-test/assets/logo.png",
    "assets/style.css": "http://localhost:8080/persistent-test/assets/style.css"
  }
}
```

### 4.4 本地测试 HTML 文件
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Manifest Test Page</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Manifest Cache Test</h1>
    <img src="logo.png" alt="Logo">
    <div id="status">Testing...</div>
    <script>
        document.getElementById('status').textContent = 'Page loaded at ' + new Date().toLocaleTimeString();

        // 检测是否在缓存环境
        if (window.webkit && window.webkit.messageHandlers) {
            document.getElementById('status').textContent += ' | JS Bridge available';
        }
    </script>
</body>
</html>
```

---

## 5. 验证点清单

### 5.1 功能验证
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
- [ ] URL 参数正确解析和应用

### 5.2 UI 验证
- [ ] TabBar 在进入浏览器时隐藏
- [ ] TabBar 在退出浏览器时恢复
- [ ] 导航栏显示/隐藏正确
- [ ] 状态栏显示/隐藏正确
- [ ] WebView 约束正确
- [ ] 关闭/后退按钮状态正确

### 5.3 日志验证
- [ ] 缓存命中时输出日志
- [ ] 缓存未命中时输出日志
- [ ] 强制刷新时输出日志
- [ ] 错误时有详细日志
- [ ] 性能日志完整

### 5.4 性能验证
- [ ] 缓存命中时加载更快
- [ ] Lazy 模式 HTML 立即显示
- [ ] Persistent 模式所有资源下载完成
- [ ] 内存占用正常
- [ ] 无内存泄漏

---

## 6. 回归测试清单

### 6.1 冒烟测试（Smoke Tests）
每次修改后必须运行的快速验证：

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

### 6.2 完整回归测试
每次发布前必须执行：

- [ ] TC-UNI-001 到 TC-UNI-004
- [ ] TC-MAN-001 到 TC-MAN-006
- [ ] TC-DISP-001 到 TC-DISP-006
- [ ] TC-PARAM-001 到 TC-PARAM-004

### 6.3 边界条件测试
- [ ] manifest.json 为空
- [ ] manifest.json 格式错误
- [ ] 网络断开时访问
- [ ] 极大 manifest.json
- [ ] 特殊字符在资源路径中

---

## 7. 测试报告模板

### 7.1 测试执行记录
```
测试日期：YYYY-MM-DD
测试人员：
测试版本：
设备信息：

测试用例执行记录：
| 用例编号 | 用例名称 | 执行结果 | 备注 |
|---------|---------|---------|------|
| TC-UNI-001 | openBrowser() 基本功能 | PASS/FAIL | |
| ... | ... | ... | |

问题列表：
| 编号 | 严重程度 | 问题描述 | 复现步骤 |
|-----|---------|---------|---------|
| 1 | P0/P1/P2 | | |

总结：
- 总用例数：XX
- 通过：XX
- 失败：XX
- 通过率：XX%
```

---

## 8. 自动化测试建议

### 8.1 XCUITest 测试结构
```swift
// ManifestCacheUITests.swift
func testOpenBrowserWithCache() {
    let app = XCUIApplication()
    app.launch()

    // 测试基础打开功能
    app.buttons["OpenBrowser"].tap()
    XCTAssertTrue(app.webViews.firstMatch.exists)
}

func testForceRefreshParameter() {
    // 测试强制刷新参数
    // ...
}
```

### 8.2 单元测试建议
```swift
// ManifestCacheManagerTests.swift
func testManifestCacheHit() {
    // 测试缓存命中逻辑
}

func testVersionComparison() {
    // 测试版本比较
}
```

---

## 9. 常见问题排查

### 9.1 缓存未命中
- 检查 manifest.json 路径是否正确
- 确认 AppID 解析是否正确
- 验证 URLSchemeHandler 是否正确注册

### 9.2 状态标签不更新
- 检查通知是否正确发送
- 验证主线程更新 UI
- 确认 updateCacheStatus 被调用

### 9.3 强制刷新不生效
- 确认 forceRefresh 参数正确传递
- 检查缓存清除逻辑
- 验证重新下载流程

---

## 10. 测试完成标准

### 10.1 测试通过标准
- 所有 P0 用例 100% 通过
- P1 用例至少 95% 通过
- 无 P0 阻塞性问题

### 10.2 上线标准
- 所有冒烟测试通过
- 无内存泄漏
- 无崩溃问题
- 性能指标符合要求
