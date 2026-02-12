# WebBridgeKit Manifest 缓存功能测试执行手册

## 快速开始

### 1. 一键执行所有测试
```bash
cd /Users/xuyingzhou/Project/temporary/WebBridgeKit
./run_tests.sh all
```

### 2. 执行特定测试类别
```bash
# 只执行基础功能测试
./run_tests.sh basic

# 只执行 Manifest 缓存测试
./run_tests.sh manifest

# 只执行显示模式测试
./run_tests.sh display
```

---

## 详细测试步骤

### 第一阶段：环境准备

#### 步骤 1.1：验证依赖
```bash
# 检查 Xcode 是否安装
xcodebuild -version

# 检查模拟器是否可用
xcrun simctl list devices

# 检查 Python3 是否可用（用于测试服务器）
python3 --version
```

#### 步骤 1.2：启动测试服务器
```bash
# 方式一：使用脚本自动启动（推荐）
./run_tests.sh all

# 方式二：手动启动
cd test-server
python3 -m http.server 8080
```

验证测试服务器：
```bash
# 在浏览器访问测试页面
open http://localhost:8080/lazy-test/
```

#### 步骤 1.3：准备测试模拟器
```bash
# 列出可用模拟器
xcrun simctl list devices

# 启动 iPhone 15 模拟器
xcrun simctl boot "iPhone 15"

# 或者使用脚本自动启动
./run_tests.sh all
```

---

### 第二阶段：统一入口测试 (TC-UNI)

#### TC-UNI-001: openBrowser() 基本功能
**操作步骤：**
1. 在 Demo App 主界面，找到"测试用例"入口
2. 点击任意 URL 测试按钮
3. 观察 WebView 是否正确加载

**预期结果：**
- [ ] WebView 成功加载目标 URL
- [ ] 导航栏正确显示标题
- [ ] TabBar 正确隐藏
- [ ] 关闭按钮可点击

**日志验证：**
```bash
# 监控控制台日志
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep 'WebBrowserManager'
```

**验证点：**
- [ ] 日志输出 `=== WebBrowserManager.openBrowser ===`
- [ ] 无错误日志输出

---

#### TC-UNI-002: forceRefresh=false 缓存命中
**操作步骤：**
1. 打开测试 URL：`http://localhost:8080/lazy-test/`
2. 关闭浏览器（返回上一页）
3. 再次打开同一 URL（forceRefresh 默认为 false）

**预期结果：**
- [ ] 第二次打开时缓存命中
- [ ] 缓存状态标签显示 "INTERCEPT"
- [ ] 页面加载速度明显更快

**日志验证：**
```bash
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep -E 'cache|Cache'
```

**验证点：**
- [ ] 日志输出 `[LazyLoader] 缓存命中`
- [ ] 状态标签背景为绿色

---

#### TC-UNI-003: forceRefresh=true 绕过缓存
**操作步骤：**
1. 确保已建立缓存（先访问一次页面）
2. 使用代码或测试工具调用：
   ```swift
   WebBrowserManager.shared.openBrowser(
       url: testURL,
       forceRefresh: true,
       from: self,
       animated: true
   )
   ```
3. 观察是否重新下载

**预期结果：**
- [ ] 清除旧缓存
- [ ] 重新下载 manifest.json
- [ ] 使用新的内容

**日志验证：**
```bash
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep 'forceRefresh'
```

**验证点：**
- [ ] 日志输出 `🔄 [强制刷新] 绕过缓存，重新下载所有内容`
- [ ] 缓存被清除

---

#### TC-UNI-004: animated 参数控制动画
**操作步骤：**
1. 在测试代码中分别调用：
   ```swift
   // 无动画
   openBrowser(url: testURL, animated: false)

   // 有动画
   openBrowser(url: testURL, animated: true)
   ```

**预期结果：**
- [ ] animated=false 时页面立即出现
- [ ] animated=true 时有标准 push 动画

---

### 第三阶段：Manifest 缓存测试 (TC-MAN)

#### TC-MAN-001: Lazy 模式自动检测
**测试 URL：** `http://localhost:8080/lazy-test/`

**操作步骤：**
1. 在 Demo App 中打开测试 URL
2. 观察页面加载过程
3. 检查控制台日志

**预期结果：**
- [ ] 自动下载 manifest.json
- [ ] HTML 立即加载显示
- [ ] 资源在后台下载

**日志验证：**
```bash
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep 'LazyLoader'
```

**验证点：**
- [ ] 日志显示 `[智能加载] 选择懒加载模式`
- [ ] 页面立即显示（不等资源下载完成）

---

