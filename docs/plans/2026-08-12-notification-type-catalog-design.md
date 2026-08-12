# Notification Type Catalog Design

## Goal

Make every documented Push v2 content type map to deterministic Inbox list, detail, action, and fallback behavior. Keep one native detail hierarchy and add only type-specific content slots.

## Supported matrix

| Type | Specialized content | Primary action | Failure or terminal state |
| --- | --- | --- | --- |
| `plain` | Plain body | Open link/app when supplied | Body remains readable without a destination |
| `markdown` | Sanitized native-hosted Markdown WebView | Open trusted links | Rendering failure falls back to source text |
| `image` | Remote image card with loading state | Open destination when supplied | Explicit unavailable state keeps the message readable |
| `qr` | Host-generated QR card | Copy QR value | Empty/invalid value never creates a blank card |
| `otp` | Large code card with expiry | Copy code | Expired state disables urgency while retaining history |
| `chat` | Message body and conversation context | Open conversation | Missing trusted route leaves a readable notification only |
| `approval` | State banner and native actions, or trusted handoff | Confirm action/open approval | Resolved, rejected, cancelled, expired, conflict and network states |

## Information hierarchy

The visible order is title, state or specialized content, contextual action, body, destination action, basic metadata, secondary actions. Basic metadata contains received time, source, group and expiry. Routing paths, replacement/request identifiers, state path and revision move into a collapsed technical-information disclosure. This keeps operational fields available for debugging without dominating the user-facing message.

Chat does not introduce a second messaging protocol. `appId + route + params` locates the conversation in a trusted PWA, where its existing authentication and message APIs remain authoritative. Push parameters never authorize a sensitive action.

## Verification

Seed one deterministic message per type. Add focused UI tests for plain, image and chat while retaining Markdown, OTP, QR and approval tests. Verify media loading and failure states, chat destination wording, collapsed technical metadata, Push v2 schema examples, lint, build, screenshot inspection and zero crash logs.
