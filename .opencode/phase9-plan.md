# Phase 9: CI/CD 优化 + 生产就绪 + 质量保障

**创建时间**: 2026-05-06
**前置依赖**: Phase 8 完成（SuperApp 业务开发）
**预计工期**: 2-3 周
**优先级**: 🟠 高

---

## 一、现状分析

### 1.1 CI 流水线现状

| 维度 | 现状 | 问题 |
|------|------|------|
| Runner | macos-15 | ✅ 足够新 |
| Xcode | 26.4.1 (本地) / CI 自带 | ✅ |
| 构建触发 | push/PR to main/master/develop | ✅ |
| 并发控制 | `cancel-in-progress: true` | ✅ |
| 依赖缓存 | CocoaPods (Pods/) | ⚠️ 无 DerivedData 缓存 |
| 单元测试 | 10 个 scheme 矩阵并行 | ✅ 但每个 job 独立安装依赖 |
| UI 测试 | 3 个 job (Smoke/Core/Manifest) | ❌ 全部 `continue-on-error` |
| 覆盖率 | `xccov view --report` 输出到 artifact | ⚠️ 无外部服务集成 |
| 代码签名 | 无 (unsigned build only) | ❌ 无法真机测试/分发 |
| IPA 构建 | tag 触发，unsigned | ⚠️ 无法安装到真机 |
| SwiftLint | brew install 每次 | ⚠️ 慢，无缓存 |
| 截图 | 上传为 artifact | ✅ |
| 测试报告 | JUnit XML + GitHub Actions annotation | ✅ |

### 1.2 测试覆盖现状

| 测试目录 | 文件数 | 覆盖范围 |
|----------|--------|----------|
| Tests/CacheTests | 4 | MemoryCache, DiskCache, CacheManager, KeyGenerator |
| Tests/MessageTests | 4 | Router, Engine, Store, Payload |
| Tests/HandlerTests | 3 | Simple, Advanced, Registry |
| Tests/Infrastructure | 4 | Logging, Diagnostic, HandlerRegistry, DebugPanel |
| Tests/WebBridgeKitTests | 3 | Glob, ThreadSafety, ManifestExtension |
| Tests/AITests | 1 | AIHTTPServer |
| Tests/BridgeTests | 1 | BridgeCore |
| Tests/CoreTests | 1 | WebBrowserParams |
| Tests/ModelsTests | 1 | CacheModels |
| Tests/UtilsTests | 1 | WebBridgeLogger |
| Tests/ServicesTests | 1 | NetworkService |
| Tests/SkillsTests | 1 | SkillRegistry |
| Tests/e2e | 0 | 空目录 |
| **总计** | **25** | |

### 1.3 依赖版本

| 依赖 | 版本 | 状态 |
|------|------|------|
| Alamofire | 5.11.0 | ⚠️ 非 latest |
| Kingfisher | 7.12.0 | ✅ |
| Moya/RxSwift | 15.0.0 | ⚠️ 有 15.x 更新 |
| RealmSwift | 10.54.6 | ✅ |
| RxSwift | 6.9.0 | ⚠️ 有更新 |
| SnapKit | 5.7.1 | ✅ |
| SVProgressHUD | 2.3.1 | ⚠️ 非常旧 |
| SwiftSoup | 2.11.3 | ✅ |
| ZIPFoundation | 0.9.20 | ⚠️ 有 0.9.x 更新 |
| Material | 3.1.8 | ❌ 极其陈旧，建议替换 |

### 1.4 主要痛点

1. **CI 脚本冗余**: 模拟器创建逻辑重复 4 次（unit-tests/smoke/core/manifest）
2. **UI 测试不可靠**: CI 模拟器无法渲染完整 App UI，全部 continue-on-error
3. **无代码签名**: 无法真机安装和 TestFlight 分发
4. **测试覆盖不均**: 部分模块仅 1 个测试文件（AI/Bridge/Core/Models/Utils/Services）
5. **无 E2E 测试**: Tests/e2e/ 目录为空
6. **无覆盖率门禁**: 覆盖率数据仅作为 artifact 上传，无 fail 阈值
7. **依赖老旧**: Material 3.1.8 极其陈旧，SVProgressHUD 也很旧
8. **部署目标**: iOS 14.0 — 市场份额已足够低，可考虑升级

