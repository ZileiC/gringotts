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

  // Motion (§4): one-shot sheen highlight swept across the confirm CTA.
  // White-alpha highlight, deliberately NOT a gold gradient.
  /// Sheen band core (22% white) - DESIGN_T09 section 4.
  static const Color sheen = Color(0x38FFFFFF);

  /// Sheen band edge (fully transparent, same hue family for a clean fade).
  static const Color sheenEdge = Color(0x00FFFFFF);

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
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double pill = 999;
}

/// Typography scale (Perfect Fourth, base 16; DESIGN_T09.md section 2).
abstract final class AppFont {
  /// Keypad amount display (speed-entry home).
  static const double display = 56;

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

  /// Keypad key caps.
  static const double keypad = 22;

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
