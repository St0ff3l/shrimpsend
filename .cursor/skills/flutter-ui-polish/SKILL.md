---
name: flutter-ui-polish
description: Polishes Flutter screens in this project by enforcing shared tokens, theme-based components, and cleaner visual hierarchy. Use when editing Flutter UI, improving page aesthetics, reviewing spacing/color/radius consistency, or when the user asks to make a screen look better.
---

# Flutter UI Polish

## Quick Start

When improving a Flutter screen in this repo:

1. Read the target screen and `app/lib/ui/app_ui.dart`.
2. Reuse theme and token primitives before adding local styles.
3. Remove raw colors and repeated spacing/radius values where practical.
4. Verify light mode, dark mode, disabled state, loading state, and error state.

## Project Defaults

- Theme entry: `app/lib/main.dart`
- Shared UI tokens: `app/lib/ui/app_ui.dart`
- Accent source: `AppColorTheme.accent`
- Preferred spacing scale: `4 / 8 / 12 / 16 / 24 / 32`
- Preferred radii: `12 / 16 / 20`
- Standard control height: `AppSize.controlHeight`
- Form max width: `AppSize.formMaxWidth`
- Content max width: `AppSize.contentMaxWidth`

## Required Rules

- Prefer `context.appColors`, `Theme.of(context)`, `AppSpacing`, `AppRadius`, and `AppSize`.
- Prefer `FilledButton`, `OutlinedButton`, `TextButton`, and `InputDecoration` defaults from theme.
- Do not introduce page-local gray palettes like `Color(0xFF71717A)` when an existing semantic color fits.
- Do not hardcode primary CTA colors; use `theme.colorScheme.primary` via themed components.
- Avoid scattered magic numbers for padding, gaps, radius, and control heights.
- On form pages, prefer a constrained width plus a surface container/card instead of full-width loose layouts.
- When text or icons sit inside colored cards, badges, bubbles, or buttons, choose foreground colors for that background instead of reusing page-level muted text.
- Re-check contrast in both light mode and dark mode after any color change. A color that works on page background may fail inside a sent bubble or tinted status surface.

## Visual Review Checklist

- Color hierarchy:
  - Primary action is visually clear.
  - Secondary text uses subdued semantic text color.
  - Status colors are semantic (`success`, `warning`, `danger`) rather than arbitrary.
- Spacing rhythm:
  - Gaps follow the shared spacing scale.
  - Related controls sit closer together than unrelated sections.
  - Page edges and card padding feel consistent.
- Shape consistency:
  - Inputs, buttons, badges, and cards use shared radii.
  - Rounded styles do not vary without purpose.
- Layout hierarchy:
  - Important content has a clear container or grouping.
  - Forms are not too wide on tablet/desktop.
  - Section labels, titles, helper text, and body text have obvious hierarchy.
- State coverage:
  - Error and disabled states remain readable.
  - Loading states do not collapse layout.
  - Dark mode remains balanced; avoid overly bright neutrals.
  - Secondary text inside dark surfaces remains readable; do not blindly reuse page-level muted gray.
  - Accent colors inside dark bubbles should be lifted or blended when needed so progress labels, retry buttons, and helper text stay legible.

## Preferred Workflow

1. Identify raw color values, repeated `EdgeInsets`, repeated `BorderRadius.circular(...)`, and duplicated `TextStyle(...)`.
2. Move the shared part into theme or token usage.
3. For colored surfaces, validate foreground hierarchy: primary text, secondary text, subtle metadata, and accents should each remain readable on that exact background.
4. Tighten layout with width constraints, surface grouping, and consistent vertical rhythm.
5. Keep screen-specific styling only for truly unique visual treatment.
6. Run formatting and analyze the touched Flutter files.

## Good Outcomes

- Login, settings, and future form screens should feel like the same product.
- Theme changes should propagate through buttons, inputs, chips, and cards with minimal local overrides.
- A later request like “顺手美化这个页面” should mostly be a layout and hierarchy task, not a color cleanup task.

## Anti-Patterns

- Hardcoding a CTA color already represented by `AppColorTheme.accent`
- Mixing many nearby font sizes with no clear hierarchy
- Using bright badges or warning colors that steal focus from the main action
- Leaving one-off input/button styles inside screens when theme defaults can handle them
- Adding decorative shadows or colors before fixing spacing, hierarchy, and consistency
- Using the same muted gray for page text and bubble-internal metadata
- Putting unadjusted accent colors on dark bubbles where they visually vibrate or lose readability