---

## 二、Phase 9 总体目标

```
Phase 9: CI/CD 优化 + 生产就绪
├── 9.1 CI 工作流优化（去重、缓存、速度）
├── 9.2 测试质量提升（覆盖率门禁、E2E、Flaky 管理）
├── 9.3 代码签名与分发（Apple Developer、TestFlight）
├── 9.4 依赖升级与清理
├── 9.5 安全与合规（依赖审计、密钥管理）
├── 9.6 发布自动化（版本号、Changelog、Release）
├── 9.7 监控与报告（覆盖率趋势、性能基线）
└── 9.8 文档完善
```

---

## 三、任务清单

### 9.1 CI 工作流优化

**目标**: 减少 CI 运行时间 50%+，消除脚本冗余

#### 9.1.1 创建 Composite Actions（消除重复）

- [ ] 创建 `.github/actions/setup-sim/action.yml`
  - 模拟器创建 + 启动逻辑（当前重复 4 次）
  - 输入: `device_type` (默认 iPhone 16 Pro)
  - 输出: `device_id`
  ```yaml
  # .github/actions/setup-sim/action.yml
  name: 'Setup iOS Simulator'
  description: 'Create and boot an iOS simulator'
  inputs:
    device-type:
      description: 'Device type'
      required: false
      default: 'iPhone 16 Pro'
  outputs:
    device-id:
      description: 'Created simulator UDID'
      value: ${{ steps.create.outputs.device_id }}
  runs:
    using: 'composite'
    steps:
      - name: Create Simulator
        id: create
        shell: bash
        run: |
          RUNTIME_ID=$(xcrun simctl list runtimes available -j | python3 -c "
          import json, sys
          data = json.load(sys.stdin)
          for rt in data.get('runtimes', []):
              ident = rt.get('identifier', '')
              if 'iOS' in ident and rt.get('isAvailable', False):
                  print(ident)
                  break
          ")
          DEVICE_ID=$(xcrun simctl create "CI-iPhone" "${{ inputs.device-type }}" "$RUNTIME_ID")
          echo "device_id=$DEVICE_ID" >> $GITHUB_OUTPUT
          xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
  ```

- [ ] 创建 `.github/actions/setup-project/action.yml`
  - XcodeGen + CocoaPods 安装（当前重复 5 次）
  - 含 CocoaPods 缓存
  ```yaml
  # .github/actions/setup-project/action.yml
  name: 'Setup Xcode Project'
  description: 'Install deps, generate project, pod install'
  runs:
    using: 'composite'
    steps:
      - name: Cache CocoaPods
        uses: actions/cache@v4
        with:
          path: Pods
          key: pods-${{ runner.os }}-${{ hashFiles('Podfile.lock') }}
      - name: Cache DerivedData
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: derived-${{ runner.os }}-${{ hashFiles('Podfile.lock', 'project.yml') }}
      - shell: bash
        run: |
          brew install xcodegen
          xcodegen generate
          pod install
  ```

- [ ] 创建 `.github/actions/start-test-server/action.yml`
  - 启动本地测试服务器（当前重复 2 次）

#### 9.1.2 优化 CI 流程

- [ ] 重构 `ci.yml` 使用 composite actions
  - 预计减少 ~200 行 YAML
  - 每个步骤逻辑清晰可复用

- [ ] 添加 DerivedData 缓存
  ```yaml
  - name: Cache DerivedData
    uses: actions/cache@v4
    with:
      path: ~/Library/Developer/Xcode/DerivedData
      key: derived-${{ runner.os }}-${{ hashFiles('Podfile.lock', 'project.yml') }}
      restore-keys: derived-${{ runner.os }}-
  ```

- [ ] 优化单元测试 job 依赖安装
  - 当前每个 matrix job 独立安装 brew install xcodegen + pod install
  - 考虑合并为单一 job（使用 `-scheme` 循环），或添加 brew 缓存

- [ ] 添加 SwiftLint 缓存
  ```yaml
  - name: Cache SwiftLint
    uses: actions/cache@v4
    with:
      path: ~/Library/Caches/Homebrew/swiftlint
      key: swiftlint-${{ runner.os }}
  ```

