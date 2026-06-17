# Design

## Theme

Grounded farm-market daylight. Mobile-first product UI for rural farmers using phones outdoors. Pure white surface for maximum sunlight legibility; a deep sun-cured **olive** primary carries the brand (fields, produce, honest weight); a **burnt-terracotta** accent provides the warm-earth counterpoint and marks money/offers. Calm, high-contrast, infrastructure-not-startup. Light mode only for v1 (outdoor readability beats a dark theme here).

Mood phrase: *"early-morning vegetable market — dew on green crates, dust, honest weight, sun coming up."*

## Color

OKLCH throughout. Strategy: **Committed-restrained** — olive primary on key actions/nav/headers, white/near-white surfaces, terracotta reserved for value/offer emphasis. Status never relies on color alone (always icon + label).

```css
:root {
  /* surfaces */
  --bg:          oklch(1 0 0);            /* pure white */
  --surface:     oklch(0.976 0.006 120);  /* faint olive wash panels */
  --surface-2:   oklch(0.955 0.008 120);  /* deeper inset / pressed */
  --line:        oklch(0.905 0.008 120);  /* hairline borders */

  /* text */
  --ink:         oklch(0.24 0.02 130);    /* body  ~12:1 on white */
  --muted:       oklch(0.50 0.018 130);   /* secondary ~4.7:1 */

  /* brand */
  --primary:        oklch(0.46 0.105 120); /* deep olive — holds white text */
  --primary-press:  oklch(0.40 0.10 120);
  --primary-tint:   oklch(0.955 0.022 120);/* selected/active wash */
  --on-primary:     oklch(0.99 0.004 120);

  /* accent — money / offers */
  --accent:       oklch(0.605 0.15 52);    /* burnt terracotta */
  --accent-press: oklch(0.55 0.145 52);
  --accent-tint:  oklch(0.955 0.028 52);
  --on-accent:    oklch(0.99 0.006 52);

  /* status (always paired with icon + label) */
  --ok:     oklch(0.55 0.12 150);  /* verified / paid / completed */
  --warn:   oklch(0.66 0.13 75);   /* pending / awaiting */
  --danger: oklch(0.55 0.18 28);   /* dispute / cancelled */
}
```

## Typography

One family, multiple weights — **Hanken Grotesk** (warm humanist grotesque; grounded, highly legible, avoids the Inter cliché). Tabular figures for prices/quantities. Devanagari/Indic fallback via **Noto Sans** for multilingual.

```css
--font: "Hanken Grotesk", "Noto Sans", system-ui, sans-serif;
--num: "Hanken Grotesk", system-ui, sans-serif; /* font-variant-numeric: tabular-nums */
```

Scale (mobile-first, clamp): display `clamp(1.5rem, 6vw, 2rem)` / 600–700; section `1.1875rem`/600; body `1rem`/400; label `0.8125rem`/500; caption `0.75rem`. `text-wrap: balance` on headings, `pretty` on prose. Line length capped 65ch in prose blocks.

## Spacing & Layout

4px base scale (4/8/12/16/20/24/32/40/48). Single-column mobile shell, max content width 460px centered (so it reads well on tablet/desktop too). Sticky top app bar + sticky bottom tab nav. Tap targets ≥44px. Radii: 8 (controls) / 14 (cards) / 20 (sheets). Flexbox for 1D rows, Grid only for the 2-col quick-stats and quality-grade picker.

## Components

App bar, bottom tab nav, live-price strip (horizontal scroll), primary action button (FAB-style "List produce"), listing card (photo + crop + qty + price + grade chip + status), offer/order row, multi-step Create Listing sheet (crop → details → quality → photos → price-with-market-context → review), quality-grade segmented control, photo uploader, status pill (icon+label), empty state.

## Motion

CSS-only, ease-out-quart. Staggered fade-up on the listing feed (50ms step), sheet slides up with backdrop fade, button press scale 0.97, value/price count emphasis. All gated behind `@media (prefers-reduced-motion: reduce)` → instant/crossfade. No bounce.

## Accessibility

WCAG 2.1 AA. Body ≥4.5:1 (most ≥7:1). Status = icon + text + color. Focus-visible rings (2px accent). ≥44px targets. Reduced-motion alternatives. Large-icon mode and voice are roadmap; layout leaves room for them.
