# Changelog

All notable changes to Gringotts are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project is milestone-driven and has
not cut a tagged release yet, so entries are grouped by milestone instead of by semantic version.

## [Unreleased] — M2.0 · Bring-your-own AI

Design in progress. Planned, in dispatch order: AI provider configuration (provider / baseURL /
apiKey / model, OpenAI-compatible) · AI analysis and suggestions on the analysis page ·
conversation window · period-report commentary · recurring bills and subscriptions · home-screen
widget · local encryption. The milestone plan and its current state live in the
[README roadmap](README.md#roadmap).

Ground rules already frozen for this milestone: the model receives aggregated statistics only —
never raw transactions — and the API key lives in `flutter_secure_storage`, never in logs, the
repository or the APK's assets.

## M1.1 — in progress

### Fixed
- **Statistics net balance now counts the monthly budget income.** The summary card showed the
  guarantee income (monthly income from the budget) as its own line but excluded it from the net
  figure, so the card contradicted the trend chart above it. Net is now
  `guarantee income + one-off income − spending` for the selected period, with no budget treated as
  zero rather than as a guess. Planned savings stay out of it: they reduce the spendable budget, they
  are not spending.

## M2.0 pre-wave — 2026-09-15

### Added
- **Budget engine**: monthly income plus planned savings produce a fixed daily baseline and a live
  remaining allowance; no budget means an honest onboarding state rather than invented numbers.
- **Analysis home**: allowance hero, budget progress, today's spend, today's category donut, and the
  reserved AI slot.
- **Ledger**: month → day → entry hierarchy, type filters that never change the grouping, full-field
  row editing and tombstone deletion.
- **Navigation shell**: analysis / assets / statistics as peer tabs, with the record key belonging to
  the analysis page alone and the ledger hanging off the statistics page.
- **Statistics rebuilt** (T-21): the day view is the whole selected month instead of a fixed seven-day
  window; the bottom axis labels sit exactly on their data points; the money axis has real ticks; a
  spend-bar chart measures each day against that day's allowance and turns the over-limit segment
  red; and the trend chart's income line now carries the amortised monthly income instead of resting
  on the axis. One shared month drives analysis, ledger and statistics.
- **Savings → asset** (T-21): a month-end card can turn the planned savings into a real asset in one
  tap; declining writes nothing at all.
- **Design system**: hand-drawn 1.25 px tab icons, a plus-only record key drawn as a vector glyph,
  and the UI font moved to a subset [MiSans](https://hyperos.mi.com/font) (~14 KB per weight).

### Changed
- Quick entry writes an authoritative record on confirm; the draft pipeline (review page, bulk
  category back-fill, "needs attention" badge) was removed.
- Statistics export key became a hairline gold outline key; a negative net balance now takes the
  semantic expense colour.

### Fixed
- Statistics day view no longer drifts its axis labels (`interval = length / 6` was the root cause),
  and the vertical axis is no longer rendered without ticks (`showTitles: false`).
- `updateFields` could silently clear a draft's merchant and note; the method is gone.
- The month sheet no longer overflows on short viewports (landscape phones, short windows): it
  scrolls inside the sheet while keeping 52 dp cells.
- Assets net value restored to the brand serif + gold gradient treatment.
- Five integration scripts that had silently rotted since the navigation and quick-entry changes were
  repaired rather than skipped.

## M1.0 — 2026-09-08

### Added
- Local core ledger: three-second quick entry with mixed-input parsing, review flow, history,
  assets with cost-per-day and held days, statistics (day / month / year, category share), CSV +
  JSON export, quick-settings tile and launcher shortcut.
- Brand layer: black-gold dark theme, splash wordmark, application icons, motion baseline with a
  `reduce-motion` path throughout.
- Data foundation: UUID primary keys, `created_at` / `updated_at` / `deleted_at` tombstones on every
  table, integer-cent money, additive migrations, photo content-hashing with compression.

### Notes
- M1.0 was closed before this repository went public; the milestone plan in the
  [README](README.md#roadmap) is the durable record of what shipped in it.
