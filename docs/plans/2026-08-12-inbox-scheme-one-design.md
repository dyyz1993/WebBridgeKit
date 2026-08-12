# Inbox Scheme One — Quiet Native Priority List

## Goal

Make the Inbox scan like a native priority list instead of a stack of miniature cards. The content hierarchy is source and time, title, then one-line preview. Type recognition comes from the leading icon and semantic tint; labels are reserved for exceptions that need immediate action.

## Layout

1. Keep the compact title, latest/group switch, search, and filter controls, but reduce their visual weight.
2. Keep filters on one horizontal line without equal-width stretching.
3. Use an 88 pt message row with a 40 pt icon, source/time metadata, title, and one-line preview.
4. Give every row a small surface separation and consistent rounded container; remove the generic type badge and routine priority badge.
5. Show a compact state marker only for `待确认`, `紧急`, or other actionable states.
6. Use the primary token for unread status rather than a competing red dot.
7. In group mode, render a compact localized group header with count and disclosure; never expose raw group identifiers as oversized titles.

## Type Treatment

| Type | Primary recognition | Exception marker |
| --- | --- | --- |
| Markdown | document icon + accent tint | none |
| OTP | key icon + primary tint | only `重要` when high priority |
| QR | QR icon + info tint | none |
| Chat | paper-plane icon + info tint | none |
| Approval | clock/clipboard icon + warning tint | `待确认` |
| Security | shield icon + error tint | `紧急` when critical |
| Plain | source-derived icon + neutral tint | none |

## Acceptance

- Latest and grouped screenshots show at least four messages without clipped text or overlap.
- A normal row has no more than one status marker.
- All filters remain reachable on a narrow iPhone screen.
- Group headers use readable labels and collapse/expand without UITableView consistency errors.
- Existing message selection, search, filters, mark-all-read, and swipe-delete tests remain green.