- [ ] 添加 CI 超时保护
  ```yaml
  # 每个 job 加 timeout
  timeout-minutes: 30
  ```

#### 9.1.3 添加 CI 状态徽章 + PR 检查

- [ ] README.md 添加 CI 状态徽章
  ```markdown
  ![CI](https://github.com/dyyz1993/WebBridgeKit/actions/workflows/ci.yml/badge.svg)
  ```
- [ ] 配置 branch protection: PR 必须 CI 通过才能合并

#### 9.1.4 预期效果

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| YAML 行数 | ~350 行 | ~150 行 |
| 重复代码 | 4 处模拟器 + 5 处依赖安装 | 0 |
| 首次构建 | ~10 min | ~10 min（不变） |
| 增量构建 | ~10 min | ~5-6 min（DerivedData 缓存） |

---

### 9.2 测试质量提升

**目标**: 测试覆盖率 > 70%，建立 E2E 测试框架

#### 9.2.1 覆盖率门禁

- [ ] 添加覆盖率计算 job
  ```yaml
  coverage-report:
    name: Coverage Report
    runs-on: macos-15
    needs: [unit-tests]
    steps:
      - uses: actions/checkout@v4
      - name: Download all coverage artifacts
        uses: actions/download-artifact@v4
        with:
          pattern: coverage-*
      - name: Merge and calculate
        run: |
          # 合并所有 xcresult
          # 计算总覆盖率
          TOTAL=$(cat coverage-*.txt | grep "OVERALL" | ...)
          echo "Total coverage: $TOTAL"
          # 门禁检查
          if [ "$TOTAL" -lt "60" ]; then
            echo "::error::Coverage below 60%: $TOTAL%"
            exit 1
          fi
  ```

- [ ] 配置最低覆盖率阈值: 60%（初期），逐步提升到 70%+

#### 9.2.2 补充薄弱模块测试

当前单文件模块（需要扩充）：

- [ ] **AITests** (1 → 3+ files)
  - `AIRouterTests.swift` — 路由匹配测试
  - `BuiltinAIToolsTests.swift` — 内置工具测试
  - `MCPProtocolTests.swift` — MCP 协议测试

- [ ] **BridgeTests** (1 → 3+ files)
  - `BridgeMessageHandlerTests.swift` — 消息处理测试
  - `BridgeLifecycleTests.swift` — 生命周期测试

- [ ] **CoreTests** (1 → 3+ files)
  - `WebViewConfigurationTests.swift`
  - `NavigationDelegateTests.swift`
  - `ScriptMessageHandlerTests.swift`

- [ ] **ModelsTests** (1 → 3+ files)
  - `MessageModelsTests.swift`
  - `HandlerModelsTests.swift`
  - `CacheModelsAdditionalTests.swift`

- [ ] **UtilsTests** (1 → 2+ files)
  - `JSONUtilsTests.swift`
  - `URLUtilsTests.swift`

- [ ] **ServicesTests** (1 → 2+ files)
  - `ManifestServiceTests.swift`
  - `ResourceDownloadServiceTests.swift`

#### 9.2.3 E2E 测试框架

- [ ] 设计 E2E 测试架构
  ```
  Tests/e2e/
  ├── BridgeE2ETests.swift       — JS↔Native 完整链路
  ├── CacheE2ETests.swift        — Manifest 加载→缓存→离线访问
  ├── MessageE2ETests.swift      — 推送接收→路由→页面打开
  └── Support/
      ├── MockHTTPServer.swift   — 本地 HTTP Mock
      └── TestFixtures.swift     — 测试数据
  ```

- [ ] 实现 Bridge E2E 测试
  - WebView 加载 → JS 调用 → Native Handler 执行 → 回调结果
  - 覆盖 Top 10 高频 Handler（camera, location, storage, clipboard, etc.）

- [ ] 实现 Cache E2E 测试
  - Manifest 下载 → 资源缓存 → 离线加载 → 缓存刷新
  - 使用本地 mock server（`test-server/lazy-test`）

#### 9.2.4 Flaky 测试管理

