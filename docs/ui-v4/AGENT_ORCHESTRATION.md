# UI v4 Agent Orchestration

This document defines how to run the UI v4 refactor with multiple agents without creating a tangled PR.

## Recommended approach

Use one orchestrator and six specialist agents.

```text
Orchestrator
  ├─ Baseline + Automation Agent
  ├─ App Shell + Components Agent
  ├─ Web Cache Agent
  ├─ JSBridge Agent
  ├─ Token Push Agent
  ├─ Debug DeepLink Agent
  └─ Review + Release Agent
```

The orchestrator owns sequencing, merge order, scope control, and final verification.

## Branching model

Preferred branch:

```text
codex/ui-v4-refactor
```

Specialist agents can use temporary branches:

```text
codex/ui-v4-baseline
codex/ui-v4-shell
codex/ui-v4-web-cache
codex/ui-v4-jsbridge
codex/ui-v4-token-push
codex/ui-v4-debug-links
codex/ui-v4-release-gate
```

Merge order:

1. Baseline + Automation
2. App Shell + Components
3. Web Cache
4. JSBridge
5. Token/Push
6. Debug + Deep Link
7. Visual/Release gate
8. Legacy cleanup

Do not merge two feature agents at once if both touched:

- `project.yml`
- app root entry point
- `TabBarController`
- `docs/design-tokens.json`
- shared components
- screenshot scripts
- CI files

## Shared contract

Every agent must read these first:

1. `AGENTS.md`
2. `docs/ui-v4/README.md`
3. `docs/ui-v4/INFORMATION_ARCHITECTURE.md`
4. `docs/ui-v4/SCREEN_SPECS.md`
5. `docs/ui-v4/AUTOMATION_MATRIX.md`
6. `docs/ui-v4/AGENT_TASKS.md`
7. `docs/plans/2026-06-02-ui-v4-refactor.md`

Every agent must obey:

- No hardcoded feature colors.
- Lucide icons only.
- 44 pt minimum tap target.
- iPhone SE layout must pass.
- No nested cards.
- No new debug prints.
- No unrelated refactors.
- No changes to core cache/bridge/push behavior unless required by a failing test.

## Agent 0: Orchestrator

Role:

- Owns plan, sequence, review, and final release readiness.

Allowed files:

- All docs
- CI/scripts
- Small integration fixes

Responsibilities:

- Create branch.
- Keep task board updated.
- Assign tasks.
- Review each specialist branch.
- Resolve conflicts.
- Run final verification.

Required commands:

```bash
bash scripts/services.sh verify
swiftlint --quiet
bash tools/ci-lint.sh
bash tools/run-ui-v4-regression.sh
bash tools/run-release-gate.sh
bash scripts/scan-crash-logs.sh --json
```

Handoff must include:

- Commit list
- Verification table
- Remaining manual checks
- Screenshot/report paths

## Agent 1: Baseline + Automation Agent

Primary task:

- Execute Milestone 0 and Task 0 in `docs/ui-v4/AGENT_TASKS.md`.

Owns:

- `docs/ui-v4/BASELINE_AUDIT.md`
- `tools/run-ui-v4-regression.sh`
- `tools/run-cache-regression.sh`
- `tools/run-jsbridge-regression.sh`
- `tools/run-release-gate.sh`
- `tools/run-real-device-smoke.sh`
- `build/reports/` output format

Must not:

- Redesign UI.
- Touch feature screens except to add identifiers needed for baseline capture.

Acceptance:

- Baseline screenshots exist.
- Regression script shells run.
- Reports are generated.
- Existing checks are documented.

Prompt to give agent:

```text
Read AGENTS.md and docs/ui-v4/*.md. Execute Milestone 0 from docs/plans/2026-06-02-ui-v4-refactor.md. Create the baseline audit, screenshot folders, and regression script entrypoints. Do not redesign UI. Provide changed paths, commands run, report paths, and remaining gaps.
```

## Agent 2: App Shell + Components Agent

Primary task:

- Execute Milestone 1.

Owns:

