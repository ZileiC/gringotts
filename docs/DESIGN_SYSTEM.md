# Design system

Gringotts is dark-only, black-and-gold, and deliberately quiet. This document is the public
reference for how that is built; the implementation lives in
[`lib/ui/tokens.dart`](../lib/ui/tokens.dart) and the components under [`lib/ui/`](../lib/ui).

The rule that matters most: **`tokens.dart` is the only source of colour, type and spacing.**
A widget that hard-codes a hex value, a font size or a padding is a bug, not a style choice.

---

## 1. Foundations

### Colour

| Token | Value | Role |
|---|---|---|
| `canvas` | `#0C0B09` | app background (near-black, warm) |
| `surface` | `#14120E` | cards, panels |
| `elevated` | `#1D1A13` | inputs, chips, keypad keys |
| `overlay` | `#262117` | modal sheets |
| `hairline` | `#2C271C` | every border and divider in the app |
| `ink` | `#F4EFE2` | primary text (warm white, never pure `#FFF`) |
| `inkSecondary` | `#A69C86` | labels, secondary text, muted icons |
| `goldAccent` | `#E3C36B` | champagne gold: borders, labels, accents |
| `goldDeep` | `#9C7A24` | the deep end of the two brand gradients |
| `goldContainer` | `#2A2314` | faint gold wash (selected states) |
| `onGoldContainer` | `#EDD9A3` | text on that wash |
| `onGold` | `#171204` | text on solid gold |
| `semanticExpense` | `#E5484D` | overspend, negative balances |
| `semanticIncome` | `#46A758` | income, positive balances |

### Gold discipline

Gold is expensive, so it is spent sparingly:

- **Allowed**: hairlines, borders, chart accents, active tab labels, focus rings, the record key,
  and four named gradient moments (hero allowance · net asset value · the record key · the chart
  gold scale).
- **Forbidden**: body text, dividers, large fills, keypad faces, anything animated in a loop.
- Structural separation is done with `hairline`, not with colour.

### Depth

There are no shadows in this app. Depth is expressed with hairlines, tonality
(`canvas → surface → elevated → overlay`) and a single 0.96 press scale. Gradients are banned except
for the four named moments above; glow and looping animation are banned outright.

---

## 2. Typography

| Role | Family | Size / weight |
|---|---|---|
| Brand moments — hero allowance, net asset value | Playfair Display | 48 / 600, tabular figures |
| Wordmark, splash | Playfair Display | 600 |
| Quick-entry amount | Playfair Display | 42 / 600 |
| Keypad digits | Playfair Display | 26 / 600 (symbols stay sans) |
| Lead / section | MiSans | 21 / 16 |
| Body | MiSans | 16 / 400 |
| Labels, tab labels | MiSans | 12 / 500–600, letter-spacing +0.08em |
| Numerals anywhere | MiSans | tabular figures, always |

Two rules do the work here:

1. **Serif only for brand moments.** A number that the user is meant to *feel* may be Playfair; a
   number the user is meant to *read* is sans with tabular figures so digits never jitter.
2. **Small Chinese labels need air.** The tab labels are 12 pt with `+0.08em` tracking; tightening
   that to zero is the fastest way to make the interface look cheap.

---

## 3. Space and shape

| Scale | Values |
|---|---|
| Spacing | `xs 4` · `s 8` · `m 16` · `l 24` · `xl 32` · `xxl 48` |
| Radius | `s 8` · `m 12` · `l 16` · `pill 999` · `key 17` |
| Touch | every interactive target ≥ 48 × 48 (a 36 pt ring is drawn inside a 48 pt hit area) |

---

## 4. Motion

- **One-shot only.** Nothing loops, nothing breathes, nothing pulses.
- Press feedback: 0.96 scale (keys, tabs, cards) or a colour change (outline keys).
- One shared timing family: 120 ms for key feedback, 180 ms for the tab slider, 180–240 ms for
  sheet transitions.
