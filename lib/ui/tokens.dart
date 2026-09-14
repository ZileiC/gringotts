import 'package:flutter/material.dart';

/// Design tokens for the Gringotts black-gold identity (T-09A palette).
///
/// Single source of truth for colors, typography sizes, spacing and radii.
/// Widgets must never hard-code these values; the whole app reskins by
/// editing this file only.
///
/// Palette provenance (DESIGN_T09.md): warm near-black vault layers plus a
/// champagne gold light system, derived from the user-approved brand mark.
abstract final class AppColors {
  // Brand gold system.
  /// Champagne gold brand seed used for the Material color scheme.
  static const Color seedGold = Color(0xFFD4AF37);

  /// Interactive gold on dark surfaces (brighter, WCAG-AA on canvas).
  static const Color goldAccent = Color(0xFFE3C36B);

  /// Pressed state / gradient deep end.
  static const Color goldDeep = Color(0xFF9C7A24);

  /// Gold-tinted container behind selected chips and badges.
  static const Color goldContainer = Color(0xFF2A2314);

  /// Text/icon color placed on gold containers.
  static const Color onGoldContainer = Color(0xFFEDD9A3);

  /// Text/icon color placed on solid gold fills.
  static const Color onGold = Color(0xFF171204);

  // Layer system (warm vault blacks; never pure #000).
  /// Deepest page background.
  static const Color canvas = Color(0xFF0C0B09);

  /// Card and list-item surface.
  static const Color surface = Color(0xFF14120E);

  /// Keypad keys and raised components.
  static const Color elevated = Color(0xFF1D1A13);

  /// Sheets and dialog surface.
  static const Color overlay = Color(0xFF262117);

  /// Hairline borders and dividers (warm gray-gold, NOT gold).
  static const Color hairline = Color(0xFF2C271C);

  // Text system (warm whites; never pure #FFF).
  /// Primary text.
  static const Color ink = Color(0xFFF4EFE2);

  /// Secondary/muted text.
  static const Color inkSecondary = Color(0xFFA69C86);

  // Semantic colors.
  /// Expense / loss.
  static const Color semanticExpense = Color(0xFFE5484D);

  /// Income / profit.
  static const Color semanticIncome = Color(0xFF46A758);

  // Chart gold scale (DESIGN_T09 section 7: the only chart gold exemption).
  static const List<Color> goldChartScale = <Color>[
    Color(0xFF9C7A24),
    Color(0xFFC9A54E),
    Color(0xFFE3C36B),
    Color(0xFFF0E0AC),
    Color(0xFFD4AF37),
    Color(0xFFB8952E),
  ];

  /// Neutral gray fallback beyond the gold scale (uncategorized etc.).
  static const List<Color> neutralChartScale = <Color>[
    Color(0xFF5A564C),
    Color(0xFF6E6A5E),
    Color(0xFF827E72),
  ];

  /// Pie label color for gold-scale slices (dark ink on light gold).
  static Color chartSliceLabel(int index) =>
      index < goldChartScale.length ? onGold : ink;

  /// Canonical chart palette: gold scale first, neutral grays beyond.
  ///
  /// The single colour mapping consumed by the statistics pie and the home
  /// donut (via the shared `StatisticsService.chartSlices` color index), so no
  /// chart can drift into an off-brand rainbow.
  static const List<Color> chartPalette = <Color>[
    ...goldChartScale,
    ...neutralChartScale,
  ];

  /// Deterministic slice colour for a palette [index].
  static Color chartColor(int index) =>
      chartPalette[index % chartPalette.length];

  /// Slice colour with the neutral-gray fallback for the merged "其他" slice
  /// (de-emphasised on purpose, matching the approved home frame).
  static Color chartSliceColor(int index, {bool neutral = false}) => neutral
      ? neutralChartScale[index % neutralChartScale.length]
      : chartColor(index);

  // Backwards-compatible aliases used across existing pages.
  /// Deprecated alias for [surface].
  static const Color surfaceBlack = canvas;