#### TC-MAN-002: Persistent 模式自动检测
**测试 URL：** `http://localhost:8080/persistent-test/` (需创建)

**操作步骤：**
1. 确保 manifest.json 中 `persistent: true`
2. 打开测试 URL
3. 观察是否显示进度弹窗

**预期结果：**
- [ ] 显示下载进度弹窗
- [ ] 下载所有资源后显示页面
- [ ] 页面完全离线可用

**验证点：**
- [ ] 进度弹窗正确显示
- [ ] 进度百分比实时更新

---

#### TC-MAN-003: 缓存命中状态标签
**操作步骤：**
1. 第一次打开测试页面（建立缓存）
2. 关闭页面
3. 第二次打开同一页面
4. 观察导航栏标题旁的状态标签

**预期结果：**
- [ ] 状态标签显示 "INTERCEPT"（绿色）
- [ ] 或显示 "MANIFEST"（蓝色）
- [ ] 标签位置在标题右侧

**验证点：**
- [ ] 状态标签文本正确
- [ ] 状态标签颜色正确

---

#### TC-MAN-004: forceRefresh 绕过缓存
**操作步骤：**
1. 修改服务器端 manifest.json 版本号
2. 使用 forceRefresh=true 打开页面
3. 检查版本是否更新

**预期结果：**
- [ ] 版本号更新为最新
- [ ] 旧缓存被清除
- [ ] 页面使用新内容

---

#### TC-MAN-005: manifest.json 不存在回退
**操作步骤：**
1. 打开没有 manifest.json 的 URL
2. 观察回退行为

**预期结果：**
- [ ] 回退到普通 WebView 加载
- [ ] 控制台输出警告日志
- [ ] 页面正常显示
- [ ] 状态标签显示 "LIVE"

---

### 第四阶段：显示模式测试 (TC-DISP)

#### TC-DISP-001: Normal 模式
**操作步骤：**
1. 创建 Normal 模式参数
2. 调用 openBrowser()
3. 观察 UI

**预期结果：**
- [ ] 导航栏显示
- [ ] TabBar 隐藏
- [ ] 状态栏显示
- [ ] 可以后退

---

#### TC-DISP-002: Immersive 模式
**操作步骤：**
1. 创建 Immersive 模式参数
2. 调用 openBrowser()
3. 观察 UI

**预期结果：**
- [ ] 导航栏隐藏
- [ ] TabBar 隐藏
- [ ] 状态栏隐藏
- [ ] WebView 占满整个屏幕
- [ ] 点击底部区域可关闭

---

#### TC-DISP-003: Modal 模式
**操作步骤：**
1. 创建 Modal 模式参数
2. 调用 openBrowser()
3. 观察弹窗效果

**预期结果：**
- [ ] 以弹窗形式显示
- [ ] 背景有半透明遮罩
- [ ] 可以向下滑动关闭
- [ ] 弹窗大小正确

---

### 第五阶段：URL 参数测试 (TC-PARAM)

#### TC-PARAM-001: hideNavBar 参数
**测试 URL：** `http://localhost:8080/lazy-test/?hideNavBar=1`

**验证点：**
- [ ] 导航栏隐藏
- [ ] WebView 全屏显示

---

#### TC-PARAM-002: hideStatusBar 参数
**测试 URL：** `http://localhost:8080/lazy-test/?hideStatusBar=1`

**验证点：**
- [ ] 状态栏隐藏

---

#### TC-PARAM-003: mode=immersive 参数
**测试 URL：** `http://localhost:8080/lazy-test/?mode=immersive`

**验证点：**
- [ ] 激活沉浸模式
- [ ] 完全全屏显示

---

## 测试结果记录

### 测试执行记录表

| 用例编号 | 用例名称 | 执行结果 | 执行日期 | 备注 |
|---------|---------|---------|---------|------|
| TC-UNI-001 | openBrowser() 基本功能 | ⬜ PASS / ⬜ FAIL | | |
| TC-UNI-002 | forceRefresh=false 缓存命中 | ⬜ PASS / ⬜ FAIL | | |
| TC-UNI-003 | forceRefresh=true 绕过缓存 | ⬜ PASS / ⬜ FAIL | | |
| TC-UNI-004 | animated 参数控制动画 | ⬜ PASS / ⬜ FAIL | | |
| TC-MAN-001 | Lazy 模式自动检测 | ⬜ PASS / ⬜ FAIL | | |
| TC-MAN-002 | Persistent 模式自动检测 | ⬜ PASS / ⬜ FAIL | | |
| TC-MAN-003 | 缓存命中状态标签 | ⬜ PASS / ⬜ FAIL | | |
| TC-MAN-004 | forceRefresh 绕过缓存 | ⬜ PASS / ⬜ FAIL | | |
| TC-MAN-005 | manifest.json 不存在回退 | ⬜ PASS / ⬜ FAIL | | |
| TC-DISP-001 | Normal 模式 | ⬜ PASS / ⬜ FAIL | | |
| TC-DISP-002 | Immersive 模式 | ⬜ PASS / ⬜ FAIL | | |
| TC-DISP-003 | Modal 模式 | ⬜ PASS / ⬜ FAIL | | |