- `SuperApp/Sources/Views/AppShell/`
- `SuperApp/Sources/Views/Components/`
- `SuperAppUITests/AppShellTests.swift`
- `SuperAppUITests/ComponentCatalogTests.swift`

May modify:

- app root entry point
- `SuperApp/Sources/Controllers/Tab/TabBarController.swift`
- `project.yml` only if required

Must not:

- Implement Web Cache, JSBridge, Token/Push, Debug, or Deep Link feature logic.
- Delete old tabs before parity.

Acceptance:

- Five-tab shell launches.
- Shared components render.
- Component tests pass.
- iPhone SE layout has no tab/content overlap.

Prompt:

```text
Read docs/ui-v4/SCREEN_SPECS.md and docs/plans/2026-06-02-ui-v4-refactor.md. Implement Milestone 1 only: AppShell and shared components. Use placeholders for feature tabs. Keep old UI reachable if needed. Add AppShellTests and ComponentCatalogTests. Run ci-lint and targeted UI tests. Do not touch feature business logic.
```

## Agent 3: Web Cache Agent

Primary task:

- Execute Task 2.1.

Owns:

- `SuperApp/Sources/Views/WebCache/`
- `SuperAppUITests/CacheFlowTests.swift`

May use:

- `SuperApp/Sources/ViewModels/CacheDashboardViewModel.swift`
- `Sources/Cache/`
- `Sources/Handlers/CacheDebug/`
- `Sources/Handlers/ManifestLoader/`

Must not:

- Rewrite cache core without a failing test.
- Touch JSBridge Lab, Token/Push, Debug Center, or Deep Link UI.

Acceptance:

- C-001 through C-015 are covered or explicitly documented as manual/semi-automated.
- Cache cleanup has confirmation.
- Offline missing-cache state is clear.
- Manifest/resource errors are visible.

Prompt:

```text
Implement the UI v4 Web Cache module only. Read docs/ui-v4/AUTOMATION_MATRIX.md cases C-001 through C-015 and docs/ui-v4/SCREEN_SPECS.md Web Cache sections. Create WebCache views and CacheFlowTests. Use existing cache and manifest code as adapters; do not rewrite core cache behavior unless a failing test proves a bug. Run run-cache-regression and crash scan.
```

## Agent 4: JSBridge Agent

Primary task:

- Execute Task 2.2.

Owns:

- `SuperApp/Sources/Views/BridgeLab/`
- `SuperAppUITests/JSBridgeLabTests.swift`

May use:

- `Sources/Core/WebJavaScriptBridge.swift`
- `Resources/WebBridge.js`
- `Sources/Handlers/`
- `Sources/Bridge/Error/BridgeError.swift`
- `test_resources/js_bridge_test.html`

Must not:

- Change handler behavior without unit tests.
- Touch Web Cache UI except shared navigation points.

Acceptance:

- B-001 through B-012 are covered or documented.
- Unknown command, invalid params, timeout, success, and permission states render.
- Results are copyable.
- Errors link to Debug logs.

Prompt:

```text
Implement the UI v4 JSBridge Lab only. Read docs/ui-v4/AUTOMATION_MATRIX.md cases B-001 through B-012 and docs/ui-v4/SCREEN_SPECS.md Bridge Lab section. Create BridgeLab views and JSBridgeLabTests. Use existing WebJavaScriptBridge and handlers. Run run-jsbridge-regression and crash scan.
```

## Agent 5: Token Push Agent

Primary task:

- Execute Task 3.1.

Owns:

- `SuperApp/Sources/Views/TokenPush/`
- `SuperAppUITests/TokenPushTests.swift`

May use:

- `SuperApp/Sources/Managers/TokenManager.swift`
- `SuperApp/Sources/Managers/PassphraseManager.swift`
- `SuperApp/Sources/Managers/APIKeyManager.swift`
- `SuperApp/Sources/Managers/AccessTokenManager.swift`
- `SuperApp/Sources/Push/`

Must not:

- Leak raw tokens in logs, diagnostics, screenshots, or copy actions by default.
- Treat APNs delivery as fully automated.

Acceptance:

