---
name: webbridgekit-design
description: Use this skill to generate well-branded interfaces for WebBridgeKit. Contains colors, type, fonts, and UI components for prototyping developer-tool mobile app UIs.
user-invocable: true
---

# WebBridgeKit Design Library — Skill Entry Point

## Quick Map

| Path | Description |
|------|-------------|
| `README.md` | Brand context, content fundamentals, visual foundations |
| `colors_and_type.css` | Drop-in CSS variables for colors, type, radius, shadow, spacing |
| `css.json` | Structured token understanding source |
| `components/index.json` | Component index + cross-component patterns |
| `preview/` | Component preview HTML files |

---

## Essentials at a Glance

- **Brand primary**: `#4F6AF6` — indigo-violet, professional developer tool. No warm accents.
- **Dark mode primary**: `#6B82F8` — slightly lighter indigo for dark backgrounds.
- **Radius**: `6px / 8px / 12px / 16px / 999px` — generous, spacious. Cards `16px`, buttons `12px`, pills full round (`--wbk-radius-full: 999px`).
- **Button height**: `48px` (`--wbk-button-height`). **Search height**: `44px` (`--wbk-search-field-height`). **Spacing unit**: `8px` (`--wbk-spacing-sm`).
- **Type stack**: SF Pro Display / SF Pro Text (iOS system), PingFang SC (Chinese fallback), SF Mono (code). No web font imports needed — the system stack provides all faces.
- **Voice**: Chinese-first, professional, developer-focused, minimal UI text.
- **Shadows**: Quiet and subtle. 5 defined levels:
  - `--wbk-shadow-sm`: `0 1px 3px rgba(17,24,39,0.008)`
  - `--wbk-shadow-md`: `0 2px 8px rgba(17,24,39,0.010)`
  - `--wbk-shadow-card`: `0 4px 16px rgba(17,24,39,0.008)`
  - `--wbk-shadow-fab`: `0 8px 24px rgba(17,24,39,0.020)`
  - `--wbk-shadow-lg`: `0 8px 24px rgba(17,24,39,0.012)`
  - `--wbk-shadow-sheet`: `0 12px 32px rgba(17,24,39,0.015)`
- **Card shadow**: `0 4px 16px` with `--wbk-shadow` base color.
- **Dark mode**: Full light/dark token pairs via `.dark` class, auto-switch via `prefers-color-scheme` media query.

---

## Color Palette (Light)

| Token | Value | Usage |
|-------|-------|-------|
| `--wbk-background` | `#F8F9FC` | Page background |
| `--wbk-background-secondary` | `#F0F2F7` | Secondary surfaces |
| `--wbk-background-tertiary` | `#E8EBF2` | Tertiary / hover backgrounds |
| `--wbk-surface` | `#FFFFFF` | Card / sheet surface |
| `--wbk-card-background` | `#FFFFFF` | Card background |
| `--wbk-text` | `#1A1D2E` | Primary text |
| `--wbk-text-secondary` | `#6B7394` | Secondary / metadata text |
| `--wbk-text-tertiary` | `#9CA3C4` | Placeholder / disabled |
| `--wbk-primary` | `#4F6AF6` | Brand primary / CTAs |
| `--wbk-primary-pressed` | `#3D56E0` | Pressed state |
| `--wbk-primary-soft` | `#EEF1FE` | Soft brand bg |
| `--wbk-accent` | `#8B5CF6` | Accent purple |
| `--wbk-success` | `#16A34A` | Success semantic |
| `--wbk-warning` | `#D97706` | Warning semantic |
| `--wbk-error` | `#DC2626` | Error semantic |
| `--wbk-info` | `#0F766E` | Info semantic |
| `--wbk-border` | `#D8DEE8` | Borders |
| `--wbk-separator` | `#E6EAF0` | Dividers / separators |

## Color Palette (Dark)

