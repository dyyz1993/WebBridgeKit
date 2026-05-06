# CI/CD Guide

## CI Pipeline Overview

The CI pipeline is defined in `.github/workflows/ci.yml` and runs on every push/PR to `main`, `master`, or `develop`.

### Pipeline Flow

```
SwiftLint ──► Build ──┬──► Unit Tests (matrix × 10)
                      ├──► Smoke Tests
                      ├──► Core UI Tests
                      └──► Manifest Cache Tests
```

### Jobs

| Job | Runner | Timeout | Description |
|-----|--------|---------|-------------|
| **SwiftLint** | macos-15 | 30 min | Lint `Sources/` and `SuperApp/Sources/` |
| **Build** | macos-15 | 30 min | Compile SuperApp (Debug, arm64 simulator) |
| **Unit Tests** | macos-15 | 30 min | 10 test schemes in parallel matrix |
| **Smoke Tests** | macos-15 | 30 min | Main flow + settings + permission UI tests |
| **Core UI Tests** | macos-15 | 45 min | Core UI tests (3 parallel workers, skips manifest) |
| **Manifest Tests** | macos-15 | 30 min | Manifest cache tests (sequential, no parallelism) |

### Unit Test Matrix

| Scheme | Module |
|--------|--------|
| CacheTests | Cache Engine |
| MessageTests | Message Engine |
| AITests | AI Engine |
| SkillsTests | Skills Engine |
| HandlerTests | 41 Handlers |
| BridgeTests | Bridge Engine |
| CoreTests | Core module |
| ModelsTests | Data models |
| UtilsTests | Utilities |
| ServicesTests | Service layer |

### Features

- **Concurrency control** — same branch cancels older runs
- **CocoaPods cache** — keyed by `Podfile.lock` hash
- **DerivedData cache** — keyed by `Podfile.lock` + `project.yml`
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

# Single module
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme CacheTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Integration Tests

```bash
./run_tests.sh            # All tests
./run_tests.sh basic      # Basic functionality
./run_tests.sh manifest   # Manifest cache
./run_tests.sh display    # Display mode
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

- CI creates a fresh simulator each run via `setup-sim` composite action
- Locally: `xcrun simctl delete unavailable` to clean up

### Dependency Cache Miss

- If CocoaPods cache is stale, the cache key is based on `Podfile.lock`
- Bump a pod version or clear the cache in GitHub Actions UI

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

Edit `.github/workflows/ci.yml` — add the new scheme to the `unit-tests` matrix:

```yaml
matrix:
  scheme:
    - CacheTests
    - MessageTests
    # ... existing schemes
    - NewModuleTests   # Add here
```

### 4. Regenerate and install

```bash
xcodegen generate
pod install
```

## Composite Actions

### `setup-project`

**Path:** `.github/actions/setup-project/action.yml`

Installs xcodegen + swiftlint, caches CocoaPods and DerivedData, then runs `xcodegen generate` and `pod install`.

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
