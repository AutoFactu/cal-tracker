---
name: Cal Tracker
description: Bright mobile nutrition tracker interface extracted from three phone UI mockups
colors:
  app-bg: "#f0f0ef"
  screen: "#f7f7f5"
  surface: "#fbfbf8"
  surface-soft: "#f3f3f1"
  surface-muted: "#ecedea"
  ink: "#080907"
  ink-soft: "#2f312d"
  ink-muted: "#72756f"
  rule: "#e3e5df"
  rule-soft: "#eef0eb"
  lime: "#9ad32a"
  lime-deep: "#78a51b"
  lime-soft: "#d8f3a0"
  lime-wash: "#edf8d2"
  leaf: "#4f9b1f"
  water: "#10c7f5"
  orange: "#f08b2b"
  mint: "#4fd6a2"
  coral: "#e94f5f"
  yellow: "#fff0b6"
typography:
  display:
    fontFamily: "SF Pro Display, -apple-system, BlinkMacSystemFont, Segoe UI, system-ui, sans-serif"
    fontSize: "3rem"
    fontWeight: 700
    lineHeight: 1.16
    letterSpacing: "0"
  title:
    fontFamily: "SF Pro Display, -apple-system, BlinkMacSystemFont, Segoe UI, system-ui, sans-serif"
    fontSize: "1.375rem"
    fontWeight: 650
    lineHeight: 1.18
    letterSpacing: "0"
  body:
    fontFamily: "SF Pro Text, -apple-system, BlinkMacSystemFont, Segoe UI, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0"
  label:
    fontFamily: "SF Pro Text, -apple-system, BlinkMacSystemFont, Segoe UI, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "0"
rounded:
  none: "0px"
  sm: "10px"
  md: "18px"
  lg: "24px"
  xl: "32px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "14px 22px"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "14px 20px"
  panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "20px"
  metric-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "16px"
  bottom-nav:
    backgroundColor: "{colors.screen}"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.none}"
    padding: "8px 18px"
---

# Design System: Cal Tracker

## 1. Overview

**Creative North Star: "Fresh Food Intelligence"**

Cal Tracker uses a soft, bright mobile nutrition interface built from white space, fresh lime accents, real food imagery, and rounded metric surfaces. The design should feel optimistic and personal without becoming childish. It is a food and health product first: the interface makes meal logging, calorie awareness, hydration, progress, and daily habits feel approachable.

The source mockup shows three phone views: an onboarding screen with a vegetable photo composition, a personalized home dashboard with weekly progress and meal cards, and a statistics screen with calorie charts and compact health metrics. The screenshot brand text reads "FitBite"; this document extracts the visual language for Cal Tracker rather than adopting that literal name.

**Key Characteristics:**
- Near-white phone screens on a soft gray presentation background.
- Strong lime green as the signature color, supported by pale lime washes.
- Real food photography and circular meal thumbnails, not flat illustrated food.
- Rounded cards, circular icon chips, pill controls, and low-contrast shadows.
- Large black numerals for calories, steps, water, BPM, and dates.
- Calm, airy product screens that still carry enough density for daily tracking.

The product should feel like a modern iOS nutrition coach: friendly, visual, lightweight, and task-oriented. It should not feel like a clinical medical app, a gym performance dashboard, or a dark quantified-self tool.

## 2. Colors

The palette is dominated by white, off-white, and lime. Secondary colors appear only inside small semantic icons, charts, and health modules.

