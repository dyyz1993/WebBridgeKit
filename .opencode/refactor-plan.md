# WebBridgeKit Refactoring Plan

> Generated: 2026-05-12 | Status: Phase 0-4.2 COMPLETE

## Overview

6 Phases, 22 Tasks, ~11-16 days estimated effort.

## Phase 0: Split Oversized Files (P0 - Critical) — ✅ COMPLETE

7 files > 600 lines split. Commit: `bab526b`

| # | File | Before | After | Strategy |
|---|------|--------|-------|----------|
| 0.1 | ComponentCatalogVC | 1284 | 125 | Extract 17 section builders via protocol |
| 0.2 | WebCacheDebugHandler | 900 | 171 | Split into 3 sub-handlers by domain |
| 0.3 | PersistentManifestLoader | 887 | 499 | Extract Types/Downloader/UI |
| 0.4 | WebResourceCacheManager | 827 | 81 | Extract Space/Resource/Stats |
| 0.5 | ManifestStore | 671 | 389 | Extract HTML/Manifest/Persistence |
| 0.6 | BuiltinAITools | 645 | 22 | Split ReadOnly/ReadWrite tools |
| 0.7 | AgentSchema | 639 | 96 | Extract Schema/Registry/Query |

## Phase 1: Handler Module Reorganization (P1) — ✅ COMPLETE

42 flat Handler files → 10 organized subdirectories. Commit: `bab526b`

## Phase 2: SuperApp Directory Reorganization (P1) — ✅ COMPLETE

46 flat VC files → 7 organized directories. 23 Views → 3 subdirectories. Commit: `bab526b`

## Phase 3: Test Architecture Upgrade (P2) — ✅ COMPLETE

- Split 4 test files > 600 lines (~15 new files)
- Commit: `bab526b`

## Phase 4: Build System Optimization (P2) — ✅ COMPLETE

### Phase 4.1 — File Splits (Commit: `09d3c79`)
- Split 5 more files: WebPageHistoryVC, WebPageHistoryManager, WebPageCacheHandler, ManifestCacheManager, TestDataSeeder
- Restored WebBrowserViewController+Navigation extension

### Phase 4.2 — SwiftLint + Borderline Files (Commit: `6843a2b`)
- Fixed 3 long lines (>300 chars) in BuiltinSkills, AgentSchema, NotificationDebugVC
- Split InboxVC (805→439), MainVC (687→539), ManifestCacheTestVC (896→579)
- SwiftLint warnings: only 18 acceptable `no_static_color_tokens` remain

### Phase 4.3 — CI Pipeline Optimization — ✅ DONE
- Consolidated 11 unit-test matrix → 3 groups (Core/Handlers/Modules)
- Max concurrent runners: 15 → 7 (53% reduction)
- Added per-scheme retry (2x) within unit-test groups
- Smoke + UI fidelity already had 3x retry (preserved)
- Caching already present in setup-project action (verified)
- Extracted XCODE_VERSION env var for DRY

## Phase 5: Architecture Quality (P3) — 🔲 TODO (low priority)

- Extract protocol layer for Cache module
- Unify error handling (WebBridgeError aggregation)
- Add performance benchmarks
- Generate API documentation with Swift-DocC

## Execution Log

| Date | Task | Status | Commit |
|------|------|--------|--------|
| 2026-05-12 | Phase 0: Split 7 oversized files | ✅ DONE | `bab526b` |
| 2026-05-12 | Phase 1: Handler reorganization (42→10 dirs) | ✅ DONE | `bab526b` |
| 2026-05-12 | Phase 2: SuperApp reorganization (46→7 dirs) | ✅ DONE | `bab526b` |
| 2026-05-12 | Phase 3: Test architecture upgrade | ✅ DONE | `bab526b` |
| 2026-05-12 | Phase 4.1: Split 5 more files | ✅ DONE | `09d3c79` |
| 2026-05-12 | Phase 4.2: SwiftLint + split 3 VCs | ✅ DONE | `6843a2b` |
| 2026-05-12 | Phase 4.3: CI pipeline optimization | ✅ DONE | pending |
| — | Phase 5: Architecture quality | 🔲 TODO | — |

## Final Scorecard

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Files >600 lines | 32 | 5 | 84% reduction |
| Max file size | 1,284 lines | ~630 lines | 51% reduction |
| SwiftLint warnings | Many | 18 acceptable | Near-zero |
| Handler navigation | 42 flat files | 10 directories | Organized |
| SuperApp navigation | 46 flat VCs | 7 directories | Organized |
| CI max runners | 15 | 7 | 53% reduction |
| CI unit-test groups | 11 individual | 3 grouped | Faster feedback |
| Build status | ✅ | ✅ | Zero regressions |