  /// Deprecated alias for [surface].
  static const Color surfaceDark = surface;

  /// Deprecated alias for [elevated].
  static const Color surfaceElevated = elevated;

  /// Deprecated alias for [ink].
  static const Color textPrimary = ink;

  /// Deprecated alias for [inkSecondary].
  static const Color textSecondary = inkSecondary;
}

/// Spacing scale (4pt grid).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Bottom inset for a floating snackbar on pages that own a bottom CTA:
  /// clears the 56 pt confirm button (plus its 16 pt padding) so the snackbar
  /// never covers the one-shot sheen (T-09C2 ruling, landed in T-09D).
  static const double snackBarCtaInset = 88;

  /// Bottom tab row height (DESIGN_MAIN section 8.3): the bar has exactly this
  /// height on every tab, so switching can never make the bar jump.
  static const double navTabHeight = 56;

  /// Analysis top bar height (DESIGN_MAIN section 8.2): 8pt top padding plus a
  /// 48pt content row, held constant while the page content scrolls.
  static const double topBarHeight = 56;

  /// Record key (DESIGN_MAIN section 8.2): a 36pt visual ring inside a 48x48
  /// transparent hit target, with the vector plus drawn at 16x16.
  static const double recordKeyVisual = 36;
  static const double recordKeyHit = 48;
  static const double recordRingStroke = 1.25;
  static const double recordPlusSize = 16;
  static const double recordPlusStroke = 1.75;

  /// Bottom tab line icons (DESIGN_MAIN section 8.3): 20x20, 1.25pt stroke.
  static const double tabIconSize = 20;
  static const double tabIconStroke = 1.25;

  /// Gold selection line under the active tab (DESIGN_MAIN section 8.3):
  /// 16 x 1.5, sliding 180ms between tabs.
  static const double tabIndicatorWidth = 16;
  static const double tabIndicatorHeight = 1.5;

  // Speed-entry page geometry (T-11 / DESIGN_MAIN section 4.1-4.2).
  /// Project-name input height.
  static const double entryNameHeight = 44;

  /// Confirm button height.
  static const double entryConfirmHeight = 54;

  /// Category grid cell height (3x3, all nine visible).
  static const double categoryCellHeight = 58;

  /// Keypad horizontal gap between keys.
  static const double keypadGapX = 16;

  /// Keypad vertical gap between rows (row-gap > col-gap optic balance).
  static const double keypadGapY = 10;

  /// Horizontal/vertical gap inside the category grid.
  static const double categoryGap = 6;

  /// Vertical padding of the budget-link row.
  static const double linkRowPadding = 6;

  /// Breathing room above and below the key block ("ma", not leftover space).
  static const double keypadVertMargin = 12;

  /// Speed-entry page horizontal padding.
  static const double entryPagePadH = 14;

  /// Speed-entry page vertical padding.
  static const double entryPagePadV = 11;
}

/// Motion durations shared by the T-14b chrome (DESIGN_MAIN sections 8.2-8.3).
abstract final class AppMotion {
  /// Record key: the ring interior fades in goldContainer on press, once
  /// (120ms). reduce-motion keeps the colour change but drops the fade.
  static const Duration recordPressFade = Duration(milliseconds: 120);

  /// Bottom tab: the gold indicator slides to the selected tab (180ms).
  /// reduce-motion switches without displacement.
  static const Duration tabIndicator = Duration(milliseconds: 180);
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double pill = 999;

  /// Keypad key corner radius (T-11 section 4.2: softer than a card, more
  /// restrained than a pill - "soft slate", not a toy key).
  static const double key = 17;
}

/// Gradients. DESIGN_MAIN.md section 7 caps gold-gradient definitions at four
/// (home hero allowance / assets net value / bottom-bar 记一笔 / chart gold
/// scale) and prohibits them everywhere else, so the two text moments share
/// this one definition instead of each page rolling its own.
abstract final class AppGradient {
  /// Brand gold text gradient (home hero allowance + assets net value).
  static const LinearGradient goldText = LinearGradient(
    colors: [AppColors.goldAccent, AppColors.goldDeep],
  );
}

