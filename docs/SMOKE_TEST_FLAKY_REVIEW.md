# Smoke Tests Flaky Review

## Recent CI Runs

| Run ID | Status | Conclusion |
|--------|--------|------------|
| 26075787543 | queued | — |
| 26074735793 | completed | cancelled |
| 26074712384 | in_progress | — |
| 26074364865 | completed | cancelled |
| 25979044789 | completed | cancelled |

> Recent runs are mostly cancelled (likely from `cancel-in-progress: true` concurrency setting). No completed successful/failed runs in recent history.

## Known Flaky Areas

### 1. Smoke Tests (SuperAppUITests/SuperAppSmokeTests)

**Flakiness level**: High

**Root causes**:
- **Simulator availability** — CI uses `macos-15` runner which may not have the expected iOS runtime pre-installed. The workflow tries multiple device types (iPhone 16 Pro → iPhone SE 3rd gen) with fallbacks.
- **Simulator boot timing** — Race conditions between boot and test execution. Mitigated by 3x retry loop.
- **UI timing** — UITests depend on animation completion and rendering. Network-dependent UI can timeout.

**Mitigations already in place**:
- 3x retry loop with 5s cooldown between attempts
- `shutdown all` + `erase all` before each test attempt
- Destination probe loop trying multiple device types
- `continue-on-error: true` on UI fidelity job (not smoke tests)

### 2. Unit Tests (Simulator-dependent)

**Flakiness level**: Medium

**Root causes**:
- **Runtime not available** — Dynamic runtime detection with Python JSON parsing fallback
- **Simulator create/boot failures** — Handled with `use_simulator` flag and skip fallback
- **Test execution timeout** — 60-minute job timeout, but individual scheme hangs are possible

**Mitigations already in place**:
- 2x retry per scheme within the group
- Graceful skip when no simulator available
- Diagnostic capture on failure (simulator logs, device state)

### 3. UI Fidelity Tests

**Flakiness level**: Medium-High

**Root causes**:
- Same simulator issues as smoke tests
- Screenshot diff comparison sensitive to rendering differences across runs
- No reference images on first run (gracefully handled with baseline save)

**Mitigations**:
- 3x retry loop
- `continue-on-error: true` — does not block CI
- Configurable diff threshold (currently 5%)

## Recommendations

| Priority | Action | Effort |
|----------|--------|--------|
| HIGH | Pre-warm custom runner image with iOS 18.x runtime | Medium |
| HIGH | Add test timeout per scheme (e.g., 10 min max per scheme) | Low |
| MEDIUM | Mark smoke tests as `continue-on-error: true` temporarily | Low |
| MEDIUM | Add exponential backoff between retries (5s → 15s → 30s) | Low |
| LOW | Collect and aggregate flaky test statistics over time | Medium |
| LOW | Consider parallelizing unit test groups further | Low |

## Flaky Test Tracking

To track flakiness going forward:

```bash
# Check recent workflow runs with details
gh run list --workflow=CI --limit 20 --json status,conclusion,headBranch,createdAt

# Check specific run failures
gh run view <run-id> --log-failed

# Re-run only failed jobs
gh run rerun <run-id> --failed
```