| Token | Value | Usage |
|-------|-------|-------|
| `--wbk-background` | `#0F1117` | Page background |
| `--wbk-background-secondary` | `#1A1D28` | Secondary surfaces |
| `--wbk-background-tertiary` | `#252A38` | Tertiary / hover backgrounds |
| `--wbk-surface` | `#13171D` | Card / sheet surface |
| `--wbk-card-background` | `#1E2233` | Card background |
| `--wbk-text` | `#F0F2F7` | Primary text |
| `--wbk-text-secondary` | `#8892B0` | Secondary text |
| `--wbk-primary` | `#6B82F8` | Brand primary |
| `--wbk-primary-pressed` | `#4F6AF6` | Pressed state |
| `--wbk-primary-soft` | `rgba(107,130,248,0.14)` | Soft brand bg |
| `--wbk-success` | `#4ADE80` | Success semantic |
| `--wbk-warning` | `#FBBF24` | Warning semantic |
| `--wbk-error` | `#F87171` | Error semantic |
| `--wbk-border` | `#2A323D` | Borders |
| `--wbk-separator` | `#232A34` | Dividers |

---

## Typography

### Font Families

- **Primary**: `system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif` — resolves to **SF Pro Text** on iOS, **PingFang SC** for Chinese text.
- **Monospace**: `ui-monospace, "SF Mono", Menlo, Monaco, Consolas, monospace` — **SF Mono** on Apple platforms.
- **Chinese rendering**: System font stack auto-selects PingFang SC on iOS/macOS for Chinese text. No separate `@font-face` import required.

### Type Scale

| Token | Shorthand | CSS Variable |
|-------|-----------|-------------|
| Display Large | `700 34px/1.2` | `--wbk-text-display-large` |
| Display / Screen Title | `700 28px/1.2` | `--wbk-text-display` / `--wbk-text-screen-title` |
| Compact Title | `700 24px/1.3` | `--wbk-text-compact-title` |
| Section Title / Headline | `600 17px/1.3` | `--wbk-text-section-title` |
| Row Title / Card Title | `600 16px/1.3` / `500 16px/1.3` | `--wbk-text-card-title` / `--wbk-text-row-title` |
| Body | `400 15px/1.4` | `--wbk-text-body` |
| Button | `600 15px/1.4` | `--wbk-text-button` |
| Metadata | `400 13px/1.4` | `--wbk-text-metadata` |
| Caption | `400 12px/1.4` | `--wbk-text-caption` |
| Tab Label | `500 11px/1.3` | `--wbk-text-tab-label` |
| Badge | `700 10px/1.3` | `--wbk-text-badge` |

### Monospace Scale

| Token | Shorthand | CSS Variable |
|-------|-----------|-------------|
| Mono Display | `700 20px/1.3` | `--wbk-text-monospace-display` |
| Mono Title | `700 18px/1.3` | `--wbk-text-monospace-title` |
| Mono Body | `400 13px/1.4` | `--wbk-text-monospace-body` |
| Mono Meta | `400 12px/1.4` | `--wbk-text-monospace-meta` |
| Mono Small | `400 11px/1.3` | `--wbk-text-monospace-small` |
| Mono Mini | `400 10px/1.3` | `--wbk-text-monospace-mini` |
| Mono Micro | `400 9px/1.3` | `--wbk-text-monospace-micro` |

---

## Spacing

| Token | Value | Typical Use |
|-------|-------|-------------|
| `--wbk-spacing-xxs` | `2px` | Tiny inset |
| `--wbk-spacing-xs` | `4px` | Dense gap |
| `--wbk-spacing-sm` | `8px` | Default spacing unit |
| `--wbk-spacing-md` | `12px` | Input padding |
| `--wbk-spacing-lg` | `16px` | Card padding, screen margin |
| `--wbk-spacing-xl` | `20px` | Button padding |
| `--wbk-spacing-xxl` | `24px` | Section gap |
| `--wbk-spacing-xxxl` | `32px` | Large section gap |
| `--wbk-spacing-section` | `32px` | Section spacing |

---

## Radius

| Token | Value | Component |
|-------|-------|-----------|
| `--wbk-radius-xs` | `6px` | Small indicators |
| `--wbk-radius-sm` | `8px` | Compact elements |
| `--wbk-radius-md` | `12px` | Buttons, search fields |
| `--wbk-radius-row` | `12px` | Settings rows |
| `--wbk-radius-lg` | `12px` | Large elements |
| `--wbk-radius-card` | `16px` | Cards |
| `--wbk-radius-sheet` | `20px` | Bottom sheets |
| `--wbk-radius-xxl` | `20px` | Extended surfaces |
| `--wbk-radius-xl` | `24px` | Extra-large surfaces |
| `--wbk-radius-full` | `999px` | Pills, badges |
| `--wbk-radius-avatar` | `22px` | Avatars |
| `--wbk-radius-pill` | `28px` | Filter pills |