- [ ] 添加测试重试机制
  ```yaml
  - name: Run tests with retry
    uses: nick-fields/retry@v3
    with:
      timeout_minutes: 15
      max_attempts: 2
      command: xcodebuild test ...
  ```

- [ ] 添加 Flaky 测试标记
  - 创建 `Tests/Infrastructure/FlakyTestTracker.swift`
  - 记录历史失败率
  - 自动跳过已知 flaky 测试（CI 环境）

- [ ] 添加测试超时配置
  ```yaml
  - maximum-test-execution-time-allowance 60  # 单个测试 60s 超时
  ```

#### 9.2.5 预期效果

| 指标 | 当前 | 目标 |
|------|------|------|
| 测试文件 | 25 | 40+ |
| E2E 测试 | 0 | 3 个套件 |
| 覆盖率 | 未知 | > 70% |
| Flaky 率 | 未知 | < 5% |

---

### 9.3 代码签名与分发

**目标**: 支持 TestFlight 分发和真机安装

#### 9.3.1 Apple Developer 配置

- [ ] 注册/配置 Apple Developer 账号
- [ ] 配置 App ID: `com.webbridgekit.superapp`
- [ ] 配置 Provisioning Profile
- [ ] 在 GitHub Secrets 中配置:
  ```
  APPLE_CERTIFICATE_BASE64    — P12 证书 (Base64)
  APPLE_CERTIFICATE_PASSWORD  — P12 密码
  KEYCHAIN_PASSWORD           — 临时 Keychain 密码
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_PRIVATE_KEY
  TEAM_ID                     — Apple Team ID
  ```

#### 9.3.2 签名工作流

- [ ] 创建 `.github/workflows/build-signed.yml`
  ```yaml
  name: Build Signed IPA

  on:
    push:
      branches: [main]
    workflow_dispatch:

  jobs:
    build:
      runs-on: macos-15
      steps:
        - uses: actions/checkout@v4

        - name: Install Apple Certificate
          uses: apple-actions/import-codesign-certs@v2
          with:
            p12-file-base64: ${{ secrets.APPLE_CERTIFICATE_BASE64 }}
            p12-password: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}

        - name: Install Provisioning Profile
          run: |
            echo "${{ secrets.PROVISIONING_PROFILE_BASE64 }}" | base64 -d > profile.mobileprovision
            mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
            cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

        - name: Build & Archive
          run: |
            xcodebuild archive \
              -workspace WebBridgeKit.xcworkspace \
              -scheme SuperApp \
              -configuration Release \
              -archivePath build/SuperApp.xcarchive \
              -destination 'generic/platform=iOS' \
              CODE_SIGN_STYLE=Manual \
              DEVELOPMENT_TEAM=${{ secrets.TEAM_ID }} \
              PROVISIONING_PROFILE_SPECIFIER="SuperApp_Distribution"

        - name: Export IPA
          run: |
            xcodebuild -exportArchive \
              -archivePath build/SuperApp.xcarchive \
              -exportOptionsPlist ExportOptions.plist \
              -exportPath build/export

        - name: Upload IPA
          uses: actions/upload-artifact@v4
          with:
            name: SuperApp-Signed
            path: build/export/*.ipa
  ```

- [ ] 创建 `ExportOptions.plist`

#### 9.3.3 TestFlight 上传

- [ ] 在 `build-signed.yml` 中添加 TestFlight 上传步骤
  ```yaml
  - name: Upload to TestFlight
    if: github.ref == 'refs/heads/main'
    run: |
      xcrun altool --upload-app \
        --type ios \
        --file build/export/*.ipa \
        --apiKey ${{ secrets.APP_STORE_CONNECT_KEY_ID }} \
        --apiIssuer ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
  ```

- [ ] 添加 TestFlight 分发通知（可选 Slack/Bark）

#### 9.3.4 预期效果

| 能力 | 当前 | 目标 |
|------|------|------|
| 签名构建 | ❌ 仅 unsigned | ✅ Apple 签名 |
| 真机安装 | ❌ | ✅ Ad-hoc |
| TestFlight | ❌ | ✅ 自动上传 |
| 分发渠道 | GitHub Release only | GitHub Release + TestFlight |

---

### 9.4 依赖升级与清理

**目标**: 升级老旧依赖，减少技术债

#### 9.4.1 依赖升级优先级

