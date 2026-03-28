---
name: design-system
description: Guides correct use of the MovieTracker design system (DesignSystem package). Use when writing SwiftUI views, styling components, or any time colors, fonts, icons, spacing, padding, shadows, or corner radii are needed. Covers accessor syntax, token names, and when to use semantic vs. raw tokens.
---

# Using the Design System

All tokens live in `MovieTrackerPackage/Sources/DesignSystem/`. Accessor extensions in `Accessors/` expose them through natural SwiftUI syntax — always prefer accessors over calling the underlying token structs directly.

## Icons — `Image`

```swift
Image.catalogTab
Image.starFilled
Image.heartFill
Image.errorCircle
```

Full list in `DSIcon.swift`. Every `DSIcon` case has a matching static `Image` property.

## Typography — `Font`

```swift
.font(.heading1)     // 34pt black
.font(.heading2)     // 24pt bold
.font(.heading3)     // 20pt semibold
.font(.small)        // 13pt regular
.font(.buttonLabel)  // 15pt semibold
.font(.tagLabel)     // 12pt medium
// ds-prefix avoids shadowing system Font members:
.font(.dsBody)       // 16pt regular
.font(.dsCaption)    // 11pt regular
```

## Colors — `Color`

Prefer semantic tokens over brand primitives:

```swift
// Semantic (use these)
.foregroundStyle(.accent)
.foregroundStyle(.labelOnDark)
.background(.backgroundPrimary)
.background(.backgroundSecondary)
.background(.backgroundTertiary)
.background(.backgroundOverlay)
.foregroundStyle(.rating)
.foregroundStyle(.error)
.foregroundStyle(.success)
.overlay(Rectangle().fill(.separator))

// Brand primitives (only when no semantic token fits)
Color.dsPrimary      // #0d1b2a navy
Color.dsSecondary    // #1b263b dark blue
Color.dsAccent       // #e63946 red
Color.dsGold         // #f77f00 orange
```

## Padding — `View`

Two overloads — pick by intent:

```swift
// Scalar: applies token's uniform value to specified edges
.padding(.screenEdge)             // horizontal 16pt margins
.padding(.cardContent)            // all edges 12pt
.padding(.bottom, .cardContent)
.padding(.horizontal, .screenEdge)

// Asymmetric-aware: applies full EdgeInsets (use for tagInset, sectionVertical, etc.)
.padding(.tagInset)               // top 4 / horizontal 6
.padding(.sectionVertical)        // top+bottom 24
```

Token reference:

| Token | Value |
|---|---|
| `.screenEdge` | 16 h, 0 v |
| `.cardContent` | 12 all |
| `.sectionVertical` | 24 top+bottom |
| `.componentGap` | 8 all |
| `.tagInset` | 6 h × 4 v |
| `.wizardStep` | 20 all |
| `.sheetContent` | 24 all |
| `.iconHitArea` | 44 all |

## Corner Radius — `View`

```swift
.cornerRadius(.small)    // 6  — tags, chips
.cornerRadius(.medium)   // 10 — cards, inputs
.cornerRadius(.large)    // 14 — cards, sheets
.cornerRadius(.xLarge)   // 20 — modal sheets
.cornerRadius(.full)     // 999 — pill shapes
```

Accepts an optional `style:` parameter (default `.continuous`).

## Shadow — `View`

```swift
.shadow(.card)      // subtle — list cards, posters
.shadow(.elevated)  // medium — sticky headers, floating controls
.shadow(.modal)     // strong — sheets, overlays
```

## Spacing in Stacks

Pass `DSSpacing` directly via the `spacing:` label; applies to `VStack`, `HStack`, `LazyVStack`, `LazyHStack`:

```swift
VStack(spacing: .small) { }          // 12pt
HStack(spacing: .xSmall) { }         // 8pt
LazyVStack(spacing: .medium) { }     // 16pt
LazyHStack(spacing: .large) { }      // 24pt
```

Scale: `.xxSmall` 4 · `.xSmall` 8 · `.small` 12 · `.medium` 16 · `.large` 24 · `.xLarge` 32 · `.xxLarge` 48 · `.xxxLarge` 64

## Raw values (when needed)

If a SwiftUI API requires a `CGFloat` directly, use the raw value:

```swift
DSSpacing.medium.rawValue          // CGFloat 16
DSCornerRadius.large.rawValue      // CGFloat 14
DSPadding.cardContent.value        // CGFloat 12
DSPadding.cardContent.edgeInsets   // EdgeInsets
```
