# Third-party notices

Gringotts is MIT licensed (see [`LICENSE`](LICENSE)). It bundles or depends on the following
third-party work, which keeps its own licence. The canonical dependency list is
[`pubspec.yaml`](pubspec.yaml).

## Bundled fonts (redistributed inside the APK)

| Asset | Owner | Licence | Notes |
|---|---|---|---|
| `fonts/MiSans-Regular.ttf`, `MiSans-Medium.ttf`, `MiSans-Demibold.ttf` | Xiaomi Inc. | MiSans font licence (free for commercial use) | Subset to the glyphs this UI actually uses; the full licence text ships alongside as [`fonts/MiSans-LICENSE.pdf`](fonts/MiSans-LICENSE.pdf) |
| `fonts/PlayfairDisplay-SemiBold.ttf`, `PlayfairDisplay-Bold.ttf` | Claus Eggers Sørensen / Google Fonts | SIL Open Font License 1.1 | Used for brand moments only (hero allowance, net value, wordmark, keypad digits) |
| `MaterialIcons-Regular.otf` (Flutter asset) | Google Inc. | Apache License 2.0 | Only a small subset of icons is referenced by the app |

If you redistribute a build of Gringotts, keep these files and their licence texts with it.

## Runtime libraries

| Package | Licence |
|---|---|
| Flutter / Dart SDK, `flutter_test`, `integration_test` | BSD-3-Clause |
| `drift`, `sqlite3_flutter_libs`, `sqlite3` | MIT |
| `flutter_riverpod` | MIT |
| `fl_chart` | MIT |
| `intl`, `crypto`, `path`, `path_provider` | BSD-3-Clause / MIT as per package |
| `flutter_secure_storage` (M2, planned) | BSD-3-Clause |

Each package's full licence text is available from its pub.dev page and from the package cache in
your Flutter installation (`~/.pub-cache`).

## Development-only tooling

Not shipped inside the APK: `build_runner`, `drift_dev`, `flutter_lints`, the Python helpers under
[`tool/`](tool) (media cleanup, database housekeeping, screenshot placeholders) — all of which are
either MIT/BSD or project-owned scripts.
