# Contributing to WebBridgeKit

## Development Environment Setup

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 15+ | Mac App Store |
| CocoaPods | Latest | `sudo gem install cocoapods` |
| XcodeGen | Latest | `brew install xcodegen` |
| SwiftLint | Latest | `brew install swiftlint` |
| xcpretty | Latest | `gem install xcpretty --no-document` |
| XcodeBuildMCP | Latest | `npm install -g xcodebuildmcp@latest` |

### Setup

```bash
git clone https://github.com/dyyz1993/WebBridgeKit.git
cd WebBridgeKit
bash scripts/bootstrap-dev.sh --no-services
open WebBridgeKit.xcworkspace
```

如果你希望把本地测试服务也一起拉起来，直接运行：

```bash
bash scripts/bootstrap-dev.sh
```

## How to Build

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Install CocoaPods dependencies
pod install

# Build from CLI
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

## Code Style

We use [SwiftLint](https://github.com/realm/SwiftLint) with rules defined in `.swiftlint.yml`.

### Key Rules

- **No `any` type** — use `unknown` and narrow with type checks
- **Explicit return types** on all public functions
- **No empty `catch` blocks** — handle or log every error
- **Files over 100 lines** — consider splitting
- **No force casts (`as!`)** in production code
- **No force tries (`try!`)** in production code

### Lint

```bash
swiftlint lint --config .swiftlint.yml Sources/ SuperApp/Sources/
```

CI runs SwiftLint as the first job. Fix all warnings before pushing.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`

**Examples:**

```
feat(bridge): add NFC handler
fix(cache): resolve manifest race condition
test(message): add channel pipeline tests
ci: add code coverage reporting
```

## Pull Request Process

1. **Fork** the repository and create a feature branch from `develop`
2. **Write tests** for all new code (see Testing Requirements below)
3. **Run lint** locally: `swiftlint lint --config .swiftlint.yml Sources/ SuperApp/Sources/`
4. **Open a PR** against `develop`
5. **CI must pass** — all jobs in the pipeline must be green
6. **At least one review** from a maintainer before merge
7. **Squash merge** into `develop`

### PR Title Format

Same as commit messages: `feat(scope): description`

## Testing Requirements

- **All new code must have tests.** No exceptions.
- Tests are **co-located** with source: test files live in `Tests/` organized by module
- Test file naming: `XxxTests.swift` (e.g., `CacheManagerTests.swift`)
- Run tests before pushing:

```bash
# Unit tests (all modules)
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme CacheTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Integration tests
./run_tests.sh

# Specific module
./run_tests.sh basic
./run_tests.sh manifest
```

### Test Directory Structure

```
Tests/
├── AITests/            # AI Engine tests
├── BridgeTests/        # Bridge Engine tests
├── CacheTests/         # Cache Engine tests
├── CoreTests/          # Core module tests
├── HandlerTests/       # Handler tests
├── Infrastructure/     # Infrastructure tests
├── MessageTests/       # Message Engine tests
├── ModelsTests/        # Model tests
├── ServicesTests/      # Service tests
├── SkillsTests/        # Skills Engine tests
├── UtilsTests/         # Utility tests
├── WebBridgeKitTests/  # Framework integration tests
└── e2e/                # End-to-end tests
```

When adding a new module, create a corresponding `XxxTests/` directory and add the test target to `project.yml`.

## Architecture Overview

Three-layer architecture, bottom-up:

```
┌─────────────────────────────────────────────────┐
│                  SuperApp                        │  Business App Layer
│           (business code, routing, config)       │
├─────────────────────────────────────────────────┤
│                 AppTemplate                      │  App Template Layer
│     (AppDelegate, RootVC, TabBar templates)      │
├─────────────────────────────────────────────────┤
│                WebBridgeKit                      │  Framework Layer
│  ┌──────┬──────┬──────┬──────┬──────┬──────┐    │
│  │Bridge│Cache │Message│ AI  │Theme │Skills│    │
│  └──────┴──────┴──────┴──────┴──────┴──────┘    │
│           41 Handlers · Core · Services          │
└─────────────────────────────────────────────────┘
```

- **Framework Layer** — `WebBridgeKit` static library containing all engines and handlers
- **App Template Layer** — `AppTemplate/` scaffold for new apps (AppDelegate/RootVC/TabBar)
- **SuperApp Layer** — `SuperApp/` sample/host app demonstrating full usage

### Six Engines

| Engine | Core Class | Purpose |
|--------|-----------|---------|
| Bridge Engine | `WebJavaScriptBridge` | JS ↔ Native bidirectional communication |
| Cache Engine | `CacheManager` / `ManifestCacheManager` | 3-tier cache (Memory/Disk/Manifest offline) |
| Message Engine | `MessageEngine` | Push notifications + processor pipeline + routing |
| AI Engine | `AIHTTPServer` / `AIRouter` | Local HTTP API + MCP tool protocol |
| Theme Engine | `ThemeManager` | Light/dark theme switching |
| Skills Engine | `SkillRegistry` | Pluggable skill modules |

## Directory Structure

```
WebBridgeKit/
├── Sources/                    # Framework source code
│   ├── AI/                     # AI Engine (Router, Server, Tools)
│   ├── Base/                   # Base classes (ViewController, ViewModel)
│   ├── Bridge/                 # Bridge Engine (Error, Meta, Registry)
│   ├── Cache/                  # Cache Engine (Memory/Disk/Manifest)
│   ├── Controllers/            # View Controllers
│   ├── Core/                   # Core (WebBridgePool, WebJavaScriptBridge)
│   ├── Extensions/             # Swift extensions
│   ├── Handlers/               # 41 native capability handlers
│   ├── Infrastructure/         # Logging, debugging, diagnostics
│   ├── Managers/               # Managers
│   ├── Message/                # Message Engine (Channels, Processors)
│   ├── Models/                 # Data models
│   ├── Services/               # Service layer (DI + Mock)
│   ├── Skills/                 # Skills Engine
│   ├── Theme/                  # Theme Engine
│   ├── Utils/                  # Utilities
│   ├── ViewModels/             # ViewModels
│   ├── Views/                  # UI components
│   └── WebBridgeKit.swift      # Framework entry point
├── AppTemplate/                # App template scaffold
│   └── Sources/
│       ├── AppDelegate.swift
│       ├── RootViewController.swift
│       └── TabBarController.swift
├── SuperApp/                   # Sample application
│   ├── Sources/
│   └── Resources/
├── Tests/                      # Test targets
├── SuperAppUITests/            # UI tests
├── Resources/                  # Framework resources (WebBridge.js)
├── docs/                       # Documentation
├── scripts/                    # Build/test scripts
├── test-server/                # Local test HTTP server
├── .github/
│   ├── workflows/              # CI/CD (ci.yml, build-ipa.yml)
│   └── actions/                # Composite actions (setup-sim, setup-project)
├── project.yml                 # XcodeGen project spec
├── Podfile                     # CocoaPods dependencies
└── .swiftlint.yml              # SwiftLint configuration
```