| 依赖 | 当前 | 目标 | 风险 | 行动 |
|------|------|------|------|------|
| Material | 3.1.8 | 移除 | 高 | 替换为原生 UIKit / SnapKit |
| SVProgressHUD | 2.3.1 | 最新或移除 | 中 | 评估是否仍需，可用原生替代 |
| Alamofire | 5.11.0 | 5.x latest | 低 | 直接升级 |
| RxSwift | 6.9.0 | 6.x latest | 低 | 直接升级 |
| Moya | 15.0.0 | 15.x latest | 低 | 直接升级 |
| ZIPFoundation | 0.9.20 | 0.9.x latest | 低 | 直接升级 |

#### 9.4.2 Material 替换方案

- [ ] 审计 Material 使用范围
  ```bash
  grep -r "import Material" --include="*.swift" Sources/ SuperApp/
  ```

- [ ] 制定替换策略
  - Material 的 `Button`, `TextField`, `Card` 等组件 → SnapKit + 原生 UIKit
  - Material 的 `Motion` 动画 → UIView.animate
  - 如果使用范围小，直接替换；如果大，分批替换

- [ ] 执行替换并验证测试

#### 9.4.3 SVProgressHUD 评估

- [ ] 审计使用范围
- [ ] 如仅少量使用 → 替换为原生 `UIActivityIndicatorView`
- [ ] 如广泛使用 → 升级到最新版本

#### 9.4.4 部署目标评估

- [ ] 评估 iOS 14 → iOS 15 升级可行性
  - iOS 14 市场份额 < 1%（2026 年）
  - iOS 15+ 支持 async/await 原生并发
  - iOS 15+ 支持 `UIButton.Configuration`
  - 可以移除部分 polyfill 代码

#### 9.4.5 预期效果

| 指标 | 当前 | 目标 |
|------|------|------|
| 过时依赖 | 2 个高风险 | 0 |
| Pod 数量 | 12 个 | ≤ 10 个 |
| 部署目标 | iOS 14.0 | iOS 15.0（可选） |

---

### 9.5 安全与合规

**目标**: 建立安全扫描和密钥管理机制

#### 9.5.1 依赖安全审计

- [ ] 添加依赖漏洞扫描
  ```yaml
  security-audit:
    name: Security Audit
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Check Pod vulnerabilities
        run: |
          pod repo update
          # 检查已知漏洞
          for pod in $(cat Podfile.lock | grep -A1 "PODS:" | tail -n +2 | head -n -2 | sed 's/ *- //'); do
            echo "Checking $pod"
          done
  ```

- [ ] 定期运行 `pod outdated` 检查更新
- [ ] 添加 Dependabot 配置（如果支持 CocoaPods）

#### 9.5.2 密钥管理

- [ ] 审计所有硬编码密钥和 URL
  ```bash
  grep -rn "apiKey\|secret\|token\|password" --include="*.swift" Sources/ SuperApp/
  ```

- [ ] 确保 Keychain 存储所有敏感数据
- [ ] 添加 `.gitignore` 确认无 `.env` / 密钥文件泄露

#### 9.5.3 SAST 扫描

- [ ] 配置 SwiftLint 安全规则
  ```yaml
  # .swiftlint.yml 添加
  opt_in_rules:
    - force_unwrapping
    - empty_count
    - overridden_super_call
    - prohibited_super_call
    - anyobject_protocol
    - private_outlet
    - vertical_whitespace_closing_braces
  ```

- [ ] 考虑添加 SonarQube / CodeQL 扫描（如团队规模增长）

---

### 9.6 发布自动化

**目标**: 一键发布，自动版本号 + Changelog

#### 9.6.1 版本号管理

- [ ] 创建 `scripts/bump_version.sh`
  ```bash
  #!/bin/bash
  # Usage: ./scripts/bump_version.sh [major|minor|patch]
  
  CURRENT=$(grep -m1 'MARKETING_VERSION' project.yml | sed 's/.*: *"\(.*\)"/\1/')
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
  
  case "${1:-patch}" in
    major) ((MAJOR++)); MINOR=0; PATCH=0 ;;
    minor) ((MINOR++)); PATCH=0 ;;
    patch) ((PATCH++)) ;;
  esac
  
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
  echo "Bumping $CURRENT → $NEW_VERSION"
  
  sed -i '' "s/MARKETING_VERSION: \"$CURRENT\"/MARKETING_VERSION: \"$NEW_VERSION\"/g" project.yml
  sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$((MAJOR * 100 + MINOR * 10 + PATCH))\"/g" project.yml
  ```

