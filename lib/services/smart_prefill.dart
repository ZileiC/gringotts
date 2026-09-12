import '../domain/seed_ids.dart';

/// Time-of-day default category rules (ticket T-02).
///
/// 07:00-08:59 breakfast / 11:30-13:29 lunch / 17:00-18:59 dinner /
/// 22:30+ late night. Other hours yield no prefill.
class TimeOfDayDefaults {
  TimeOfDayDefaults._();

  /// Returns the fixed seed category id for [now], or null when the hour
  /// has no default prefill.
  static String? defaultCategoryId(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    final breakfast = 7 * 60; // 07:00
    final breakfastEnd = 9 * 60; // 09:00 exclusive
    final lunch = 11 * 60 + 30; // 11:30
    final lunchEnd = 13 * 60 + 30; // 13:30 exclusive
    final dinner = 17 * 60; // 17:00
    final dinnerEnd = 19 * 60; // 19:00 exclusive
    final lateNight = 22 * 60 + 30; // 22:30

    if (minute >= breakfast && minute < breakfastEnd) {
      return categoryIdDining;
    }
    if (minute >= lunch && minute < lunchEnd) {
      return categoryIdDining;
    }
    if (minute >= dinner && minute < dinnerEnd) {
      return categoryIdDining;
    }
    if (minute >= lateNight || minute < 4 * 60) {
      return categoryIdEntertainment;
    }
    return null;
  }
}

/// Effective category selection rules for the speed-entry page (T-11).
///
/// The high-frequency chip bar became a smart default: the grid never
/// re-orders by frequency (spatial consistency), it only pre-selects a cell.
class QuickEntryDefaults {
  QuickEntryDefaults._();

  /// Category selection precedence:
  ///   1. explicit tap (the user overrules everything),
  ///   2. name-parser suggestion (a typed name is more specific than a clock),
  ///   3. time-of-day default,
  ///   4. most frequent category of the last 14 days,
  ///   5. none (nothing pre-selected).
  ///
  /// Rules 3 -> 4 are the "smart default"; the grid order stays fixed.
  static String? resolve({
    String? explicitId,
    String? nameSuggestionId,
    String? timeDefaultId,
    String? topFrequencyId,
  }) =>
      explicitId ?? nameSuggestionId ?? timeDefaultId ?? topFrequencyId;
}

/// Frequency ranking of categories over the last N days (chip bar).
class HighFrequencyCategories {
  HighFrequencyCategories._();

  /// Ranked category ids for the chip bar, best first.
  ///
  /// [records] are the live transactions from the recent window; ties break
  /// by recency (newest first). Category-less drafts are skipped.
  static List<String> ranked(
    Iterable<({String? categoryId, DateTime occurredAt})> records, {
    DateTime? now,
    int windowDays = 14,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: windowDays));
    final counts = <String, int>{};
    final latest = <String, DateTime>{};
    for (final r in records) {
      final id = r.categoryId;
      if (id == null || r.occurredAt.isBefore(cutoff)) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      final known = latest[id];
      if (known == null || r.occurredAt.isAfter(known)) {
        latest[id] = r.occurredAt;
      }
    }
    final ids = counts.keys.toList();
    ids.sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return latest[b]!.compareTo(latest[a]!);
    });
    return ids;
  }
}

/// Inline "is this lunch?" pattern recognition (weekday lunch around a
/// recurring amount). Inline hint only - never a dialog.
class LunchPattern {
  LunchPattern._();

  /// Matches when [now] is a weekday inside 11:30-13:30 and [amountCents]
  /// is within [toleranceCents] of [anchorCents].
  static bool matches({
    required DateTime now,
    required int amountCents,
    int anchorCents = 1500,
    int toleranceCents = 200,
  }) {
    if (now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday) {
      return false;
    }
    final minute = now.hour * 60 + now.minute;
    final insideLunch =
        minute >= 11 * 60 + 30 && minute < 13 * 60 + 30;
    if (!insideLunch) return false;
    final diff = (amountCents - anchorCents).abs();
    return diff <= toleranceCents;
  }
}
