# UI Fidelity Testing

Visual regression testing system for WebBridgeKit UI components.

## Directory Structure

```
docs/ui-fidelity/
├── references/          # Baseline reference screenshots (committed to git)
│   └── .gitkeep
└── diff-report/         # Generated diff reports (not committed)
    ├── index.html       # Visual HTML report
    └── results.json     # Machine-readable results
```

## How It Works

1. **Component Catalog** (`ComponentCatalogViewController.swift`) — Storybook-style page showing every UI component with design token annotations
2. **Screenshot Tests** (`UIFidelityTests.swift`) — XCUITest that launches the catalog and captures a screenshot per section
3. **Diff Tool** (`tools/diff-screenshots.sh`) — Compares actual screenshots against baselines, generates HTML report

## Running Tests

```bash
# Run UI fidelity screenshot tests
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme SuperApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:SuperAppUITests/UIFidelityTests \
  CODE_SIGNING_ALLOWED=NO

# Compare against baselines
./tools/diff-screenshots.sh docs/ui-fidelity/references build/screenshots/actual
```

## Updating Baselines

When intentional UI changes are made, update the reference images:

```bash
cp build/screenshots/actual/*.png docs/ui-fidelity/references/
git add docs/ui-fidelity/references/
git commit -m "chore(ui): update visual regression baselines"
```

## Threshold

Default threshold is **5%** pixel difference. Images exceeding this are marked as FAIL.

- **PASS**: Diff < 5% — acceptable rendering variance
- **FAIL**: Diff >= 5% — possible unintended visual change
- **NEW**: No matching reference — first run or new test
- **REMOVED**: Reference exists but no actual screenshot

## CI Integration

The `ui-fidelity` job in `.github/workflows/ci.yml`:
1. Builds the app on iOS simulator
2. Runs `UIFidelityTests` to capture screenshots
3. If reference images exist: runs diff comparison, fails if >5% threshold
4. If no references: saves current screenshots as baseline (first run)
5. Uploads all artifacts (screenshots + diff report)

## Catalog Sections (17 total)

| # | Section | Tokens Used |
|---|---------|-------------|
| 1 | Colors | ThemeTokens.Colors (22 tokens) |
| 2 | Typography | ThemeTokens.Typography (11 fonts) |
| 3 | Spacing | ThemeTokens.Spacing (6 values) |
| 4 | Corner Radius | ThemeTokens.CornerRadius (7 values) |
| 5 | Shadows | ThemeTokens.Shadows (5 presets) |
| 6 | Buttons | ThemeButton (3 styles x 2 states) |
| 7 | Badges | ThemeBadge (5 styles) |
| 8 | Cards | ThemeCard (3 variants) |
| 9 | Empty States | ThemeEmptyState (2 variants) |
| 10 | Gradient Views | ThemeGradientView (2 sizes) |
| 11 | Section Headers | ThemeSectionHeader (2 variants) |
| 12 | Message Cells | InboxMessageCell (unread/read) |
| 13 | Token Card | PushTokenCardCell style |
| 14 | Quick Actions | Home quick actions (4 items) |
| 15 | Filter Pills | Inbox filter pills (3 states) |
| 16 | FAB | Floating action button |
| 17 | Menu Items | Settings rows (3 styles) |
