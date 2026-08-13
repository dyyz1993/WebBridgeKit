# Screenshot Baselines

## Directory Structure
- `light/` — Light Mode screenshots (01-home through 08-about)
- `dark/` — Dark Mode screenshots (01-home through 08-about)
- `ui-redesign/` — Reviewed SuperApp baselines for the current three-tab information architecture

## How to Update Baselines

1. Boot simulator: `xcrun simctl boot "iPhone 16 Pro"`
2. Run `bash tools/capture-screenshots.sh --build`
3. Review all six images under `build/screenshots/ui-redesign/`
4. Copy accepted images into `docs/screenshots/ui-redesign/`
5. Run `bash tools/run-visual-regression.sh`

The visual gate rejects a baseline directory that is also used as the actual directory.

## Naming Convention
| Prefix | Page |
|--------|------|
| 01 | Home |
| 02 | Settings |
| 03 | Inbox (empty) |
| 04 | Discover |
| 05 | Debug Panel |
| 06 | Cache Dashboard |
| 07 | WebView |
| 08 | About |
| 09 | Component Catalog |
| 10 | Error State |
| 11 | Permission State |

The current `ui-redesign/` suite is intentionally limited to:

| File | Page |
|---|---|
| `01-home-light.png` | Home, light |
| `02-inbox-light.png` | Inbox, light |
| `03-settings-light.png` | Settings, light |
| `04-home-dark.png` | Home, dark |
| `05-inbox-dark.png` | Inbox, dark |
| `06-settings-dark.png` | Settings, dark |

## Diff Rules
- Threshold: 5% pixel difference (configurable via `--threshold`)
- A screenshot "fails" if > 5% of pixels differ from baseline
- Known acceptable diffs are documented in `tools/known-diffs.md`

## Tools
- Capture: `bash tools/capture-screenshots.sh --build`
- Capture and diff: `bash tools/run-visual-regression.sh --capture`
- Diff: `bash tools/run-visual-regression.sh`
- Report: `/tmp/wbk-diff-report/index.html`
