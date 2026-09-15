# Design system

Every colour, font size and spacing value in Gringotts comes from
[`lib/ui/tokens.dart`](../lib/ui/tokens.dart). This document lists those values and the rules the
app follows when it uses them. The components live in [`lib/ui/`](../lib/ui).

## Colour

| Token | Value | Where it is used |
|---|---|---|
| `canvas` | `#0C0B09` | app background |
| `surface` | `#14120E` | cards and panels |
| `elevated` | `#1D1A13` | inputs, chips, keypad keys |
| `overlay` | `#262117` | modal sheets |
| `hairline` | `#2C271C` | every border and divider |
| `ink` | `#F4EFE2` | primary text |
| `inkSecondary` | `#A69C86` | labels, secondary text, muted icons |
| `goldAccent` | `#E3C36B` | borders, labels, chart accents |
| `goldDeep` | `#9C7A24` | the deep end of the text gradient |
| `goldContainer` | `#2A2314` | faint gold background for selected states |
| `onGoldContainer` | `#EDD9A3` | text on that background |
| `onGold` | `#171204` | text on solid gold |
| `semanticExpense` | `#E5484D` | overspending, negative balances |
| `semanticIncome` | `#46A758` | income, positive balances |

### Where gold is allowed

Borders, hairlines, chart accents, the active tab label, focus rings and the record key. There is
also one text gradient, `AppGradient.goldText`, used on the home allowance and the net asset value.

It is not used for body text, dividers, keypad faces or large fills. Separation between sections is
done with `hairline`.

### Depth

There are no shadows. Depth comes from hairlines and from stepping through the surface colours
(`canvas`, `surface`, `elevated`, `overlay`), plus a 0.96 press scale on keys and cards. Glow and
looping animation are not used at all.

## Type

| Role | Family | Size and weight |
|---|---|---|
| Home allowance, net asset value | Playfair Display | 48 / 600, tabular figures |
| Wordmark, splash | Playfair Display | 600 |
| Quick-entry amount | Playfair Display | 42 / 600 |
| Keypad digits | Playfair Display | 26 / 600, symbols stay sans |
| Section headings | MiSans | 21 / 16 |
| Body | MiSans | 16 / 400 |
| Tab labels and small labels | MiSans | 12 / 500 to 600, letter-spacing +0.08em |
| Numbers in tables and lists | MiSans | tabular figures |

Playfair Display appears in four places, all brand moments: the wordmark, the two large brand
numbers and the keypad. Every number the user compares against another number is sans with tabular
figures, so digits keep the same width as they change.

Tab labels are set at 12 with `+0.08em` tracking. Chinese characters at that size need the extra
spacing to stay legible.

## Spacing and shape

| Scale | Values |
|---|---|
| Spacing | `xs 4`, `s 8`, `m 16`, `l 24`, `xl 32`, `xxl 48` |
| Radius | `s 8`, `m 12`, `l 16`, `pill 999`, `key 17` |
| Touch targets | at least 48 x 48, so a 36 pt ring is drawn inside a 48 pt hit area |

## Motion

Everything is one-shot. Nothing loops, pulses or breathes.

- Pressing a key, tab or card scales it to 0.96. Outline keys change colour instead of moving.
- Key feedback runs at 120 ms, the tab underline slides over 180 ms, sheets take 180 to 240 ms.
- With `MediaQuery.disableAnimationsOf` true, every duration collapses to zero, scale effects are
  dropped, sheets fade in and the colour changes stay. This path is tested.

## Components

- Cards are `surface` with a 1 px `hairline` border and a 12 pt radius. No shadow, no gradient.
- Secondary and confirm actions are outlined: 1 px `goldAccent` border, gold label, transparent fill.
  The quick-entry confirm key, the export key and the record key all follow this.
- The record key is a gold ring with a plus drawn as two stroked lines with round caps, inset by half
  a stroke so the glyph is optically centred. A font's `+` is not centred the same way on every
  platform, so it is drawn instead.
- The three navigation icons (trend line, stacked frames, three bars) are drawn in-house at 1.25 px
  rather than taken from a general icon set, so the tab bar matches the type.
- The active tab is gold text with a 16 x 1.5 gold underline that slides between positions. A
  selected month cell takes a gold border and a faint gold background, the same treatment the
  category grid uses.

## Money and charts

- Money is an integer number of cents, formatted at the edge. There are no floats in the money path.
- The allowance is derived: `budget = income - planned savings`, `daily allowance = budget / days in
  the month`, and the live remaining allowance is that minus what has been spent. None of it is
  stored.
- The first statistics chart draws one bar per day, with the part above that day's allowance in
  `semanticExpense`, and the allowance itself as a 1 px gold dashed rule. Overspending is visible
  without arithmetic.
- The second chart draws spending and income as two lines. The income line carries the monthly income
  spread across the month's days. One-off income is not plotted: it gets a dashed leader, a dot and
  its value, because a single large amount would otherwise set the scale for the whole chart.
- The y scale comes from `ChartScale.resolve`, which takes every value that will be drawn. If the
  largest value is more than 2.5 times the next distinct value, the scale is set from the smaller one
  and the outlier is clamped to the top of the plot with its real value printed next to it.
- The money axis always shows ticks, and the category axis puts every label on its data point.
- A negative net balance takes `semanticExpense`; zero and positive stay `ink`.
- Charts use a six step gold scale with a neutral fallback.

## Accessibility

Contrast, measured against the surfaces the colours are used on:

| Pair | Ratio |
|---|---|
| `ink` on `canvas` | 17.1 : 1 |
| `inkSecondary` on `canvas` | 7.2 : 1 |
| `goldAccent` on `canvas` | 11.5 : 1 |
| `onGold` on `goldAccent` | 10.9 : 1 |
| `semanticExpense` on `canvas` | 5.0 : 1 |
| `semanticIncome` on `canvas` | 6.5 : 1 |
| `goldDeep` on `canvas` | 4.9 : 1 |

All of these clear AA for text. The lowest value is the deep end of the gold gradient at 4.9 : 1.
Touch targets are at least 48 pt. The app is dark only, so contrast is measured once against the real
surfaces rather than against a light theme that does not exist.

## Not used

No shadows. No gradient fills beyond the one text gradient. No glow or neon. No looping animation.
No colours beyond the fourteen tokens above. No light theme. No second accent colour.
