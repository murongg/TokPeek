---
name: TokPeek
description: Your AI token usage at a glance.
colors:
  black: "oklch(0 0 0)"
  white: "oklch(1 0 0)"
  ink-light: "oklch(0.18 0 0)"
  muted-light: "oklch(0.46 0 0)"
  divider-light: "oklch(0.84 0 0)"
  ink-dark: "oklch(0.96 0 0)"
  muted-dark: "oklch(0.70 0 0)"
  divider-dark: "oklch(0.32 0 0)"
typography:
  headline:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.2
  title:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.35
  label:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.2
  data:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.1
rounded:
  control: "8px"
  surface: "12px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  menu-surface:
    background: "macOS regularMaterial"
    tint: "none"
  button-primary:
    backgroundColor: "{colors.ink-light}"
    textColor: "{colors.white}"
    rounded: "{rounded.control}"
    padding: "7px 12px"
  chart-surface:
    backgroundColor: "currentColor at 5.5% opacity"
    rounded: "{rounded.surface}"
    padding: "{spacing.md}"
---

# Design System: TokPeek

## Overview

**Creative North Star: “The Quiet Instrument Panel”**

TokPeek is a precise macOS utility that stays out of the way. Its identity is
black and white; hierarchy comes from typography, weight, opacity, spacing, and
native macOS materials rather than brand color.

The menu panel uses one continuous system glass surface. Internal sections do
not become separate glass cards. This lets the app inherit Apple’s current
window appearance while remaining compatible with earlier supported macOS
versions.

**Key Characteristics:**

- Native macOS behavior and control vocabulary
- Pure grayscale visual language
- One continuous system-material menu surface
- Compact, scan-friendly hierarchy
- Monospaced numerals inside a system-sans interface
- No decorative gradients, colored accents, or custom glass imitation

## Logo and App Mark

The mark is an abstract token peeking from behind a vertical panel:

- Near-black rounded square
- White panel
- Mid-gray token created only from white opacity
- A template-safe outlined TokPeek mark in the summary menu bar item

The mark must remain legible at 16px. Do not add outlines, shadows, letters,
charts, eyes, or colored details. The default menu bar status item uses a
two-line numeric summary instead of the mark; the template symbol remains the
loading fallback and an optional display mode.

The AppIcon tile fills its asset canvas; rounded corners provide the only
transparent area, with no additional safe-area inset.

## Color

TokPeek has no brand hue.

- **Primary:** System-adaptive black or white for important content and actions.
- **Secondary:** System secondary foreground for labels and metadata.
- **Tertiary:** System tertiary foreground for low-priority diagnostics.
- **Surface:** Primary foreground at 5.5% opacity for structural grouping.
- **Divider:** Native separator color.

**The Grayscale Rule.** Data categories use distinct lightness and labels, not
different hues.

**The One Glass Rule.** Only the menu window owns glass. Cards, rows, and charts
use spacing or quiet tonal fills; never stack separate blur layers.

## Material

The menu panel background uses SwiftUI `regularMaterial`. Material is a native
adaptive background, not a fixed translucent color:

- It blurs content behind the window.
- It enables system vibrancy for foreground content.
- It follows light mode, dark mode, accessibility contrast, and future macOS
  visual updates.
- It has no custom tint.

Settings continue to use standard grouped macOS surfaces because they are a
conventional utility window rather than a floating menu panel.

## Typography

**Display and body:** SF Pro through the system font
**Numeric data:** SF Mono or system monospaced digits

- **Headline** (600, 17px): Panel and settings titles.
- **Title** (600, 15px): Section titles and high-priority labels.
- **Body** (400, 13px): Explanations and settings help.
- **Label** (500, 11px): Metadata and chart annotations.
- **Data** (600, 15px): Token counts, cost, percentages, and durations.

Every changing numeric value uses monospaced digits to prevent layout jitter.

## Layout and Elevation

- Main menu: `480 × 560pt`
- Control radius: `8pt`
- Surface radius: `12pt`
- Content padding: `16pt`
- Section spacing: `16pt`
- Internal components add no ambient shadows.
- The system menu window owns rounding, blur, and elevation.

## Components

### Buttons

Use native bordered and borderless styles. Primary actions use the adaptive
primary foreground as tint. Hover, focus, pressed, disabled, and keyboard
states come from macOS.

### Period Picker

Use the native compact segmented picker. Selection follows the adaptive
black/white AccentColor asset.

### Model Filter

- A compact native menu sits opposite the period picker.
- Its catalog comes from an all-time local scan, independent of the selected
  period, and is cached to avoid repeated full-history work.
- Angle-bracketed Tokscale sentinel IDs are internal records and never appear
  as selectable models.
- Selecting a model updates every aggregate and chart in the dashboard.

### Menu Bar Summary

- A compact monochrome mark anchors the left side of the status item.
- Estimated cost appears on the first line and Token usage on the second.
- Both values use compact, left-aligned monospaced numerals within a fixed
  native menu bar height.
- Loading uses stable dash placeholders so the status item does not jump
  between an icon and text.

### Activity Chart

- Bars use the primary foreground.
- The average rule uses lower primary opacity.
- Grid lines use native separators.
- The chart container uses a 5.5% tonal fill, not another material.

### Chart Tooltips

- Every data visualization exposes details on hover.
- Tooltips share one compact system-surface component with monospaced values.
- The active mark remains prominent while neighboring marks recede.
- Tooltip content includes Token and the relevant cost, messages, or share.

### Usage Composition

Input, output, cache, and reasoning use four descending primary opacities.
Every segment remains text-labeled and VoiceOver-readable.

### Client Breakdown

- A compact donut chart shows each client’s share of total Token usage.
- The center displays the total, while the adjacent legend preserves client
  name, Token count, and percentage.
- Segments use descending primary opacities. Categories are always
  text-labeled and never communicated by grayscale alone.
- When more than five clients are present, the four largest remain named and
  the long tail is grouped as Other.

### Model Ranking

- The eight most-used provider/model pairs appear below the client breakdown.
- Entries use a two-column grid ordered left-to-right, then top-to-bottom.
- Each entry shows rank, model, provider, Token count, percentage, and a thin
  normalized bar.
- Ranking uses the full selected period and remains ordered by Token usage.

### Status

- Loading: grayscale tonal skeletons. Period changes crossfade to a gently
  pulsing skeleton, while scheduled same-period refreshes keep the current
  report visible.
- Empty: monochrome mark, explanation, and one recovery action.
- Error: primary foreground plus icon and readable message.
- Stale data: warning icon and last-updated timestamp while preserving the last
  successful snapshot.

## Motion

- Use 150–250ms state transitions.
- Do not animate every number update.
- Respect Reduce Motion.
- No decorative looping motion.

## Accessibility

- Maintain at least 4.5:1 contrast for body text.
- Never encode categories using lightness alone; labels remain present.
- Provide useful chart and composition accessibility values.
- Keep the menu bar mark template-compatible.
- Follow increased-contrast and reduced-transparency system settings.

## Anti-Patterns

- Colored brand accents
- Custom blur shaders or fake glass gradients
- Multiple nested glass cards
- Decorative shadows
- Dense web-dashboard grids
- Large rounded cards
- Color-only data categories
