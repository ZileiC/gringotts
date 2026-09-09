import 'package:flutter/material.dart';

/// Design tokens for the Gringotts black-gold identity.
///
/// Single source of truth for colors, typography sizes, spacing and radii.
/// Widgets must never hard-code these values; T-08 reskins the whole app by
/// editing this file only.


/// Brand color palette (dark-only theme).
abstract final class AppColors {
  /// Champagne gold brand accent used as the theme seed.
  static const Color seedGold = Color(0xFFD4AF37);

  /// Deep black app background layer.
  static const Color surfaceBlack = Color(0xFF0F0F12);

  /// Elevated dark surface layer (cards, sheets).
  static const Color surfaceDark = Color(0xFF1A1A1F);

  /// Slightly lighter dark surface for interactive elements.
  static const Color surfaceElevated = Color(0xFF24242A);

  /// Primary text on dark surfaces.
  static const Color textPrimary = Color(0xFFF4F4F5);

  /// Secondary/muted text on dark surfaces.
  static const Color textSecondary = Color(0xFF9E9EA6);

  /// Gold-tinted container used for brand moments (badges, selected chips).
  static const Color goldContainer = Color(0xFF3A301B);
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

/// Typography scale (sizes only; weights/styles come from TextTheme).
abstract final class AppFont {
  static const double display = 56;
  static const double title = 18;
  static const double body = 14;
  static const double caption = 12;
  static const double keypad = 22;
}

/// Builds the app-wide dark Material 3 theme from tokens.
///
/// The only theme in the app; no theme switching entry exists.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seedGold,
    brightness: Brightness.dark,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surfaceBlack,
    textTheme: base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontSize: AppFont.display,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: AppColors.textPrimary,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: AppFont.title,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: AppFont.body,
        color: AppColors.textPrimary,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: AppFont.caption,
        color: AppColors.textSecondary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
    ),
  );
}