### Primary
- **Fresh Lime** (#9ad32a): Primary brand accent, active navigation, progress rings, selected days, chart highlights, and primary circular controls.
- **Deep Lime** (#78a51b): Pressed or active accent state, icon foregrounds, and darker lime marks on white controls.
- **Soft Lime** (#d8f3a0): Large dashboard highlight panels, pale bar chart columns, selected date background, and progress card fill.

### Secondary
- **Leaf Green** (#4f9b1f): Food-photo harmony color and natural health accent. Use it in botanical details, not as a competing brand color.
- **Water Cyan** (#10c7f5): Hydration icons, water droplets, and water-specific chart marks.
- **Activity Orange** (#f08b2b): Step or movement iconography, small activity accents, and warm status chips.
- **Exercise Mint** (#4fd6a2): Exercise mini charts and positive habit indicators.
- **Heart Coral** (#e94f5f): BPM, alerts, and heart-rate signals.
- **Warm Yellow** (#fff0b6): Calorie or flame icon chip backgrounds.

### Neutral
- **App Background** (#f0f0ef): Outer presentation background and page gutters.
- **Screen White** (#f7f7f5): Main mobile screen fill. Use instead of pure white for the app canvas.
- **Card Surface** (#fbfbf8): Cards, stat panels, calendar trays, and onboarding bottom action tray.
- **Soft Surface** (#f3f3f1): Secondary cards, inactive icon buttons, and subtle bottom navigation grounding.
- **Muted Rule** (#e3e5df): Dividers, card edges, chart guide marks, and quiet separators.
- **Ink** (#080907): Primary text, major numerals, icons, and status bar elements.
- **Soft Ink** (#2f312d): Secondary headings, labels, and body text.
- **Muted Ink** (#72756f): Metadata, units, inactive nav labels, axis labels, and helper copy.

### Named Rules

**The Lime Has A Job Rule.** Lime marks something selected, progressing, actionable, or motivational. Do not use lime as a random decorative wash outside health progress and primary actions.

**The Real Food Rule.** Food surfaces should use real, colorful photography or carefully masked bitmap assets. Flat generic food icons cannot replace the vegetable hero image or circular meal thumbnails.

**The Soft White Rule.** The screenshot reads white, but implementation should prefer near-white tokens for app surfaces. Reserve absolute white for imported photo masks or native device chrome only.

**The Small Semantic Color Rule.** Cyan, orange, mint, coral, and yellow are module colors. They should appear in small icon chips, sparklines, drops, and status details, not as full-screen themes.

## 3. Typography

**Display Font:** SF Pro Display with system fallbacks  
**Body Font:** SF Pro Text with system fallbacks  
**Number Font:** SF Pro Display or SF Pro Text with tabular numeric features

**Character:** rounded, native, and direct. The screenshot uses an iOS-like sans with black headlines, compact labels, and clear numeric hierarchy. It does not use decorative display fonts, condensed type, serif type, or negative letter spacing.

### Hierarchy
- **Display** (700, 3rem, 1.16): onboarding headline, large calorie number, and hero metric values.
- **Headline** (700, 2.5rem, 1.14): large marketing or first-run lines when display is too large.
- **Title** (650, 1.375rem, 1.18): screen titles, card titles, month labels, and dashboard block headings.
- **Metric** (650-700, 2rem to 3rem, 1): calories, step count, water count, exercise hours, BPM, and active date numerals.
- **Body** (400, 1rem, 1.35): supporting labels such as "Good morning!", meal names, units, and card body copy.
- **Label** (500, 0.75rem, 1): nav labels, weekday labels, chart axis labels, units, and compact metadata.

### Named Rules

**The Big Number Rule.** Health metrics should lead with a large number and a smaller unit. Examples from the mockup include `1250 Kcal`, `5,500 steps`, `12 glass`, `2.0 hours`, and `86 bpm`.

**The Native iOS Rule.** Text should look like a polished iOS app. Use system font stacks, normal letter spacing, familiar weights, and clear tap target labels.

**The Gentle Label Rule.** Labels are not shouting. Avoid all-caps metadata unless a platform pattern requires it.

**The Two-Line Hero Rule.** Large onboarding copy can wrap generously. Keep the line breaks intentional and avoid squeezing the display text into narrow measures.

## 4. Elevation

The system uses soft physical depth. Cards appear raised through subtle shadows, rounded corners, and slightly brighter surfaces, not heavy borders.

Most surfaces sit on the screen without visible outlines. Shadows are diffuse, low opacity, and warm-gray. Use enough depth to separate white cards from the near-white canvas, especially in stacked dashboard layouts.

### Named Rules

**The Soft Card Rule.** Cards should feel like lightweight ceramic tiles. Use soft shadows and rounded corners, not hard rules.

**The No Heavy Border Rule.** Borders are mostly invisible in the mockup. Use `rule-soft` only for chart guides, separators, and tiny control boundaries.

**The Floating Control Rule.** Circular icon buttons can float with a faint shadow. They should remain compact, tappable, and visually lighter than major cards.

**The Photo Depth Rule.** Food imagery may overlap content layers, but it must not obscure text or controls. The onboarding vegetable composition sits behind calorie callouts and under the bottom action tray.

## 5. Components

### Buttons
- **Shape:** pill or circle. The onboarding call-to-action is a wide white pill tray with circular controls at both ends.
- **Primary:** lime circular or pill button with black icon or text. Use for start, scan, selected navigation, and high-confidence forward actions.
- **Secondary:** white or soft-surface button with black icon or muted text. Use for calendar navigation, back, overflow, and non-primary actions.
- **Hover / Focus:** keep the rounded shape. Increase contrast, add a tight lime or ink focus ring, and avoid glow effects.
- **Disabled:** muted surface with muted ink. Do not use low-opacity lime on white if contrast becomes unclear.

### Cards / Containers
- **Corner Style:** 24-32px for major cards, 18-24px for compact stat cards, pill radius for controls.
- **Background:** card surface for white cards, soft lime for the weekly progress panel, screen white for the app canvas.
- **Shadow Strategy:** low, diffuse, and barely visible. Suggested shadow direction is downward with soft blur, matching the mockup's airy card depth.
- **Border:** usually none. Use faint rules only when necessary for chart structure or separation.
- **Internal Padding:** 16px for metric cards, 20-24px for larger panels, 28-32px for onboarding hero safe areas.

### Inputs / Fields
- **Style:** rounded, near-white or soft-surface fields with clear black text. Text entry should visually match the card system.
- **Focus:** lime ring or ink ring with strong contrast.
- **Error / Disabled:** semantic copy plus visible state color. Never rely only on a small icon color.
- **Voice Input:** microphone controls should use the circular button language. Active recording should use a clear state change, such as lime fill, pulsing ring, or coral stop state.

### Navigation
- **Style:** iOS bottom navigation with five items, line icons, labels, and one elevated central lime circular action.
- **Active Item:** lime circular button or lime-backed state. The mockup shows the central scan action as the most prominent nav element.
- **Inactive Items:** black line icons with small labels in muted ink. Keep all labels visible.
- **Top Bars:** simple status-aware headers with avatar, greeting, calendar button, notification button, centered title on detail pages, and circular back/overflow controls.

### Onboarding View
- **Composition:** brand mark at top left, tiny progress indicator at top right, large black display headline, food photography filling the lower half.
- **Hero Copy:** "Your Daily Guide to Smarter Eating." style, with an inline lime circular flame mark replacing one word or acting as a visual beat.
- **Imagery:** leafy greens, cauliflower, peppers, carrot, tomato, zucchini, and spinach-like leaves. The food should feel fresh, crisp, and high saturation.
- **Callouts:** small rounded white calorie bubbles, connected with thin gray stems and dots to food points.
- **CTA:** bottom white pill tray, lime circular leading icon, centered button text, and pale trailing confirmation circle.

### Home Dashboard View
- **Header:** avatar on the left, small greeting, bold user name, circular calendar button, circular notification button with tiny lime unread dot.
- **Weekly Progress Panel:** large soft-lime rounded rectangle with small icon label, two-line title, and circular progress ring showing days remaining.
- **Small Metrics:** two side-by-side white cards for steps and water. Each card has a colored icon chip, title, large number, and small unit.
- **Calendar Strip:** white rounded card with month label, left/right circular controls, weekday initials, date row, and lime selected date pill.
- **Meal Rows:** white rounded rows for breakfast and lunch, flame icon chip, calorie range, overlapping circular food thumbnails, and a plus button.

### Statistics View
- **Header:** centered title, circular back button on the left, circular overflow button on the right.
- **Calorie Card:** large white rounded panel with label, large calorie number, unit, target text, and vertical weekly bar chart.
- **Chart Bars:** pale lime bars for ordinary days, stronger lime for selected/high day, light gray hatched guide bars behind or between values.
- **Chart Labels:** percentages above bars and weekday labels below. Wednesday is the active day in the source image.
- **Metric Grid:** two-column compact cards for exercise, BPM, weight, and water. Each card uses a module icon chip, simple sparkline or icon row, and a large value where relevant.

## 6. Do's and Don'ts

**Do**
- Use near-white screens, white rounded cards, and a single strong lime accent.
- Keep layouts spacious, but preserve dashboard density for daily tracking.
- Use circular icon chips for health modules and quick actions.
- Use large tabular numerals for calories, steps, hydration, exercise, and BPM.
- Use real food photography for onboarding and meal thumbnails.
- Use soft shadows and large radii to separate cards from the page.
- Keep bottom navigation labels visible and predictable.
- Make voice, add, back, calendar, notifications, and overflow controls familiar platform actions.
- Include empty, loading, recording, transcribing, success, correction, and error states in this same visual language.

**Don't**
- Do not use dark-mode dashboards as the default for this visual direction.
- Do not replace food photography with generic line icons or abstract gradients.
- Do not use hard black borders, square brutalist cards, or heavy table rules.
- Do not use pure `#000` or pure `#fff` as app tokens; use the near-black and near-white values above.
- Do not use gradient text, side-stripe accent borders, glassmorphism, or decorative blur.
- Do not make every inactive state lime. Lime must communicate selection, progress, or action.
- Do not hide calorie targets, units, or dates behind icon-only UI.
- Do not let food images overlap labels, controls, or chart values.
