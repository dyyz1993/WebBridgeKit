# Dependency Audit

## CocoaPods Dependencies (iOS App)

| Dependency | Version | Purpose | License | Upgrade Risk |
|------------|---------|---------|---------|--------------|
| **SnapKit** | 5.7.1 | Auto Layout DSL | MIT | Low — mature, stable API |
| **RxSwift** | 6.9.0 | Reactive programming framework | MIT | Medium — v7 has breaking changes |
| **RxCocoa** | 6.9.0 | UIKit bindings for RxSwift | MIT | Medium — tied to RxSwift version |
| **RxDataSources** | 5.0.0 | Animated table/collection data sources | MIT | Low — stable on RxSwift 6 |
| **Moya/RxSwift** | 15.0.0 | Network abstraction over Alamofire | MIT | Low — well-maintained |
| **Kingfisher** | 7.12.0 | Image downloading & caching | MIT | Medium — v8 has API changes |
| **SwiftSoup** | 2.11.3 | HTML parsing & manipulation | MIT | Low — stable, no breaking changes |
| **RealmSwift** | 10.54.6 | Local database / object store | Apache 2.0 | High — v11 requires migration |
| **ZIPFoundation** | 0.9.20 | ZIP archive read/write | MIT | Low — stable API |
| **Alamofire** | 5.11.0 | HTTP networking (transitive via Moya) | MIT | Low — mature, stable |

### Transitive Dependencies

| Dependency | Version | Required By |
|------------|---------|-------------|
| Differentiator | 5.0.0 | RxDataSources |
| RxRelay | 6.9.0 | RxCocoa |
| Realm (Core) | 10.54.6 | RealmSwift |
| Moya/Core | 15.0.0 | Moya/RxSwift |

## SPM Dependencies (Server — Hummingbird Backend)

| Dependency | Version | Purpose | License | Upgrade Risk |
|------------|---------|---------|---------|--------------|
| **Hummingbird** | 2.0.0+ | Lightweight HTTP server framework | Apache 2.0 | Low — Swift 6 ready |
| **swift-nio** | 2.83.0+ | Non-blocking I/O framework (by Apple) | Apache 2.0 | Low — Apple maintained |
| **swift-crypto** | 3.0.0+ | Crypto primitives (by Apple) | Apache 2.0 | Low — Apple maintained |

## Risk Assessment

### High Risk

| Dependency | Concern | Mitigation |
|------------|---------|------------|
| RealmSwift | v10.54.6 is late in v10 lifecycle; v11 changes sync API and object model | Pin version, plan migration in dedicated sprint |
| RxSwift | v6 is in maintenance mode; community shifting to async/await | Gradually migrate critical paths to Swift Concurrency |

### Medium Risk

| Dependency | Concern | Mitigation |
|------------|---------|------------|
| Kingfisher | v8 preview available with API refinements | Pin to ~> 7.0, test v8 in branch |
| Moya | Limited RxSwift 7 compatibility testing | Pin to current version |

### Low Risk

| Dependency | Status |
|------------|--------|
| SnapKit | Stable, no major versions pending |
| SwiftSoup | Stable, feature-complete |
| ZIPFoundation | Stable |
| Hummingbird / swift-nio / swift-crypto | Apple/community maintained, Swift 6 ready |

## License Compliance

All dependencies use permissive licenses (MIT or Apache 2.0). No GPL or copyleft licenses. No attribution requirements beyond license inclusion.

**Action required**: Include third-party license notices in app Settings > About > Legal section.

## Outdated Check

```bash
# Check for CocoaPods updates
pod outdated

# Check SPM updates
cd Server && swift package update --dry-run
```

## Recommendations

1. **Pin exact versions** in Podfile for CI reproducibility (already done via Podfile.lock)
2. **Plan RxSwift → async/await migration** — Start with new code using Swift Concurrency, migrate existing code incrementally
3. **Evaluate RealmSwift v11** — Test migration path on a feature branch
4. **Add license attribution** — Create a Settings screen section listing all third-party licenses
5. **Monthly dependency audit** — Run `pod outdated` and review changelogs monthly