#### 9.6.2 自动 Changelog

- [ ] 创建 `scripts/generate_changelog.sh`
  ```bash
  #!/bin/bash
  # 从 git log 生成 changelog
  PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
  
  echo "## What's Changed"
  echo ""
  
  if [ -n "$PREV_TAG" ]; then
    git log "$PREV_TAG"..HEAD --pretty=format:"- %s (%h)" --no-merges
  else
    git log --pretty=format:"- %s (%h)" --no-merges -20
  fi
  ```

- [ ] 配置 release workflow
  ```yaml
  # .github/workflows/release.yml
  name: Release

  on:
    workflow_dispatch:
      inputs:
        bump_type:
          type: choice
          options: [patch, minor, major]
          default: patch

  jobs:
    release:
      runs-on: macos-15
      steps:
        - uses: actions/checkout@v4
          with:
            token: ${{ secrets.GITHUB_TOKEN }}

        - name: Bump Version
          run: ./scripts/bump_version.sh ${{ inputs.bump_type }}

        - name: Generate Changelog
          run: ./scripts/generate_changelog.sh > CHANGELOG.md

        - name: Commit & Tag
          run: |
            git config user.name "github-actions"
            git config user.email "actions@github.com"
            VERSION=$(grep -m1 'MARKETING_VERSION' project.yml | sed 's/.*: *"\(.*\)"/\1/')
            git add project.yml CHANGELOG.md
            git commit -m "chore: release v$VERSION"
            git tag "v$VERSION"
            git push --follow-tags

        - name: Build & Upload to TestFlight
          # ... (复用 9.3 的签名构建步骤)

        - name: Create GitHub Release
          uses: softprops/action-gh-release@v2
          with:
            tag_name: ${{ steps.version.outputs.version }}
            body_path: CHANGELOG.md
            files: build/export/*.ipa
  ```

#### 9.6.3 Release Notes 模板

- [ ] 创建 `docs/RELEASE_NOTES_TEMPLATE.md`
  ```markdown
  ## v{VERSION}

  ### New Features
  -

  ### Bug Fixes
  -

  ### Breaking Changes
  -

  ### Dependencies
  -

  ### Migration Guide
  -
  ```

---

### 9.7 监控与报告

**目标**: 建立持续监控，追踪质量趋势

#### 9.7.1 覆盖率趋势

- [ ] 添加覆盖率趋势报告
  - 方案 A: Codecov.io 集成（免费开源项目）
  - 方案 B: GitHub Actions 内置趋势（上传 JSON + 绘图）

  ```yaml
  - name: Upload Coverage to Codecov
    uses: codecov/codecov-action@v4
    with:
      files: ./coverage/*.xml
      fail_ci_if_error: false
  ```

- [ ] README 添加覆盖率徽章
  ```markdown
  [![Coverage](https://codecov.io/gh/dyyz1993/WebBridgeKit/branch/main/graph/badge.svg)]
  ```

#### 9.7.2 性能基线

- [ ] 添加编译时间监控
  ```yaml
  - name: Measure Build Time
    run: |
      START=$(date +%s)
      xcodebuild build ...
      END=$(date +%s)
      DURATION=$((END - START))
      echo "Build time: ${DURATION}s"
      echo "BUILD_DURATION=$DURATION" >> $GITHUB_ENV

  - name: Check Build Time Regression
    run: |
      if [ "$BUILD_DURATION" -gt 600 ]; then
        echo "::warning::Build time exceeds 10 minutes: ${BUILD_DURATION}s"
      fi
  ```

- [ ] 添加测试执行时间监控
  - 每次测试记录耗时
  - 超过阈值发出 warning

#### 9.7.3 CI 健康度监控