/// Typography scale (Perfect Fourth, base 16; DESIGN_T09.md section 2).
abstract final class AppFont {
  /// Keypad amount display (speed-entry home).
  static const double display = 56;

  /// The brand serif number: the two gold-gradient amounts (home hero live
  /// allowance + assets net value, DESIGN_MAIN.md section 6/7). Identical in
  /// both places by construction - brand_number_test locks the pair.
  static const double brandNumber = 48;

  /// H3 level.
  static const double h3 = 38;

  /// H4 level.
  static const double h4 = 28;

  /// Lead paragraph.
  static const double lead = 21;

  /// Body text.
  static const double body = 16;

  /// Small body text.
  static const double bodySm = 14;

  /// Caption / eyebrow.
  static const double caption = 12;

  // T-14b UI font (DESIGN_MAIN section 8.4): MiSans is subset to the glyphs
  // the bottom tabs and the month button actually render; Playfair stays
  // reserved for brand moments.
  /// Family name declared in pubspec.yaml (fonts/MiSans-*.ttf).
  static const String uiFamily = 'MiSans';

  /// Bottom tab label: 12 / +0.08em tracking (0.96 logical px at 12).
  static const double tabLabel = 12;
  static const double tabLetterSpacing = 0.96;

  /// Reserved tab label line box, part of the frozen 56pt tab budget
  /// (icon 20 + gap 4 + line 16 + padding 8 + 8).
  static const double tabLabelHeight = 16;

  /// Keypad key caps.
  static const double keypad = 22;

  // Speed-entry typography (T-11 / DESIGN_MAIN section 4.2 / section 7).
  /// Amount display on the speed-entry page (Playfair 600, serif moment 4).
  static const double amountEntry = 42;

  /// Keypad number glyphs (Playfair 600; serif moment 5).
  static const double keyNumber = 26;

  /// Keypad symbol glyphs (`.` / backspace) stay sans for legibility.
  static const double keySymbol = 21;

  /// Category grid icon size.
  static const double categoryIcon = 19;

  /// Category grid label size.
  static const double categoryLabel = 11.5;

  /// Page titles / buttons.
  static const double title = 18;

  /// Tabular figures for money amounts (anti-jitter rule).
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];
}

/// Builds the app-wide dark Material 3 theme from tokens.
///
/// The only theme in the app; no theme switching entry exists.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedGold,
    brightness: Brightness.dark,
  ).copyWith(
    surface: AppColors.surface,
    surfaceContainerHighest: AppColors.elevated,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSecondary,
    outline: AppColors.hairline,
    primary: AppColors.goldAccent,
    onPrimary: AppColors.onGold,
    primaryContainer: AppColors.goldContainer,
    onPrimaryContainer: AppColors.onGoldContainer,
    secondary: AppColors.goldAccent,
    onSecondary: AppColors.onGold,
    secondaryContainer: AppColors.goldContainer,
    onSecondaryContainer: AppColors.onGoldContainer,
    error: AppColors.semanticExpense,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  final textTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontSize: AppFont.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.4,
      color: AppColors.ink,
      fontFeatures: AppFont.tabularFigures,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontSize: AppFont.h3,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: AppColors.ink,
      fontFeatures: AppFont.tabularFigures,
    ),
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontSize: AppFont.h4,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.ink,
      fontFeatures: AppFont.tabularFigures,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: AppFont.lead,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: AppFont.title,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: AppFont.body,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: AppFont.body,
      color: AppColors.ink,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: AppFont.bodySm,
      color: AppColors.ink,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: AppFont.caption,
      color: AppColors.inkSecondary,
      letterSpacing: 0.2,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: const BorderSide(color: AppColors.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        borderSide: const BorderSide(color: AppColors.goldAccent),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.goldContainer,
      contentTextStyle: TextStyle(color: AppColors.onGoldContainer),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.hairline),
    splashFactory: InkSparkle.splashFactory,
  );
}
