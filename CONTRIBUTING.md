# Contributing to Gringotts

Thanks for taking a look. Gringotts is a small, opinionated codebase; the rules below are what keep
it that way. They are short on purpose.

## Before you start

- **Structural changes: open an issue first.** New pages, new tables, new dependencies and anything
  that touches the design system need a decision before code — otherwise the PR will be asked to
  restart from the issue.
- **Small fixes are welcome directly**: typos, accessibility details, test repairs, small bugs with a
  reproduction.

## Development setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after any drift schema change
flutter analyze
flutter test
flutter test integration_test/<name>_test.dart -d windows   # real-engine evidence scripts
flutter build apk --release
```

Requirements: Flutter 3.x stable, the Android SDK for APKs, and the Windows desktop toolchain if you
want to run the integration scripts the way this project does.

## House rules

1. **Source and comments are English.** UI copy may be Chinese; product strings are not translated
   in code.
2. **Design tokens are the only source of colour, type and spacing.** Import
   `lib/ui/tokens.dart`; never hard-code a hex value, font size or padding in a widget.
3. **No shadows, no gradient fills, no glow, no looping animation.** Gold is a border, a label, a
   hairline or a named gradient moment — never body text or a large fill. Serif (Playfair) is
   reserved for brand moments.
4. **Data rules are non-negotiable**: integer cents, UUID keys, `created_at` / `updated_at` /
   `deleted_at` on every table, no physical deletes, and derived values are computed on read rather
   than stored.
5. **Never commit secrets.** No API keys, no `.env`, no keystores, no device dumps. If you need a
   credential to test something, keep it in `flutter_secure_storage` or an untracked local file.

## Expectation: evidence, not vibes

A pull request that changes behaviour is expected to carry:

- `flutter analyze` at zero issues and `flutter test` green (state the test count),
- a **value-level assertion** for the behaviour you changed — a widget or service test that checks
  the number, colour, geometry or database row, not a screenshot,
- frame-based evidence only if a value assertion cannot express the claim, with the raw PNGs kept out
  of git and each frame's md5 recorded next to the run,
- and, for migrations, a test against a real previous-version database file.

Screenshots are welcome as illustration, but they never stand in for an assertion here.

## Pull requests

- One ticket, one purpose. Keep unrelated cleanups out.
- Write the commit subject as `T-xx: <what changed>` when working from a ticket, or a plain
  imperative subject otherwise.
- Run the affected integration scripts and say which ones you ran **and which you deliberately did
  not** — the difference matters more than the count.
- If you had to weaken or delete an assertion, say so explicitly. Silently relaxing a test is the one
  thing that will get a PR closed without review.

## Reporting bugs

Use the issue templates. A useful report includes: what you did, what you expected, what happened,
your device/OS and app build, and (for anything visual) a capture plus the screen it came from.
