# WebBridgeKit UI Redesign Rules

This document is the execution contract for the next UI rebuild. Use `docs/ui-redesign/design-tokens-v3.json` as the proposed source of truth, then sync the accepted values into:

- `docs/design-tokens.json`
- `Sources/Theme/ThemeTokens.swift`
- `docs/prototype/design-tokens.css`

## Product Direction

WebBridgeKit should look like a professional developer-tool iOS app:

- Quiet, precise, and useful.
- Dense enough for repeated daily use.
- Native-feeling without looking like an unfinished UIKit demo.
- Light/Dark parity.
- Lucide-only iconography.

Avoid:

- Huge icon/text scale.
- Emoji icons.
- Large decorative gradients.
- Floating card stacks.
- Card inside card.
- Page-specific custom colors.
- UIKit default blue everywhere.

## Token Rules

All feature UI must use semantic tokens. Do not use UIKit system colors directly in screens or cells.

Forbidden in feature UI:

```swift
UIColor(red:)
.systemBlue
.systemGray
.label
.secondaryLabel
.tertiaryLabel
.white
.black
```

Allowed exceptions:

- `UIColor.black.cgColor` only for shadow implementation if the token API requires a `CGColor`.
- System dynamic colors may exist only inside token implementation files.

## Color Usage

Use colors by role, not by taste:

| Role | Token |
|---|---|
| Screen background | `background` |
| Group/list background | `surface` |
| Cards | `cardBackground` |
| Primary text | `text` |
| Secondary text | `textSecondary` |
| Metadata/placeholder | `textTertiary` or `placeholder` |
| Separators | `separator` |
| Borders | `border` |
| Primary action / selected tab | `primary` |
| Connected/cache available | `success` |
| Token missing / pending / warning | `warning` |
| Failure/destructive | `error` |
| Informational status | `info` |
| Offline/disabled state | `offline` |

## Typography Rules

Use the v3 typography roles:

| UI | Token |
|---|---|
| Main screen title | `screenTitle`, 28pt |
| Compact page title | `compactTitle`, 24pt |
| Section title | `sectionTitle`, 17pt |
| Settings row title | `rowTitle`, 17pt |
| Card title | `cardTitle`, 16pt |
| Body text | `body`, 15pt |
| Metadata | `metadata`, 13pt |
| Tab label | `tabLabel`, 11pt |

Rules:

- No viewport-based font scaling.
- No negative letter spacing.
- Every label must define `numberOfLines`.
- Long titles use truncation or two-line card title, never overflow.
- Buttons and pills must not resize layout when text changes.

## Layout Contracts

These are hard constraints, not suggestions.

| Component | Contract |
|---|---|
| Screen horizontal inset | 16pt |
| Minimum tap target | 44x44pt |
| Tab bar height | 56pt + safe area |
| Tab icon | 23pt |
| Tab label | 11pt |
| Settings row | 52-60pt |
| Settings icon box | 32pt |
| Search field | 42pt |
| Filter pill | 32pt |
| Action tile | 72pt |
| Resource card | 92-116pt |
| Message cell | 72-96pt |
| Empty state icon | 48pt |
| Card radius | Max 12pt |
| Row radius | 10pt |

Any component that cannot fit inside this contract must be redesigned, not stretched.

## Required Components

Build these first, then rebuild pages with them. Pages should compose components; they should not invent new dimensions.

1. `WBKScreenScaffold`
2. `WBKSectionHeader`
3. `WBKListRow`
4. `WBKStatusBadge`
5. `WBKIconButton`
6. `WBKSearchField`
7. `WBKFilterPill`
8. `WBKEmptyState`
9. `WBKActionTile`
10. `WBKResourceCard`
11. `WBKMessageCell`

Each component must support:

- Light mode.
- Dark mode.
- Long Chinese text.
- Long English text without spaces.
- Dynamic Type Large.
- Disabled state if interactive.
- Loading or skeleton state where relevant.

## Page Redesign Targets

### Home

Goal: control console, not card playground.

Required structure:

1. Compact server status block.
2. Four action tiles.
3. Favorites / recent resources list.
4. Cache and connection metadata shown as small badges.

Rules:

- No large empty cards.
- Resource cards must fit 92-116pt.
- Metadata must be visible and useful: domain, cache status, last update.
- Primary action should be obvious but not visually dominant across the whole screen.

### Inbox

Required structure:

1. Compact title row.
2. 42pt search field.
3. 32pt filter pills.
4. Message list or actionable empty state.

Rules:

- Empty state must include a primary action.
- Message cells must show unread state without huge blue fills.
- Filter pills must not wrap awkwardly on narrow screens.

### Discover

Required structure:

1. Tool/resource sections.
2. Compact cards or rows.
3. Clear unavailable/offline/error states.

Rules:

- No marketing-style hero.
- No decorative gradient panels.
- Tool cards must show purpose and state.

### Settings

Required structure:

1. Grouped settings sections.
2. 52-60pt rows.
3. 32pt icon boxes.
4. Destructive actions use error styling.

Rules:

- Settings rows must not use oversized text.
- Chevron must align consistently.
- Section labels use metadata scale.

## Layout Guard Requirements

Add or update XCUITests to catch layout failures.

Required checks:

```swift
XCTAssertGreaterThan(element.frame.width, 0)
XCTAssertGreaterThan(element.frame.height, 0)
XCTAssertTrue(screen.intersects(element.frame))
XCTAssertGreaterThanOrEqual(button.frame.width, 44)
XCTAssertGreaterThanOrEqual(button.frame.height, 44)
```

Also verify:

- The last item in every scroll view can be fully scrolled into view.
- Tab bar does not overlap scroll content.
- Navigation title does not overlap status bar or actions.
- Search field placeholder is not clipped.
- Filter pills fit on 375pt width.
- Empty state action is visible above the tab bar.

## Screenshot Matrix

Required before handoff:

| Mode | Screens |
|---|---|
| Light | Home, Inbox, Discover, Settings, Component Catalog |
| Dark | Home, Inbox, Discover, Settings, Component Catalog |
| States | Empty, Error, Loading, Permission Denied, Offline |
| Sizes | iPhone SE width, iPhone 16 Pro, Pro Max |
| Text stress | Long Chinese, long English no spaces, Dynamic Type Large |

Save screenshots under:

```text
docs/screenshots/ui-redesign/
```

## Automated Validation

Run:

```bash
bash scripts/services.sh verify
xcodebuild build -workspace WebBridgeKit.xcworkspace -scheme SuperApp -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/wbk-dd-ui
bash scripts/scan-crash-logs.sh --json
rg 'UIColor\(red:|\.systemBlue|\.systemGray|\.label|\.secondaryLabel|\.tertiaryLabel|\.white|\.black' Sources/ SuperApp/ AppTemplate/Sources --glob '*.swift'
```

Acceptance:

- Services: 3/3 healthy.
- Build succeeds.
- Business-code warnings: 0.
- Crash scan: 0 current crashes.
- Hardcoded color scan: 0 outside token implementation.
- Release bundle does not gain large assets.

## Human Acceptance

Reject the redesign if any of these are visible:

- Text clipped unexpectedly.
- Button label overflows.
- Icon or label hidden behind safe area.
- Tab bar overlaps content.
- Card heights jump when content changes.
- Empty state has no action.
- Dark mode contrast feels weaker than light mode.
- One page looks like a different product from the others.
- Any emoji icon appears in production UI.
