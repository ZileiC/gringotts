import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/services/smart_prefill.dart';

void main() {
  group('TimeOfDayDefaults', () {
    test('breakfast 07:00-08:59 -> dining', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 7, 0)),
        categoryIdDining,
      );
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 8, 59)),
        categoryIdDining,
      );
    });

    test('09:00 -> no prefill (boundary exclusive)', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 9, 0)),
        isNull,
      );
    });

    test('lunch 11:30-13:29 -> dining', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 11, 30)),
        categoryIdDining,
      );
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 13, 29)),
        categoryIdDining,
      );
    });

    test('13:30 -> no prefill', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 13, 30)),
        isNull,
      );
    });

    test('dinner 17:00-18:59 -> dining', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 17, 0)),
        categoryIdDining,
      );
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 18, 59)),
        categoryIdDining,
      );
    });

    test('19:00 -> no prefill', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 19, 0)),
        isNull,
      );
    });

    test('late night 22:30+ -> entertainment', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 22, 30)),
        categoryIdEntertainment,
      );
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 23, 59)),
        categoryIdEntertainment,
      );
    });

    test('early hours 00:00-03:59 -> entertainment (late night tail)', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 0, 0)),
        categoryIdEntertainment,
      );
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 3, 59)),
        categoryIdEntertainment,
      );
    });

    test('04:00-06:59 -> no prefill', () {
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 4, 0)),
        isNull,
      );
      expect(
        TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 8, 6, 59)),
        isNull,
      );
    });
  });

  group('HighFrequencyCategories.ranked', () {
    test('ranks by count desc, then recency desc', () {
      final now = DateTime(2026, 9, 8, 12);
      final ranked = HighFrequencyCategories.ranked([
        (categoryId: categoryIdDining, occurredAt: now.subtract(const Duration(days: 1))),
        (categoryId: categoryIdDining, occurredAt: now.subtract(const Duration(days: 2))),
        (categoryId: categoryIdTransport, occurredAt: now.subtract(const Duration(days: 1))),
        (categoryId: categoryIdShopping, occurredAt: now.subtract(const Duration(days: 3))),
      ], now: now);
      expect(ranked.first, categoryIdDining);
      expect(ranked.length, 3);
    });

    test('skips null-category records', () {
      final now = DateTime(2026, 9, 8, 12);
      final ranked = HighFrequencyCategories.ranked([
        (categoryId: null, occurredAt: now),
        (categoryId: categoryIdDining, occurredAt: now),
      ], now: now);
      expect(ranked, [categoryIdDining]);
    });

    test('ignores records older than the 14-day window', () {
      final now = DateTime(2026, 9, 8, 12);
      final ranked = HighFrequencyCategories.ranked([
        (categoryId: categoryIdDining, occurredAt: now.subtract(const Duration(days: 20))),
        (categoryId: categoryIdTransport, occurredAt: now.subtract(const Duration(days: 1))),
      ], now: now);
      expect(ranked, [categoryIdTransport]);
    });

    test('tie breaks by recency', () {
      final now = DateTime(2026, 9, 8, 12);
      final ranked = HighFrequencyCategories.ranked([
        (categoryId: categoryIdShopping, occurredAt: now.subtract(const Duration(days: 5))),
        (categoryId: categoryIdTransport, occurredAt: now.subtract(const Duration(days: 1))),
      ], now: now);
      expect(ranked.first, categoryIdTransport);
    });
  });

  group('LunchPattern.matches', () {
    test('weekday lunch window + anchor amount matches', () {
      // 2026-09-08 is a Tuesday.
      final match = LunchPattern.matches(
        now: DateTime(2026, 9, 8, 12, 0),
        amountCents: 1500,
      );
      expect(match, isTrue);
    });

    test('within tolerance +-2 yuan matches', () {
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 12, 0), amountCents: 1300),
        isTrue,
      );
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 12, 0), amountCents: 1700),
        isTrue,
      );
    });

    test('outside tolerance does not match', () {
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 12, 0), amountCents: 1200),
        isFalse,
      );
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 12, 0), amountCents: 1800),
        isFalse,
      );
    });

    test('weekend does not match', () {
      // 2026-09-12 is a Saturday.
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 12, 12, 0), amountCents: 1500),
        isFalse,
      );
    });

    test('outside lunch window does not match', () {
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 10, 0), amountCents: 1500),
        isFalse,
      );
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 14, 0), amountCents: 1500),
        isFalse,
      );
    });

    test('boundary edges of window match', () {
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 11, 30), amountCents: 1500),
        isTrue,
      );
      expect(
        LunchPattern.matches(now: DateTime(2026, 9, 8, 13, 29), amountCents: 1500),
        isTrue,
      );
    });

    test('custom tolerance applies', () {
      expect(
        LunchPattern.matches(
          now: DateTime(2026, 9, 8, 12, 0),
          amountCents: 2000,
          anchorCents: 1500,
          toleranceCents: 500,
        ),
        isTrue,
      );
    });
  });
}
