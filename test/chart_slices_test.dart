import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/services/statistics_service.dart';

CategoryTotal _t(String? id, int cents) =>
    CategoryTotal(categoryId: id, cents: cents);

void main() {
  group('StatisticsService.chartSlices (shared pie/donut slicing)', () {
    test('empty totals produce no slices (caller renders empty state)', () {
      expect(StatisticsService.chartSlices(const []), isEmpty);
    });

    test('fewer than maxNamed keeps every category, in order', () {
      final slices = StatisticsService.chartSlices(
        [_t('a', 3000), _t('b', 2000), _t('c', 1000)],
      );
      expect(slices.map((s) => s.categoryId), ['a', 'b', 'c']);
      expect(slices.map((s) => s.cents), [3000, 2000, 1000]);
      expect(slices.map((s) => s.colorIndex), [0, 1, 2]);
      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('exactly maxNamed still keeps every category (no empty 其他)', () {
      final slices = StatisticsService.chartSlices(
        [_t('a', 3000), _t('b', 2000), _t('c', 1000)],
        maxNamed: 3,
      );
      expect(slices, hasLength(3));
      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('beyond maxNamed merges the tail into one 其他 slice', () {
      final slices = StatisticsService.chartSlices(
        [_t('a', 5000), _t('b', 3000), _t('c', 2000), _t('d', 700), _t('e', 300)],
        maxNamed: 3,
      );
      expect(slices, hasLength(4));
      expect(slices.take(3).map((s) => s.categoryId), ['a', 'b', 'c']);
      final other = slices.last;
      expect(other.isOther, isTrue);
      expect(other.categoryId, isNull);
      expect(other.cents, 1000, reason: '700 + 300 merged');
      expect(other.colorIndex, 3, reason: 'position after the named slices');
    });

    test('maxNamed = totals.length keeps all categories (stats pie path)', () {
      final totals = [_t('a', 5000), _t('b', 3000), _t('c', 2000), _t('d', 700)];
      final slices =
          StatisticsService.chartSlices(totals, maxNamed: totals.length);
      expect(slices, hasLength(4));
      expect(slices.any((s) => s.isOther), isFalse);
      // Colour index === position, identical to the historical stats mapping.
      expect(slices.map((s) => s.colorIndex), [0, 1, 2, 3]);
    });
  });
}
