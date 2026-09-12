import 'package:flutter/material.dart';

/// Maps the persisted `categories.icon` string to a Material icon (T-11).
///
/// The nine seed categories store names like `restaurant` / `commute`; the
/// quick-entry 3x3 grid renders them with the same 19 px line-icon language as
/// the rest of the app.
abstract final class CategoryIcons {
  static const Map<String, IconData> _byName = <String, IconData>{
    'restaurant': Icons.restaurant,
    'commute': Icons.commute,
    'shopping_bag': Icons.shopping_bag,
    'home': Icons.home,
    'sports_esports': Icons.sports_esports,
    'school': Icons.school,
    'medical_services': Icons.medical_services,
    'redeem': Icons.redeem,
    'category': Icons.category,
  };

  /// Icon for a stored icon name; a neutral fallback keeps unknown custom
  /// categories renderable.
  static IconData forName(String? name) =>
      _byName[name] ?? Icons.category_outlined;
}
