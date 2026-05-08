---
name: Worklog
description: Private daily work ledger with a product-brutalist interface
colors:
  paper: "#f4f1e8"
  paper-raised: "#fbf8ee"
  paper-muted: "#e7e1d4"
  ink: "#161512"
  ink-soft: "#3b3932"
  rule: "#25231e"
  rule-muted: "#a49d8d"
  acid: "#d5ef39"
  work: "#1d5dff"
  other: "#6f6a5f"
  success: "#18794e"
  warning: "#a76500"
  destructive: "#b42318"
typography:
  display:
    fontFamily: "Geist Variable, Arial Narrow, Arial, system-ui, sans-serif"
    fontSize: "3rem"
    fontWeight: 650
    lineHeight: 0.95
    letterSpacing: "0"
  title:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1.375rem"
    fontWeight: 650
    lineHeight: 1.05
    letterSpacing: "0"
  body:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 430
    lineHeight: 1.5
    letterSpacing: "0"
  label:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "0.1em"
rounded:
  none: "0px"
  sm: "2px"
  md: "4px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper-raised}"
    rounded: "{rounded.sm}"
    padding: "10px 14px"
  button-secondary:
    backgroundColor: "{colors.paper-muted}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: "10px 14px"
  panel:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "24px"
---

# Design System: Worklog

## 1. Overview

**Creative North Star: "The Ruled Studio Ledger"**

Worklog uses a product-brutalist visual system: hard black rules, dense editorial grids, oversized numerical emphasis, and direct labels. The architecture reference is translated into a working application shell, not copied as a poster. The result should feel like a precise studio ledger for time and routine.

The interface rejects softness: no glass panels, no decorative blur, no warm SaaS cards, no vague inspiration copy. Brutalism is used as structure, so the user can scan dates, states, totals, and actions faster.

**Key Characteristics:**
- Off-white paper surfaces with ink-tinted text and heavy borders.
- Squared panels, ruled headers, compact labels, and tabular numbers.
- Accent color is rare and functional: current selection, focus, completion, and primary action.
- Dense but calm layouts that preserve standard product affordances.

## 2. Colors

The palette is mostly paper and ink, with acidic and semantic accents reserved for state.

### Primary
- **Ink Black** (#161512): Main text, panel borders, primary buttons, active navigation.
- **Acid Marker** (#d5ef39): Current selection, small high-energy confirmation marks, and focus-adjacent highlights.

### Secondary
- **Work Blue** (#1d5dff): Work time blocks and work-specific heat emphasis when color is needed.
- **Other Grey** (#6f6a5f): Non-work periods and secondary records.

### Neutral
- **Ledger Paper** (#f4f1e8): Page background.
- **Raised Paper** (#fbf8ee): Main panels, dialogs, forms.
- **Muted Paper** (#e7e1d4): Secondary buttons, inactive strips, subtle fields.
- **Rule Muted** (#a49d8d): Dividers and inactive borders.

### Named Rules

**The Ink Rule.** Borders are structural, not decorative. If a panel groups work, give it a real rule.

**The Rare Acid Rule.** Acid is never used as wallpaper. It appears where the user must notice state or selection.

## 3. Typography

**Display Font:** Geist Variable with system fallbacks  
**Body Font:** Geist Variable with system fallbacks  
**Label/Mono Font:** Geist Variable with tabular numeric features

**Character:** utilitarian, condensed by composition rather than by font choice. Hierarchy comes from scale, weight, casing, and grid placement.

### Hierarchy
- **Display** (650, 3rem, 0.95): page leads, selected date, timer, major totals.
- **Headline** (650, 1.75rem, 1.05): section starts and primary panel titles.
- **Title** (650, 1.375rem, 1.05): cards, dialogs, and list group titles.
- **Body** (430, 1rem, 1.5): descriptions, notes, settings help, history text.
- **Label** (700, 0.75rem, 0.1em, uppercase): metadata, panel identifiers, stats labels, navigation utility.

### Named Rules

**The No Negative Tracking Rule.** Letter spacing is never negative. Uppercase labels use positive tracking; headings use zero tracking.

**The Numeric Ledger Rule.** Durations, dates, timers, and percentages use tabular numbers.

## 4. Elevation

This system is flat. Depth is conveyed through border weight, background changes, z-index, and direct overlay color. Shadows are avoided except for native browser affordances or unavoidable focus visibility.

### Named Rules

**The Flat By Default Rule.** Panels do not float. They sit in the grid.

## 5. Components

### Buttons
- **Shape:** squared with a 2px radius.
- **Primary:** ink background, raised-paper text, hard border.
- **Hover / Focus:** no soft glow; use contrast shift, outline, or visible ring.
- **Secondary / Ghost:** paper surfaces with ink rules; ghost controls stay text-led but keep a visible hover surface.

### Cards / Containers
- **Corner Style:** 0px by default; 2-4px only for small controls.
- **Background:** raised paper for major panels, muted paper for secondary cells.
- **Shadow Strategy:** none.
- **Border:** 1-2px rules, with stronger borders on major panels.
- **Internal Padding:** 16-32px depending on hierarchy.

### Inputs / Fields
- **Style:** squared ruled boxes on raised paper.
- **Focus:** ink/acid ring with high contrast.
- **Error / Disabled:** visible semantic color plus text, never color alone.

### Navigation
- **Style:** compact ruled strip with active item as ink block.
- **Behavior:** keep labels visible on desktop, wrap safely on smaller widths.

### Data Cells
- **Style:** tabular numbers, uppercase labels, ruled divisions.
- **Heat:** use explicit stepped fills with adequate contrast.

## 6. Do's and Don'ts

**Do**
- Use grids, dividers, and panel labels to make structure obvious.
- Keep controls standard and keyboard-accessible.
- Use icons from lucide-react only where they clarify action.
- Keep all body copy readable at mobile widths.
- Make empty, loading, error, disabled, and selected states deliberate.

**Don't**
- Do not use `rounded-2xl`, pill-heavy cards, backdrop blur, decorative gradients, or glassmorphism.
- Do not use pure `#000` or pure `#fff`; use tinted ink and paper.
- Do not use gradient text or side-stripe accent borders.
- Do not turn the product into a marketing landing page.
- Do not hide key actions behind visual experimentation.