---

## Shadows

| Token | Value |
|-------|-------|
| `--wbk-shadow-sm` | `0 1px 3px rgba(17,24,39,0.008)` |
| `--wbk-shadow-md` | `0 2px 8px rgba(17,24,39,0.010)` |
| `--wbk-shadow-card` | `0 4px 16px rgba(17,24,39,0.008)` |
| `--wbk-shadow-fab` | `0 8px 24px rgba(17,24,39,0.020)` |
| `--wbk-shadow-lg` | `0 8px 24px rgba(17,24,39,0.012)` |
| `--wbk-shadow-sheet` | `0 12px 32px rgba(17,24,39,0.015)` |

---

## Components

| Slug | Name (zh) | Key Insight | Key Tokens |
|------|-----------|-------------|------------|
| `button` | 按钮 | Primary / secondary / icon-only variants. Indigo primary fill. | Height `48px`, radius `12px`, horizontal padding `20px`, icon size `18px` |
| `card` | 卡片 | Token / resource / stats variants. Elevated white surface. | Radius `16px`, padding `16px`, shadow `0 4px 16px` |
| `settings-row` | 设置行 | Icon + label + value + chevron layout. Consistent tap targets. | Min height `54px`, max height `64px`, icon box `32px`, icon `20px`, chevron `16px` |
| `tab-bar` | 标签栏 | 4-tab bottom navigation. Frosted glass background. | Height `56px`, icon `23px`, label `11px/500`, content top padding `6px` |
| `search-field` | 搜索框 | Pill-style rounded input with search icon. | Height `44px`, radius `12px`, icon `18px`, horizontal padding `12px` |
| `filter-pill` | 筛选标签 | Active / inactive pill states. Full round shape. | Height `34px`, horizontal padding `14px`, min width `56px`, full radius |
| `action-tile` | 操作块 | Quick action grid tile. Icon + label. | Height `72px`, min width `72px`, icon `22px` |
| `resource-card` | 资源卡片 | Resource list item with icon + title + subtitle. | Min height `92px`, max height `116px`, icon `22px`, radius `16px`, padding `16px` |
| `message-cell` | 消息条目 | Inbox message row with avatar + body + timestamp. | Min height `72px`, max height `96px` |
| `empty-state` | 空状态 | Centered illustration + title + body. | Icon `48px`, title `17px/600`, body `13px/400`, max width `280px` |

---

## Brand Data

| Field | Value |
|-------|-------|
| library | WebBridgeKit |
| productType | developer-tool/mobile-app |
| personality | premium + professional + developer-focused |
| language | zh-CN |
| visualTone | spacious card-based iOS premium |
| colorNamingPrefix | wbk |

---

## Patterns & Usage

### Light / Dark Mode

All color tokens define both `:root` (light) and `.dark` overrides. Apply dark mode by adding class `dark` to a container or using `prefers-color-scheme: dark` media query.

### Layer

- **Background**: `--wbk-background` → `--wbk-background-secondary` → `--wbk-background-tertiary`
- **Surface**: `--wbk-surface` for cards; `--wbk-surface-elevated` for modal sheets
- **Text**: `--wbk-text` (primary) → `--wbk-text-secondary` (metadata) → `--wbk-text-tertiary` (disabled)

### Touch Targets

Minimum tap target: `44px x 44px` (`--wbk-tap-target-minimum-width/height`).

### Screen Layout

- Horizontal inset: `16px` (`--wbk-screen-horizontal-inset`, `--wbk-spacing-screen-horizontal`)
- Inter-section spacing: `24px` (`--wbk-screen-inter-section-spacing`)
- Screen top: `16px`, screen bottom: `24px`

---

## Consuming the Library

1. **Tokens**: Include `colors_and_type.css` in your HTML `<head>` for instant access to all CSS custom properties.
2. **Components**: Browse `preview/` for HTML previews of each component. Each preview shows light + dark state.
3. **Index**: `components/index.json` provides structured component metadata, props, and cross-component patterns.
4. **Structured data**: `css.json` contains the full token list in machine-readable format for code generation.
5. **Swift / iOS**: Use `ThemeTokens.Color.*` constants in Swift code. They auto-adapt to Light/Dark mode.