- [ ] 添加 CI 健康度检查 job
  ```yaml
  ci-health:
    name: CI Health Report
    runs-on: ubuntu-latest
    if: always()
    needs: [build, unit-tests, swiftlint]
    steps:
      - name: Generate Report
        run: |
          echo "## CI Health Report" >> $GITHUB_STEP_SUMMARY
          echo "| Job | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-----|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Build | ${{ needs.build.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Tests | ${{ needs.unit-tests.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Lint | ${{ needs.swiftlint.result }} |" >> $GITHUB_STEP_SUMMARY
  ```

---

### 9.8 文档完善

**目标**: 所有基础设施和流程有文档可查

#### 9.8.1 CI/CD 文档

- [ ] 创建 `docs/CI_CD.md`
  - CI 流水线说明
  - 如何在本地复现 CI 构建
  - 如何处理 CI 失败
  - 如何添加新的测试 target
  - 如何触发发布

#### 9.8.2 贡献指南

- [ ] 创建 `CONTRIBUTING.md`
  - 开发环境搭建
  - 代码风格规范
  - 提交信息格式（Conventional Commits）
  - PR 流程
  - 测试要求

#### 9.8.3 更新 README

- [ ] 添加项目架构图
- [ ] 添加 CI 徽章
- [ ] 添加快速开始指南
- [ ] 添加模块说明

---

## 四、执行顺序

```
Week 1: 基础设施
├── Day 1-2: 9.1 CI 工作流优化（composite actions + 缓存）
├── Day 3:   9.5.2 密钥审计 + 9.5.3 SAST 扫描
└── Day 4-5: 9.2.1 覆盖率门禁 + 9.2.4 Flaky 管理

Week 2: 质量提升
├── Day 1-2: 9.2.2 补充薄弱模块测试
├── Day 3-4: 9.2.3 E2E 测试框架
└── Day 5:   9.4.1-9.4.3 依赖升级

Week 3: 发布就绪
├── Day 1-2: 9.3 代码签名与分发
├── Day 3:   9.6 发布自动化
├── Day 4:   9.7 监控与报告
└── Day 5:   9.8 文档完善
```

---

## 五、验收标准

### 5.1 CI/CD
- [ ] CI YAML 行数减少 50%+（composite actions）
- [ ] 增量构建时间减少 30%+（DerivedData 缓存）
- [ ] 所有 job 有 timeout-minutes 保护
- [ ] README 有 CI 状态徽章

### 5.2 测试质量
- [ ] 测试文件数 > 40
- [ ] 代码覆盖率 > 70%
- [ ] 覆盖率低于 60% 时 CI 失败
- [ ] E2E 测试套件至少 3 个场景
- [ ] 已知 Flaky 测试有标记和管理机制

### 5.3 分发
- [ ] 可构建签名 IPA
- [ ] 可上传 TestFlight（配置 Apple Developer 后）
- [ ] tag 触发自动发布 + Changelog

### 5.4 安全
- [ ] 无硬编码密钥/Token
- [ ] 所有敏感数据使用 Keychain
- [ ] SwiftLint 安全规则启用

### 5.5 依赖
- [ ] 无高风险过时依赖
- [ ] Material pod 已替换或移除

### 5.6 文档
- [ ] CI/CD 文档完整
- [ ] CONTRIBUTING.md 存在
- [ ] README 包含架构图和快速开始

---

## 六、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Apple Developer 账号不可用 | 中 | 高 | 9.3 可延后，先完成 9.1/9.2/9.4 |
| Material 替换引入回归 | 中 | 中 | 分批替换，每批跑完整测试 |
| 覆盖率门禁过于严格 | 低 | 中 | 初期设 60%，渐进提升 |
| E2E 测试 CI 不稳定 | 高 | 低 | 使用 mock server，不依赖外部服务 |
| 依赖升级破坏兼容性 | 中 | 中 | 逐个升级，每次升级后跑 CI |

---

## 七、与 Phase 8 的关系

Phase 9 独立于 Phase 8 的业务功能开发，但建议：
1. **Phase 8 完成后再开始 Phase 9**：避免业务开发期间的 CI 变动影响效率
2. **部分任务可提前**：9.1 CI 优化和 9.5 安全审计可在 Phase 8 期间并行进行
3. **测试补充与 Phase 8 同步**：Phase 8 每个新功能都应同步补充测试