- **`reduce-motion` is a first-class path**, not an afterthought: with
  `MediaQuery.disableAnimationsOf(context)` true, every duration collapses to zero, scale effects are
  dropped, sheet transitions become fades and the colour changes stay.

---

## 5. Component language

- **Hairline surfaces.** Cards are `surface` + a 1 px `hairline` border and 12 pt radius. No shadow,
  no gradient, no border-radius above 18 except pills.
- **Outline keys.** Secondary and confirm actions are outlined — 1 px `goldAccent` border, gold label,
  transparent fill (the quick-entry confirm key, the export key, the record key).
- **The record key.** A gold ring with a vector plus, no text. The plus is drawn as two stroked lines
  with round caps and endpoints inset by half a stroke, because a font's `+` is never optically
  centred across platforms.
- **Hand-drawn tab icons.** The three navigation glyphs (trend line, stacked frames, three bars) are
  drawn in-house at 1.25 px stroke rather than pulled from a general-purpose icon set, so the tab bar
  reads as part of the type rather than as a toolbar.
- **Selection is a line, not a fill.** The active tab is gold text plus a 16 × 1.5 gold underline that
  slides between positions; selected month cells take a gold border with a faint gold wash — the same
  language as the category grid.

---

## 6. Data presentation

The numbers are the product, so their rules are explicit.

- **Money is integer cents.** Formatting happens at the edge; there is no float in the money path.
- **The allowance is derived, never stored.** `budget = income − planned savings`;
  `daily allowance = budget ÷ days in the selected month`; the live remaining allowance is that minus
  what has been spent. Nothing here is persisted — every figure is recomputed on read.
- **Spend bars against the allowance.** Each day is one bar; the segment above that day's allowance is
  drawn in `semanticExpense`, so "did I overspend today" is visible without arithmetic. The allowance
  itself is a 1 px gold dashed rule at its value.
- **One true two-line trend.** The expense line and the income line share an axis scaled to
  `max(expense, amortised income) × 1.15`. The income line carries the monthly income spread across
  the month's days, so it reflects reality instead of resting on the axis. One-off income far above
  the baseline is annotated with a dashed leader and a dot rather than allowed to blow up the scale.
- **Axes tell the truth.** The money axis always shows ticks; the category axis places every label
  exactly on its data point (fractional label intervals are banned — they make the axis drift).
- **Positive and negative read differently.** A negative net balance takes `semanticExpense`, zero and
  positive stay `ink`.
- **Categories share one palette.** Charts use a six-step gold scale with a neutral fallback, never a
  rainbow.

---

## 7. Accessibility

- Contrast, measured against the surfaces they are used on (WCAG 2.1):

| Pair | Ratio |
|---|---|
| `ink` on `canvas` | 17.1 : 1 |
| `inkSecondary` on `canvas` | 7.2 : 1 |
| `goldAccent` on `canvas` | 11.5 : 1 |
| `onGold` on `goldAccent` | 10.9 : 1 |
| `semanticExpense` on `canvas` | 5.0 : 1 |
| `semanticIncome` on `canvas` | 6.5 : 1 |
| `goldDeep` on `canvas` (gradient low end) | 4.9 : 1 |

  Every pairing used for text clears AA (4.5 : 1); the lowest value in the system is the deep end of
  the gold gradient at 4.9 : 1.
- Touch targets are ≥ 48 pt; the record key and the tab bar are reachable one-handed.
- Dark-only is a deliberate constraint, not a missing feature: there is no light theme to fall back
  to, so contrast is tuned once and measured.
- Motion degrades fully under `reduce-motion` (see §4).

---

## 8. What is deliberately absent

No shadows · no gradient fills outside the four named moments · no glow or neon · no looping
animation · no red/green status colours beyond the two semantic tokens · no icon-only buttons without
a hit area · no light theme · no second accent colour.
