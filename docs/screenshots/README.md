# Screenshot Baselines

## Directory Structure
- `light/` — Light Mode screenshots (01-home through 08-about)
- `dark/` — Dark Mode screenshots (01-home through 08-about)

## How to Update Baselines

1. Boot simulator: `xcrun simctl boot "iPhone 16 Pro"`
2. Build and install app
3. Navigate to each page and capture screenshot
4. Save with naming convention: `NN-pagename.png`
5. Run diff: `bash tools/run-visual-regression.sh`

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

## Diff Rules
- Threshold: 5% pixel difference (configurable via `--threshold`)
- A screenshot "fails" if > 5% of pixels differ from baseline
- Known acceptable diffs are documented in `tools/known-diffs.md`

## Tools
- Capture: `bash tools/run-visual-regression.sh --capture`
- Diff: `bash tools/run-visual-regression.sh`
- Report: `/tmp/wbk-diff-report/index.html`