- T-001 through T-009 covered.
- P-001 through P-008 covered or marked manual where appropriate.
- Redaction is enforced.

Prompt:

```text
Implement the UI v4 Token/Push module only. Read docs/ui-v4/AUTOMATION_MATRIX.md Token and Push cases. Create TokenPush views and TokenPushTests. Keep secrets redacted by default. Mark APNs delivery manual/device-only. Run targeted UI tests and crash scan.
```

## Agent 6: Debug DeepLink Agent

Primary task:

- Execute Tasks 3.2 and 3.3.

Owns:

- `SuperApp/Sources/Views/DebugCenter/`
- `SuperApp/Sources/Views/DeepLink/`
- `SuperAppUITests/DebugCenterFlowTests.swift`
- `SuperAppUITests/DeepLinkFlowTests.swift`

May use:

- `SuperApp/Sources/Controllers/Debug/`
- `Sources/Infrastructure/Debug/`
- `scripts/scan-crash-logs.sh`
- `SuperApp/Sources/AppDelegate.swift`
- `SuperApp/Sources/Managers/CommandHandler.swift`
- `Sources/CommandParser/`

Must not:

- Change command routing behavior without tests.
- Export secrets in diagnostics.

Acceptance:

- D-001 through D-010 covered.
- L-001 through L-008 covered.
- Export diagnostics redacts secrets.
- Deep-link failures are structured and visible.

Prompt:

```text
Implement UI v4 Debug Center and Deep Link modules only. Read docs/ui-v4/AUTOMATION_MATRIX.md Debug and Deep Link cases. Create views and UI tests. Use existing debug, crash scan, AppDelegate, CommandHandler, and CommandParser code as adapters. Run targeted UI tests, ci-lint, and crash scan.
```

## Agent 7: Review + Release Agent

Primary task:

- Execute Milestone 4 and 5 after feature modules merge.

Owns:

- `SuperAppUITests/ScreenshotCaptureTests.swift`
- `tools/capture-screenshots.sh`
- `tools/visual-checks.sh`
- `tools/run-visual-regression.sh`
- `tools/run-ui-v4-regression.sh`
- `tools/run-release-gate.sh`
- `docs/RELEASE_CHECKLIST.md`
- `docs/APP_SIZE_BUDGET.md`

Must not:

- Redesign feature screens unless fixing a failed acceptance criterion.

Acceptance:

- Light/Dark screenshots for all primary modules.
- iPhone SE and iPhone 16 Pro screenshots exist.
- Release gate passes.
- Crash scan total is 0.
- Legacy UI is removed or quarantined only after parity.

Prompt:

```text
Act as the UI v4 review and release agent. After all feature agents merge, expand screenshot capture, visual regression, release gate, and final docs. Do not redesign feature screens unless required by failed acceptance criteria. Run final verification and produce a release-readiness report.
```

## Conflict resolution protocol

When conflicts occur:

1. Preserve `docs/design-tokens.json` unless the task explicitly owns token changes.
2. Preserve shared component APIs once Agent 2 merges.
3. Feature agents should adapt to shared components, not fork them.
4. `project.yml` changes must be merged by the orchestrator.
5. CI/script changes must be reviewed by Agent 1 or Agent 7.

## Review checklist for every agent PR

- [ ] Scope matches assigned task.
- [ ] No unrelated refactor.
- [ ] No hardcoded feature colors.
- [ ] Lucide icons only.
- [ ] Accessibility identifiers added.
- [ ] iPhone SE safe.
- [ ] Light/Dark safe.
- [ ] Tests added or updated.
- [ ] Crash scan result included.
- [ ] Handoff includes commands and evidence.

## Final orchestration checklist

- [ ] Baseline branch merged.
- [ ] Shell/components branch merged.
- [ ] Web Cache branch merged.
- [ ] JSBridge branch merged.
- [ ] Token/Push branch merged.
- [ ] Debug/Deep Link branch merged.
- [ ] Screenshot/visual branch merged.
- [ ] Release gate branch merged.
- [ ] Legacy UI cleanup merged.
- [ ] CI green.
- [ ] Real-device smoke completed.
