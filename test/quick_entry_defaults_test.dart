import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/services/smart_prefill.dart';

void main() {
  group('QuickEntryDefaults.resolve (T-11 smart default)', () {
    test('explicit tap wins over everything', () {
      expect(
        QuickEntryDefaults.resolve(
          explicitId: categoryIdGift,
          nameSuggestionId: categoryIdDining,
          timeDefaultId: categoryIdTransport,
          topFrequencyId: categoryIdShopping,
        ),
        categoryIdGift,
      );
    });

    test('typed-name suggestion outranks the clock rule', () {
      expect(
        QuickEntryDefaults.resolve(
          nameSuggestionId: categoryIdTransport,
          timeDefaultId: categoryIdDining,
          topFrequencyId: categoryIdShopping,
        ),
        categoryIdTransport,
        reason: 'a typed merchant is more specific than time-of-day',
      );
    });

    test('time-of-day default beats recent frequency', () {
      expect(
        QuickEntryDefaults.resolve(
          timeDefaultId: categoryIdDining,
          topFrequencyId: categoryIdShopping,
        ),
        categoryIdDining,
      );
    });

    test('frequency is the fallback when the clock has no rule', () {
      expect(
        QuickEntryDefaults.resolve(topFrequencyId: categoryIdShopping),
        categoryIdShopping,
      );
    });

    test('nothing available -> nothing pre-selected', () {
      expect(QuickEntryDefaults.resolve(), isNull);
    });
  });

  group('TimeOfDayDefaults (clock rules used by the smart default)', () {
    test('lunch window maps to dining', () {
      expect(TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 12, 12, 0)),
          categoryIdDining);
    });

    test('late night maps to entertainment', () {
      expect(TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 12, 23, 0)),
          categoryIdEntertainment);
    });

    test('mid-afternoon has no rule', () {
      expect(TimeOfDayDefaults.defaultCategoryId(DateTime(2026, 9, 12, 15, 0)),
          isNull);
    });
  });
}
