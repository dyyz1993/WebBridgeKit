# WebBridgeKit Refactoring Plan

> Generated: 2026-05-12 | Status: IN PROGRESS

## Overview

6 Phases, 22 Tasks, ~11-16 days estimated effort.

## Phase 0: Split Oversized Files (P0 - Critical)

7 files > 600 lines need splitting.

| # | File | Lines | Strategy |
|---|------|-------|----------|
| 0.1 | ComponentCatalogVC | 1284 | Extract 17 section builders via protocol |
| 0.2 | WebCacheDebugHandler | 900 | Split into 3 sub-handlers by domain |
| 0.3 | PersistentManifestLoader | 887 | Extract Types/Downloader/UI |
| 0.4 | WebResourceCacheManager | 827 | Extract Space/Resource/Stats |
| 0.5 | ManifestStore | 671 | Extract HTML/Manifest/Persistence |
| 0.6 | BuiltinAITools | 645 | Split ReadOnly/ReadWrite tools |
| 0.7 | AgentSchema | 639 | Extract Schema/Registry/Query |

## Phase 1: Handler Module Reorganization (P1)

Group 42 flat Handler files into 9 subdirectories by domain.

## Phase 2: SuperApp Directory Reorganization (P1)

Group 46 flat VC files into 7 subdirectories.

## Phase 3: Test Architecture Upgrade (P2)

- Split 4 test files > 600 lines
- Merge 21 test targets into 6
- Add shared test helpers
- Populate empty e2e/ directory

## Phase 4: Build System Optimization (P2)

- Tighten SwiftLint rules incrementally
- Optimize CI pipeline (14 jobs -> 8)
- Build cache optimization

## Phase 5: Architecture Quality (P3)

- Extract protocol layer for Cache module
- Unify error handling
- Add performance benchmarks
- Generate API documentation

## Execution Log

| Date | Task | Status |
|------|------|--------|
| 2026-05-12 | 0.1 ComponentCatalogVC split | - |
| 2026-05-12 | 0.2 WebCacheDebugHandler split | - |
| 2026-05-12 | 0.3 PersistentManifestLoader split | - |
| 2026-05-12 | 0.4 WebResourceCacheManager split | - |
| 2026-05-12 | 0.5 ManifestStore split | - |
| 2026-05-12 | 0.6 BuiltinAITools split | - |
| 2026-05-12 | 0.7 AgentSchema split | - |
