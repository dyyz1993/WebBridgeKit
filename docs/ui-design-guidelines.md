# WebBridgeKit UI Design Guidelines

> Version 1.0 | Last Updated: 2026-05-08
>
> Status: **Mandatory** — All new UI code MUST comply. Existing code SHOULD migrate during refactoring.

---

## Table of Contents

1. [Design Tokens](#1-design-tokens)
   - [Color Tokens](#11-color-tokens)
   - [Typography Tokens](#12-typography-tokens)
   - [Spacing Tokens](#13-spacing-tokens)
   - [Corner Radius Tokens](#14-corner-radius-tokens)
   - [Animation Tokens](#15-animation-tokens)
2. [Component Specifications](#2-component-specifications)
   - [BaseCell Architecture](#21-basecell-architecture)
   - [Button (ThemeButton)](#22-button-themebutton)
   - [Card (ThemeCard)](#23-card-themecard)
   - [Badge (ThemeBadge)](#24-badge-themebadge)
   - [Navigation Bar](#25-navigation-bar)
   - [Tab Bar](#26-tab-bar)
   - [Section Header](#27-section-header)
   - [Empty State](#28-empty-state)
   - [Gradient View](#29-gradient-view)
3. [Layout Standards](#3-layout-standards)
4. [Code Standards](#4-code-standards)
5. [Naming Conventions](#5-naming-conventions)
6. [Migration Guide](#6-migration-guide)

---

## 1. Design Tokens

All tokens are defined in `Sources/Theme/ThemeManager.swift`. **Never hardcode visual values** — always reference tokens.

### 1.1 Color Tokens

Reference: `ThemeColors.current` (defined at `ThemeManager.swift:90`)

#### Brand Colors

| Token | Property | Usage | Light Default | Dark Default |
|-------|----------|-------|---------------|--------------|
| `primary` | `.primary` | CTA, links, active states | `systemBlue` | `systemBlue` |
| `secondary` | `.secondary` | Secondary actions, muted elements | `systemGray` | `systemGray` |

#### Text Colors

| Token | Property | Usage |
|-------|----------|-------|
| `text` | `.text` | Primary body text, titles |
| `textSecondary` | `.textSecondary` | Subtitles, descriptions, metadata |

#### Background Colors

| Token | Property | Usage |
|-------|----------|-------|
| `background` | `.background` | Screen-level background |
| `surface` | `.surface` | Elevated surface, grouped background |
| `cardBackground` | `.cardBackground` | Card container background |

#### Status Colors

| Token | Property | Usage |
|-------|----------|-------|
| `success` | `.success` | Success states, positive feedback |
| `warning` | `.warning` | Caution, pending states |
| `error` | `.error` | Error states, destructive actions |
| `info` | `.info` | Informational, neutral highlights |

#### UI Element Colors

| Token | Property | Usage |
|-------|----------|-------|
| `border` | `.border` | View borders, separators |
| `divider` | `.divider` | Section dividers, thin lines |
| `navigationBarBackground` | `.navigationBarBackground` | Nav bar fill |
| `navigationBarTitle` | `.navigationBarTitle` | Nav bar title text |
| `tabBarBackground` | `.tabBarBackground` | Tab bar fill |
| `badgeBackground` | `.badgeBackground` | Badge fill (default style) |
| `badgeText` | `.badgeText` | Badge text (default style) |
| `gradientStart` | `.gradientStart` | Gradient start color |
| `gradientEnd` | `.gradientEnd` | Gradient end color |
| `fabBackground` | `.fabBackground` | FAB button fill |

#### Rules

```
// ✅ CORRECT
label.textColor = ThemeColors.current.text
view.backgroundColor = ThemeColors.current.cardBackground

// ❌ FORBIDDEN
label.textColor = .label
view.backgroundColor = .white
view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
```

> **Enforcement**: Code review MUST reject any hardcoded `UIColor` outside of `ThemeColors` definition. The ~168 existing hardcoded colors should be migrated incrementally.

---

### 1.2 Typography Tokens

Two typography systems exist. Use **`ThemeTypography.current`** for new code. `ThemeFonts.default` is legacy.

#### Standard Tokens (`ThemeTypography.current`)

| Token | Property | Size | Weight | Usage |
|-------|----------|------|--------|-------|
| Hero | `.largeTitle` | 28pt | Bold | Screen hero titles |
| Title1 | `.title1` | 22pt | Bold | Page section titles |
| Title2 | `.title2` | 20pt | Semibold | Section headers |
| Headline | `.headline` | 17pt | Semibold | Cell titles, emphasis |
| Body | `.body` | 15pt | Regular | Body text, descriptions |
| Callout | (use `.body` + weight `.medium`) | 15pt | Medium | Callout text |
| Caption1 | `.caption1` | 13pt | Regular | Secondary info, timestamps |
| Caption2 | `.caption2` | 11pt | Regular | Micro labels, footnotes |
| Button | (see `ThemeFonts.default.button`) | 16pt | Medium | Button titles |

#### Approved Font Sizes

Only these sizes are permitted (via `ThemeTypography` tokens):

```
28pt, 22pt, 20pt, 17pt, 15pt, 13pt, 11pt
```

#### Rules

```
// ✅ CORRECT — use typography tokens
label.font = ThemeTypography.current.largeTitle
label.font = ThemeTypography.current.body

// ❌ FORBIDDEN — hardcoded font sizes
label.font = .systemFont(ofSize: 16, weight: .medium)
label.font = UIFont(name: "Helvetica", size: 14)
```

> All typography tokens support Dynamic Type via `UIFontMetrics.default.scaledFont(for:)`.

---

### 1.3 Spacing Tokens

Reference: `ThemeSpacing.default` (defined at `ThemeManager.swift:247`)

| Token | Property | Value | 4pt Grid | Usage |
|-------|----------|-------|-----------|-------|
| `xs` | `.xs` | 4pt | 1x | Tight gaps (icon-to-text, badge padding) |
| `sm` | `.sm` | 8pt | 2x | Inner padding, sibling spacing |
| `md` | `.md` | 16pt | 4x | Standard padding, section inner margin |
| `lg` | `.lg` | 24pt | 6x | Section gap, card padding |
| `xl` | `.xl` | 32pt | 8x | Screen edge margin, hero spacing |

#### Usage

```
// ✅ CORRECT
make.top.equalToSuperview().offset(ThemeSpacing.default.md)
make.leading.trailing.equalToSuperview().inset(ThemeSpacing.default.lg)

// ❌ FORBIDDEN
make.top.equalToSuperview().offset(16)
make.leading.equalToSuperview().offset(20)
```

#### Extension Recommendations

The current system lacks `xxl` (24pt) and `xxxl` (32pt). The `lg` (24pt) and `xl` (32pt) already cover these. For finer granularity, add:

```swift
// Proposed addition to ThemeSpacing
public let xxl: CGFloat = 24   // lg currently = 24, consider adding xxl = 20
public let xxxl: CGFloat = 32  // xl currently = 32, consider adding xxxl = 40
```

---

### 1.4 Corner Radius Tokens

Reference: `ThemeCornerRadius.default` (defined at `ThemeManager.swift:273`)

| Token | Property | Value | Usage |
|-------|----------|-------|-------|
| `sm` | `.sm` | 4pt | Badges, small tags, chips |
| `md` | `.md` | 8pt | Buttons, small cards, inputs |
| `lg` | `.lg` | 16pt | Cards, modals, cells |
| `full` | `.full` | 999pt (50%) | Avatars, circular icons |

#### Missing Token

The current system does not define `xl` (12pt). Add for cell/input use:

```swift
public let xl: CGFloat = 12  // Cells, input fields, medium containers
```

#### Rules

```
// ✅ CORRECT
view.layer.cornerRadius = ThemeCornerRadius.default.md

// ❌ FORBIDDEN
view.layer.cornerRadius = 8
view.layer.cornerRadius = 12
```

---

### 1.5 Animation Tokens

Reference: `ThemeAnimation` (defined at `ThemeManager.swift:296`)

| Token | Value | Usage |
|-------|-------|-------|
| `standardDuration` | 0.25s | Standard transitions |
| `springDuration` | 0.3s | Spring animations |
| `slowDuration` | 0.5s | Slow, deliberate transitions |
| `springDamping` | 0.8 | Spring damping ratio |

```
ThemeAnimation.standard { view.alpha = 1 }
ThemeAnimation.spring { view.transform = .identity }
```

---

## 2. Component Specifications

All theme components live in `Sources/Theme/Components/`.

### 2.1 BaseCell Architecture

**Problem**: 10+ Cell classes with no shared base class, duplicated layout code.

**Solution**: Introduce `BaseTableViewCell` and `BaseCollectionViewCell`.

```swift
// Sources/Theme/Components/BaseTableViewCell.swift
import UIKit
import SnapKit

public class BaseTableViewCell: UITableViewCell {

    public static var reuseIdentifier: String { String(describing: self) }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = ThemeColors.current.background
        contentView.backgroundColor = ThemeColors.current.background
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Override to add subviews. Called during init.
    open func setupUI() { }

    /// Override to set SnapKit constraints. Called during init.
    open func setupConstraints() { }

    /// Override to configure cell with data.
    open func configure(with data: Any) { }

    public override func prepareForReuse() {
        super.prepareForReuse()
        resetState()
    }

    /// Override to clear all reusable state.
    open func resetState() { }
}
```

#### Cell Layout Standard

```
┌──────────────────────────────────────────┐
│ ← lg (24pt) →  Content  ← lg (24pt) → │
│                                          │
│  ┌──────┐  Title (headline)              │
│  │ Icon │  Subtitle (caption1, secondary)│
│  │ 40pt │  ─────────────────────────     │
│  └──────┘  Accessory                     │
│                                          │
│  ↕ sm (8pt) between elements             │
│  ↕ md (16pt) section internal padding    │
│  ↕ lg (24pt) top/bottom cell padding     │
└──────────────────────────────────────────┘
```

#### Cell Rules

- **Every cell MUST inherit from `BaseTableViewCell`** (or `BaseCollectionViewCell`)
- **One cell per file** — file name matches class name (e.g., `CacheAppCell.swift` → `CacheAppCell`)
- **Icon size**: 40×40pt standard, 32×32pt compact
- **Minimum cell height**: 56pt
- **Separator**: use `ThemeColors.current.divider`, not default separator
- **`prepareForReuse()`**: MUST call `resetState()` and clear all labels/images/callbacks

---

### 2.2 Button (ThemeButton)

Reference: `Sources/Theme/Components/ThemeButton.swift`

| Property | Value |
|----------|-------|
| Corner radius | `ThemeCornerRadius.default.md` (8pt) |
| Font | 15pt medium (via `ThemeFonts.default.button` recommended) |
| Min tap target | **44×44pt** |
| Height | 44pt standard |
| Horizontal padding | 16pt (lg) |

#### Styles

| Style | Background | Text Color | Border |
|-------|-----------|------------|--------|
| `primary` | `ThemeColors.current.primary` | `.white` | none |
| `secondary` | `ThemeColors.current.surface` | `ThemeColors.current.text` | `border` (1pt) |
| `ghost` | `.clear` | `ThemeColors.current.primary` | `primary` 30% alpha (1pt) |

#### Rules

- **Minimum touch area**: 44×44pt (Apple HIG). If visual size < 44pt, use `pointInside:withEvent:` or extend hit area.
- **Forbidden**: `imageEdgeInsets`, `titleEdgeInsets` (deprecated). Use `configuration` API (iOS 15+) or subclass layout.
- **Icon buttons**: Use `LucideIcon.templateImage(pointSize:)` for icon buttons.

---

### 2.3 Card (ThemeCard)

Reference: `Sources/Theme/Components/ThemeCard.swift`

| Property | Value |
|----------|-------|
| Corner radius | `ThemeCornerRadius.default.lg` (16pt) |
| Background | `ThemeColors.current.cardBackground` |
| Shadow offset | (0, 4) |
| Shadow radius | 12 |
| Shadow opacity | 0.08 |
| Shadow color | `.black` |
| Inner padding | `ThemeSpacing.default.md` (16pt) |

#### Usage

```swift
let card = ThemeCard()
addSubview(card)
card.snp.makeConstraints { make in
    make.leading.trailing.equalToSuperview().inset(ThemeSpacing.default.md)
    make.top.equalToSuperview().offset(ThemeSpacing.default.sm)
}
```

---

### 2.4 Badge (ThemeBadge)

Reference: `Sources/Theme/Components/ThemeBadge.swift`

| Property | Value |
|----------|-------|
| Corner radius | `ThemeCornerRadius.default.sm` (4pt) |
| Font | 10pt bold |
| Padding (vertical) | 2pt |
| Padding (horizontal) | 6pt |
| Min height | ~14pt |

#### Styles

| Style | Background | Text Color |
|-------|-----------|------------|
| `default` | `badgeBackground` | `badgeText` |
| `success` | `success` 12% alpha | `success` |
| `warning` | `warning` 12% alpha | `warning` |
| `error` | `error` 12% alpha | `error` |
| `info` | `info` 12% alpha | `info` |

---

### 2.5 Navigation Bar

Configured via `ThemeManager.applyMode(_:to:)` at `ThemeManager.swift:51`.

| Property | Value |
|----------|-------|
| Background | `ThemeColors.current.navigationBarBackground` |
| Title color | `ThemeColors.current.navigationBarTitle` |
| Style | Opaque (`configureWithOpaqueBackground`) |
| Tint color | `ThemeColors.current.primary` |
| Applies to | `standardAppearance` + `scrollEdgeAppearance` |

#### Rules

- Use `UINavigationBarAppearance` for all customization
- Do NOT set title color via `navigationBar.titleTextAttributes` directly — use ThemeManager
- Back button icon: system default or custom with `primary` tint

---

### 2.6 Tab Bar

Configured via `ThemeManager.applyMode(_:to:)` at `ThemeManager.swift:70`.

| Property | Value |
|----------|-------|
| Background | `ThemeColors.current.tabBarBackground` |
| Style | Opaque (`configureWithOpaqueBackground`) |
| Tint color | `ThemeColors.current.primary` |
| Applies to | `standardAppearance` + `scrollEdgeAppearance` (iOS 15+) |

#### Rules

- Tab icons: always use template rendering mode
- Tab titles: system default font with `primary` tint for selected state
- Badge: use system tab badge (`.badgeValue`), do NOT custom-overlay

---

### 2.7 Section Header

Reference: `Sources/Theme/Components/ThemeSectionHeader.swift`

| Element | Style |
|---------|-------|
| Title font | `ThemeTypography.current.title2` (20pt semibold) |
| Title color | `ThemeColors.current.text` |
| Action font | `ThemeTypography.current.caption1` (13pt regular) |
| Action color | `ThemeColors.current.primary` |

---

### 2.8 Empty State

Reference: `Sources/Theme/Components/ThemeEmptyState.swift`

| Element | Style |
|---------|-------|
| Icon size | 64×64pt, pointSize 48 |
| Icon tint | `ThemeColors.current.textSecondary` |
| Title font | `ThemeTypography.current.title2` |
| Title color | `ThemeColors.current.text` |
| Description font | `ThemeTypography.current.body` |
| Description color | `ThemeColors.current.textSecondary` |
| Icon-to-title gap | `ThemeSpacing.default.md` (16pt) |
| Title-to-desc gap | `ThemeSpacing.default.sm` (8pt) |

---

### 2.9 Gradient View

Reference: `Sources/Theme/Components/ThemeGradientView.swift`

| Property | Value |
|----------|-------|
| Corner radius | `ThemeCornerRadius.default.lg` (16pt) |
| Start point | (0, 0) top-left |
| End point | (1, 1) bottom-right |
| Colors | `gradientStart` → `gradientEnd` |
| `clipsToBounds` | `true` |

---

## 3. Layout Standards

### 3.1 Layout Engine

**SnapKit is the ONLY approved layout system.** All 20 existing files already use SnapKit.

```
// ✅ CORRECT
view.snp.makeConstraints { make in
    make.top.equalToSuperview().offset(ThemeSpacing.default.md)
    make.leading.trailing.equalToSuperview()
    make.height.equalTo(44)
}

// ❌ FORBIDDEN
NSLayoutConstraint.activate([
    view.topAnchor.constraint(equalTo: superview.topAnchor, constant: 16)
])
view.translatesAutoresizingMaskIntoConstraints = false

// ❌ FORBIDDEN — autoresizing mask
view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
```

### 3.2 Section Spacing

| Context | Spacing |
|---------|---------|
| Between sections | `ThemeSpacing.default.lg` (24pt) |
| Section header to first item | `ThemeSpacing.default.sm` (8pt) |
| Between items in section | `ThemeSpacing.default.xs` (4pt) |
| Last item to next section header | `ThemeSpacing.default.md` (16pt) |

### 3.3 List / Collection Padding

| Edge | Value |
|------|-------|
| Left | `ThemeSpacing.default.md` (16pt) |
| Right | `ThemeSpacing.default.md` (16pt) |
| Top | `ThemeSpacing.default.lg` (24pt) |
| Bottom | `ThemeSpacing.default.xl` (32pt) |

### 3.4 Safe Area

```
// ✅ Always respect safe area for top-level content
make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)

// For scrollable content, use contentInset instead of safe area constraints
scrollView.contentInsetAdjustmentBehavior = .automatic
```

### 3.5 UITableView Configuration

```swift
tableView.separatorInset = UIEdgeInsets(
    top: 0, left: ThemeSpacing.default.lg,
    bottom: 0, right: 0
)
tableView.backgroundColor = ThemeColors.current.background
tableView.separatorColor = ThemeColors.current.divider
```

---

## 4. Code Standards

### 4.1 Cell Definition

- **One cell per file** — NO inline cell classes in ViewController files
- File location: `Sources/Views/` or `Sources/Views/Cells/`
- Filename = class name (e.g., `RuleHeaderCell.swift` → `class RuleHeaderCell`)

```
// ❌ FORBIDDEN — cells defined inside ViewController files
// WebCacheDebugPanelViewController+Cells.swift contains 5 inline cells
// These MUST be extracted to separate files
```

### 4.2 Deprecated API Avoidance

```
// ❌ FORBIDDEN (deprecated iOS 15+)
button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)

// ✅ CORRECT — use UIButton.Configuration
var config = UIButton.Configuration.plain()
config.imagePadding = 8
config.titlePadding = 4
button.configuration = config
```

### 4.3 accessibilityIdentifier Naming

Format: `{screen}_{component}_{detail}`

```
// Examples
"cache_list_app_cell"           // Cell in cache list
"cache_detail_resource_cell"    // Cell in cache detail
"settings_theme_segmented"      // Segmented control in settings
"debug_panel_add_rule_button"   // Button in debug panel
"history_empty_state_view"      // Empty state in history
```

Rules:
- All lowercase, snake_case
- Every interactive element MUST have an `accessibilityIdentifier`
- Every cell MUST have an `accessibilityIdentifier` set in `configure(with:)`

### 4.4 prepareForReuse

Every cell subclass MUST override `resetState()` (via `BaseTableViewCell`) or `prepareForReuse()`:

```swift
public override func resetState() {
    iconImageView.image = nil
    titleLabel.text = nil
    subtitleLabel.text = nil
    badge.isHidden = true
    onAction = nil
    accessoryType = .none
    isUserInteractionEnabled = true
    alpha = 1
}
```

### 4.5 Image Rendering

```
// ✅ CORRECT — always template for icons
imageView.image = icon.templateImage(pointSize: 20)
imageView.tintColor = ThemeColors.current.primary

// ❌ FORBIDDEN — non-template icons that ignore theme
imageView.image = UIImage(named: "custom-icon")
```

---

## 5. Naming Conventions

### 5.1 File Naming

| Category | Pattern | Example |
|----------|---------|---------|
| View Controller | `{Feature}ViewController.swift` | `CacheManagementViewController.swift` |
| Cell (Table) | `{Feature}Cell.swift` | `CacheAppCell.swift` |
| Cell (Collection) | `{Feature}CollectionViewCell.swift` | `WebPageHistoryGalleryCell.swift` — NOTE: should be `WebPageHistoryGalleryCell.swift` |
| Theme Component | `Theme{Component}.swift` | `ThemeButton.swift` |
| View | `{Feature}View.swift` | `LoadingView.swift` |
| Extension | `{Type}+{Feature}.swift` | `WebCacheDebugPanelViewController+Cells.swift` → should be split |

### 5.2 Class Naming

| Category | Pattern | Example |
|----------|---------|---------|
| View Controller | `{Feature}ViewController` | `WebBrowserViewController` |
| Table View Cell | `{Feature}Cell` | `CacheResourceCell` |
| Collection View Cell | `{Feature}Cell` or `{Feature}GalleryCell` | `WebPageHistoryGalleryCell` |
| Theme Component | `Theme{Component}` | `ThemeCard`, `ThemeBadge` |
| Custom View | `{Feature}View` | `EmptyStateView` |

### 5.3 Constraint Variable Naming

When storing constraints for later updates:

```swift
// Pattern: {element}{Attribute}Constraint
private var titleTopConstraint: Constraint?
private var contentViewHeightConstraint: Constraint?

// Update
titleTopConstraint?.update(offset: ThemeSpacing.default.lg)
```

### 5.4 Outlet / View Property Naming

```swift
// Pattern: descriptive noun + view type suffix
private let titleLabel = UILabel()
private let iconImageView = UIImageView()
private let actionButton = ThemeButton()
private let containerView = UIView()
```

---

## 6. Migration Guide

### Priority 1: High Impact, Low Effort

| Task | Scope | Estimate |
|------|-------|----------|
| Replace hardcoded `UIColor` with `ThemeColors` | ~168 occurrences | 2-3 days |
| Replace hardcoded font sizes with `ThemeTypography` | ~16 sizes | 1 day |
| Replace hardcoded corner radius with `ThemeCornerRadius` | ~13 values | 0.5 day |
| Replace hardcoded spacing with `ThemeSpacing` | All numeric offsets | 1 day |

### Priority 2: Structural

| Task | Scope | Estimate |
|------|-------|----------|
| Create `BaseTableViewCell` / `BaseCollectionViewCell` | New files | 0.5 day |
| Extract inline cells from `WebCacheDebugPanelViewController+Cells.swift` | 5 cells | 1 day |
| Consolidate duplicate ActionCell patterns | ~17 duplicates | 1-2 days |
| Add `accessibilityIdentifier` to all interactive elements | ~50+ elements | 1 day |

### Priority 3: Polish

| Task | Scope | Estimate |
|------|-------|----------|
| Standardize shadow styles on all cards | ThemeCard + custom | 0.5 day |
| Ensure all cells call `prepareForReuse` properly | All cells | 0.5 day |
| Migrate from deprecated `imageEdgeInsets` to `UIButton.Configuration` | Affected buttons | 0.5 day |
| Add `xl` (12pt) corner radius token | ThemeCornerRadius | 0.1 day |

### Quick Reference: Search & Replace

```bash
# Find hardcoded colors
rg "UIColor\(" --type swift Sources/ | grep -v "ThemeColors" | grep -v "ThemeManager"

# Find hardcoded font sizes
rg "systemFont(ofSize:" --type swift Sources/ | grep -v "ThemeTypography" | grep -v "ThemeFonts"

# Find hardcoded spacing numbers
rg "offset\(\d+\)" --type swift Sources/

# Find hardcoded corner radius
rg "cornerRadius\s*=\s*\d+" --type swift Sources/ | grep -v "ThemeCornerRadius"
```

---

## Appendix: Token Quick Reference Card

### Colors

```swift
ThemeColors.current.primary           // Brand primary
ThemeColors.current.secondary         // Brand secondary
ThemeColors.current.text              // Primary text
ThemeColors.current.textSecondary     // Secondary text
ThemeColors.current.background        // Screen background
ThemeColors.current.surface           // Elevated surface
ThemeColors.current.cardBackground    // Card background
ThemeColors.current.border            // View border
ThemeColors.current.divider           // Divider line
ThemeColors.current.success           // Status: success
ThemeColors.current.warning           // Status: warning
ThemeColors.current.error             // Status: error
ThemeColors.current.info              // Status: info
ThemeColors.current.badgeBackground   // Badge default bg
ThemeColors.current.badgeText         // Badge default text
ThemeColors.current.gradientStart     // Gradient start
ThemeColors.current.gradientEnd       // Gradient end
```

### Typography

```swift
ThemeTypography.current.largeTitle    // 28pt bold — Hero
ThemeTypography.current.title1        // 22pt bold — Page title
ThemeTypography.current.title2        // 20pt semibold — Section header
ThemeTypography.current.headline      // 17pt semibold — Emphasis
ThemeTypography.current.body          // 15pt regular — Body text
ThemeTypography.current.caption1      // 13pt regular — Secondary info
ThemeTypography.current.caption2      // 11pt regular — Micro label
ThemeFonts.default.button             // 16pt medium — Button text
```

### Spacing

```swift
ThemeSpacing.default.xs    // 4pt
ThemeSpacing.default.sm    // 8pt
ThemeSpacing.default.md    // 16pt
ThemeSpacing.default.lg    // 24pt
ThemeSpacing.default.xl    // 32pt
```

### Corner Radius

```swift
ThemeCornerRadius.default.sm    // 4pt  — Badge, chip
ThemeCornerRadius.default.md    // 8pt  — Button, input
ThemeCornerRadius.default.lg    // 16pt — Card, modal
ThemeCornerRadius.default.full  // 999pt — Avatar, circle
```

### Animation

```swift
ThemeAnimation.standard { }   // 0.25s
ThemeAnimation.spring { }     // 0.3s, damping 0.8
ThemeAnimation.slow { }       // 0.5s
```
