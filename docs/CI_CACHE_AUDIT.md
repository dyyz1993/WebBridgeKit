# CI Cache Optimization Audit

## Current State

Caching is **already implemented** in `.github/actions/setup-project/action.yml` (composite action):

| Cache Target | Key Strategy | Restore Keys | Status |
|-------------|-------------|--------------|--------|
| Homebrew (~/Library/Caches/Homebrew) | `brew-{os}-xcodegen-swiftlint` | None | Active |
| CocoaPods (Pods/) | `pods-{os}-{hashFiles(Podfile.lock)}` | `pods-{os}-` | Active |
| DerivedData (~/Library/Developer/Xcode/DerivedData) | `derived-{os}-xcode16.4-{hashFiles(Podfile.lock, project.yml)}` | `derived-{os}-xcode16.4-` | Active |
| Homebrew (SwiftLint job) | `brew-{os}-swiftlint` | None | Active |

### Cache Usage by Job

| Job | Uses Caching | Details |
|-----|-------------|---------|
| SwiftLint | Homebrew only | Installs swiftlint via brew |
| Build | Full (via setup-project) | Pods + DerivedData + Homebrew |
| Unit Tests (3 groups) | Full (via setup-project) | Pods + DerivedData + Homebrew |
| Smoke Tests | Full (via setup-project) | Pods + DerivedData + Homebrew |
| UI Fidelity Tests | Full (via setup-project) | Pods + DerivedData + Homebrew |

## Assessment

### What's Working Well

1. **Composite action reuse** — All jobs use the same `setup-project` action, ensuring consistent caching
2. **Podfile.lock-based cache keys** — Pods cache invalidates correctly when dependencies change
3. **DerivedData keyed on project.yml + Podfile.lock** — Catches project structure changes
4. **Restore keys with prefix fallback** — Partial cache hits still provide value

### Potential Improvements

| Area | Recommendation | Impact |
|------|---------------|--------|
| **SPM Server cache** | Add `Server/.build` cache keyed on `Server/Package.resolved` | Saves ~2-3 min on server builds |
| **xcpretty gem cache** | Cache `~/.gem` or use `ruby/setup-ruby` with bundler-cache | Minor (gem install is fast) |
| **Simulator runtime cache** | Pre-install runtime in custom runner image | Reduces flaky simulator setup |
| **Build artifact sharing** | Share build outputs between Build and test jobs using artifacts | Currently rebuilds per job — could save ~10 min |
| **Test result caching** | Skip test schemes whose source files haven't changed | Complex, low priority |

### Build Artifact Sharing (Recommended)

The biggest improvement would be sharing the build output between the `build` job and the test jobs. Currently:

1. `build` job compiles everything
2. `unit-tests` jobs re-run `setup-project` which rebuilds

**Recommendation**: Upload the `DerivedData` or `Build/Products` from the `build` job as an artifact, then download it in test jobs to skip compilation:

```yaml
# In build job:
- name: Upload Build Products
  uses: actions/upload-artifact@v4
  with:
    name: build-products
    path: ~/Library/Developer/Xcode/DerivedData/WebBridgeKit-*/

# In test jobs:
- name: Download Build Products
  uses: actions/download-artifact@v4
  with:
    name: build-products
    path: ~/Library/Developer/Xcode/DerivedData/
```

**Estimated savings**: ~10-15 minutes per test job (3 groups + smoke + UI fidelity = ~50-75 min total saved per CI run).

## Summary

Caching is well-implemented. The highest-impact improvement would be **build artifact sharing** between the build and test jobs to avoid redundant compilation. No critical issues found.