---

## 常见问题排查

### 问题 1：测试服务器无法启动
**症状：** 访问 localhost:8080 显示连接错误

**解决方案：**
```bash
# 检查端口占用
lsof -i :8080

# 更换端口
python3 -m http.server 8081

# 或者杀掉占用进程
kill -9 <PID>
```

### 问题 2：模拟器无法启动
**症状：** xcrun simctl boot 命令失败

**解决方案：**
```bash
# 重启模拟器服务
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService

# 重置模拟器
xcrun simctl shutdown all
xcrun simctl erase all
```

### 问题 3：缓存未命中
**症状：** 第二次访问仍然从网络加载

**解决方案：**
1. 检查 manifest.json 路径是否正确
2. 确认 URLSchemeHandler 已正确注册
3. 验证 AppID 解析是否正确
4. 检查缓存是否被清除

### 问题 4：状态标签不更新
**症状：** 缓存命中但标签仍显示 "LIVE"

**解决方案：**
1. 检查通知是否正确发送
2. 验证主线程更新 UI
3. 确认 updateCacheStatus 被调用
4. 检查通知监听器是否正确注册

---

## 回归测试清单

### 每次代码提交后执行

- [ ] TC-UNI-001: openBrowser() 基本功能
- [ ] TC-MAN-001: Lazy 模式自动检测
- [ ] TC-MAN-003: 缓存命中状态标签
- [ ] TC-DISP-001: Normal 模式
- [ ] TC-DISP-002: Immersive 模式

### 每次发布前执行

- [ ] 所有 P0 优先级测试用例
- [ ] 所有冒烟测试
- [ ] 内存泄漏检测
- [ ] 性能基准测试

---

## 附录：测试数据创建

### 创建 Persistent 测试页面
```bash
# 创建目录
mkdir -p test-server/persistent-test/assets

# 创建 manifest.json
cat > test-server/persistent-test/manifest.json << 'EOF'
{
  "persistent": true,
  "version": "1.0.0",
  "appid": "com.webbridgekit.test.persistent",
  "name": "Persistent Test App",
  "resources": {
    "assets/logo.png": "assets/logo.png",
    "assets/style.css": "assets/style.css"
  }
}
EOF
```

---

## 报告模板

### 测试总结报告

```
==================================================
WebBridgeKit Manifest Cache 测试报告
==================================================

测试日期：_____________________
测试人员：_____________________
测试版本：_____________________
设备信息：_________________

一、测试执行情况
--------------------------------------------------
总用例数：_____
执行数量：_____
通过数量：_____
失败数量：_____
通过率：_____%

二、用例执行明细
--------------------------------------------------
[见测试执行记录表]

三、缺陷列表
--------------------------------------------------
| 编号 | 严重程度 | 问题描述 | 复现步骤 |
|-----|---------|---------|---------|
| 1 | P0/P1/P2 | | |
| ... | ... | | |

四、性能指标
--------------------------------------------------
平均首次加载时间：_____ms
平均缓存命中时间：_____ms
缓存命中率：_____%

五、测试结论
--------------------------------------------------
□ 通过，可以发布
□ 条件通过，需修复低优先级问题
□ 不通过，需阻塞修复

六、签名
--------------------------------------------------
测试人员签名：_________________

日期：_____________________
```

---

## 快速参考命令

### 查看实时日志
```bash
# 所有日志
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"'

# 只看 Manifest 相关
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep -i manifest

# 只看缓存相关
xcrun simctl spawn "iPhone 15" log stream --predicate 'process == "DemoApp"' | grep -i cache
```

### 清除缓存
```bash
# 清除模拟器缓存
xcrun simctl shutdown all
xcrun simctl erase all

# 重置应用数据
xcrun simctl uninstall "iPhone 15" com.webbridgekit.demo
```

### 截图和录屏
```bash
# 截图
xcrun simctl io "iPhone 15" screenshot screenshot.png

# 录屏
xcrun simctl io "iPhone 15" recordVideo recording.mov
# 按 Ctrl+C 停止录屏
```
