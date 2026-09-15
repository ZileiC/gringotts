<!--
Thanks for the pull request. Gringotts asks for evidence rather than vibes — the checklist below is
what a review will actually look for.
-->

## What this changes

<!-- One paragraph. If it maps to a ticket, name it (e.g. T-21). -->

Ticket / issue:

## Why

<!-- The problem, not the patch. Link the issue if there is one. -->

## How it was verified

| Check | Result |
|---|---|
| `flutter analyze` | <!-- e.g. No issues found --> |
| `flutter test` | <!-- e.g. 237 passed --> |
| Integration scripts run | <!-- name them, and name the ones you deliberately skipped --> |
| Migration tested on a real previous-version file | <!-- yes / n/a --> |

**Value-level assertion added or changed:**

<!-- Name the test and what it pins down (a number, a colour, a geometry, a database row). -->

## Design and data checklist

- [ ] No hard-coded colour, font size, spacing or radius — everything comes from `lib/ui/tokens.dart`
- [ ] No shadows, gradient fills, glow or looping animation introduced; serif used only for brand moments
- [ ] Money stays integer cents; no float anywhere in the money path
- [ ] No physical deletes; new or changed rows still behave as tombstones
- [ ] Nothing derived is persisted (budget, allowances, cost-per-day, chart series are computed on read)
- [ ] No secret, key, `.env` or keystore added to the repository
- [ ] Source and comments in English

## Anything else

<!-- Trade-offs you made, assertions you had to relax (say so explicitly), follow-ups you are not doing here. -->
