# CI/CD Guide

## CI Pipeline Overview

The CI pipeline is defined in `.github/workflows/ci.yml` and runs on every push/PR to `main`, `master`, or `develop`.

### Pipeline Flow

```
SwiftLint ──┐
            ├──► Unit Tests (Core A) ──┐
Build ──────┤──► Unit Tests (Core B)   ├──► ✅
            ├──► Unit Tests (Handlers) │
            ├──► Unit Tests (Modules) ─┘
            ├──► Smoke Tests (continue-on-error)
            └──► UI Fidelity Tests (continue-on-error)
```

- SwiftLint and Build run **in parallel** (no dependency)
- Build uploads DerivedData artifact; test jobs download it to skip recompilation
- Critical path: **~15–20 min** (SwiftLint ~3 min + Build ~12 min || parallel, Tests ~15 min)

### Jobs (8 total)

| # | Job | Runner | Timeout | Dependency | Description |
|---|-----|--------|---------|------------|-------------|
| 1 | **SwiftLint** | macos-15 | 10 min | — | Lint `Sources/` and `SuperApp/Sources/` |
| 2 | **Build** | macos-15 | 30 min | — | Compile SuperApp, upload DerivedData artifact |
| 3 | **Unit Tests (Core A)** | macos-15 | 30 min | Build | Cache, Bridge, Core, Models tests |
| 4 | **Unit Tests (Core B)** | macos-15 | 30 min | Build | Utils, Services, Extensions, Base tests |
| 5 | **Unit Tests (Handlers)** | macos-15 | 30 min | Build | HandlerTests-Part1/2, AI, Skills, Theme tests |
| 6 | **Unit Tests (Modules)** | macos-15 | 30 min | Build | Message, WebSocket, CommandParser, Infra, Managers, ViewModel tests |
| 7 | **Smoke Tests** | macos-15 | 30 min | Build | Main flow + settings UI tests (continue-on-error) |
| 8 | **UI Fidelity Tests** | macos-15 | 30 min | Build | Screenshot diff comparison (continue-on-error) |

### Unit Test Matrix

| Group | Schemes |
|-------|---------|
| **Core A** | CacheTests, BridgeTests, CoreTests, ModelsTests |
| **Core B** | UtilsTests, ServicesTests, ExtensionsTests, BaseTests |
| **Handlers** | HandlerTests-Part1, HandlerTests-Part2, AITests, SkillsTests, ThemeTests |
| **Modules** | MessageTests, WebSocketTests, CommandParserTests, InfrastructureTests, ManagersTests, ViewModelTests, WebBridgeKitTests |

### Features

- **Concurrency control** — same branch cancels older runs
- **CocoaPods cache** — keyed by `Podfile.lock` hash
- **DerivedData cache** — keyed by `Podfile.lock` + `project.yml`
- **SPM Server cache** — caches `Server/.build` for Swift Hummingbird backend
- **Build artifact sharing** — Build job uploads DerivedData; test jobs download and reuse (skip recompilation)
- **Retry on flaky tests** — each unit test scheme retries up to 2×, Smoke/UI Fidelity retry up to 3×
- **Code coverage** — collected and uploaded as artifact
- **Screenshots** — collected on failure
- **JUnit reports** — published via `mikepenz/action-junit-report@v4`

## Running CI Locally

### SwiftLint

```bash
swiftlint lint --config .swiftlint.yml Sources/ SuperApp/Sources/
```

### Build

```bash
xcodebuild build \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -arch arm64 \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | xcpretty --color
```

### Unit Tests

```bash
# All tests
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Single scheme
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme CacheTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Handling CI Failures

### SwiftLint Failures

```bash
# Run locally to see errors
swiftlint lint --config .swiftlint.yml Sources/ SuperApp/Sources/

# Auto-fix where possible
swiftlint --fix --config .swiftlint.yml Sources/ SuperApp/Sources/
```

### Build Failures

- Check `project.yml` — run `xcodegen generate` and verify no errors
- Check `Podfile` — run `pod install` and resolve conflicts
- Common cause: missing files in `project.yml` sources list

### Unit Test Failures

- Check the JUnit report artifact for failed test names
- Run the specific scheme locally:
  ```bash
  xcodebuild test \
    -workspace WebBridgeKit.xcworkspace \
    -scheme <FailedScheme> \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
  ```

### Simulator Issues

- CI creates a fresh simulator each run
- Locally: `xcrun simctl delete unavailable` to clean up

### Dependency Cache Miss

- CocoaPods cache key: `Podfile.lock` hash
- DerivedData cache key: `Podfile.lock` + `project.yml`
- SPM Server cache key: `Server/Package.resolved` hash
- Bump a dependency version or clear the cache in GitHub Actions UI

## Adding New Test Targets

### 1. Create test directory

```bash
mkdir -p Tests/NewModuleTests
```

### 2. Add test target to `project.yml`

```yaml
targets:
  NewModuleTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - Tests/NewModuleTests
    dependencies:
      - target: WebBridgeKit
    settings:
      base:
        INFOPLIST_FILE: Tests/NewModuleTests/Info.plist
```

### 3. Update CI matrix

Edit `.github/workflows/ci.yml` — add the new scheme to the appropriate group:

```yaml
group:
  - name: Core A
    schemes: >-
      CacheTests
      BridgeTests
      CoreTests
      ModelsTests
      NewModuleTests   # Add to appropriate group
```

### 4. Regenerate and install

```bash
xcodegen generate
pod install
```

## Composite Actions

### `setup-project`

**Path:** `.github/actions/setup-project/action.yml`

Installs `xcodegen`, `swiftlint`, `pod`, `xcpretty`, caches CocoaPods + DerivedData + SPM Server, then runs `xcodegen generate` and `pod install`.

**Usage in workflow:**

```yaml
- name: Setup Project
  uses: ./.github/actions/setup-project
```

### `setup-sim`

**Path:** `.github/actions/setup-sim/action.yml`

Creates and boots an iOS simulator. Outputs the device UDID.

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `device-type` | `iPhone 16 Pro` | Simulator device type |
| `sim-name` | `CI-iPhone` | Simulator name |

**Outputs:**

| Output | Description |
|--------|-------------|
| `device-id` | Created simulator UDID |

**Usage in workflow:**

```yaml
- name: Setup Simulator
  id: sim
  uses: ./.github/actions/setup-sim
  with:
    device-type: 'iPhone 16 Pro'

- name: Run Tests
  run: |
    xcodebuild test \
      -destination "platform=iOS Simulator,id=${{ steps.sim.outputs.device-id }}" \
      ...
```

## Release Process

### Build IPA

The `build-ipa.yml` workflow generates an unsigned IPA:

**Trigger:** Push a `v*` tag or manual dispatch

```bash
# Create and push a version tag
git tag v1.2.0
git push origin v1.2.0
```

This will:
1. Setup the project (xcodegen + pod install)
2. Build an unsigned IPA
3. Upload the IPA as a GitHub Actions artifact (30-day retention)

### Manual Trigger

Go to **Actions → Build IPA → Run workflow** in the GitHub UI.
