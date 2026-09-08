import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/domain/seed_ids.dart';

void main() {
  group('money amount conversion (integer cents only)', () {
    test('yuan to cents', () {
      expect(2850, 28.50 * 100 ~/ 1); // explicit: cents are integers
      expect(1550, 15.50 * 100 ~/ 1);
    });

    test('seed category ids are valid UUID format', () {
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      final ids = [
        categoryIdDining,
        categoryIdTransport,
        categoryIdShopping,
        categoryIdHousing,
        categoryIdEntertainment,
        categoryIdStudy,
        categoryIdMedical,
        categoryIdGift,
        categoryIdOther,
      ];
      expect(ids.length, 9);
      expect(ids.toSet().length, 9, reason: 'seed ids must be unique');
      for (final id in ids) {
        expect(uuidPattern.hasMatch(id), isTrue, reason: 'id: $id');
      }
    });

    test('enum values serialize to stable text names', () {
      expect(TransactionType.values.map((e) => e.name),
          containsAllInOrder(['income', 'expense', 'transfer']));
      expect(AssetStatus.values.map((e) => e.name),
          containsAllInOrder(['inService', 'retired', 'sold']));
      expect(AssetCategory.values.map((e) => e.name),
          containsAllInOrder(['hardCurrency', 'digital', 'nonStandard', 'ordinary']));
      expect(TransactionSource.values.map((e) => e.name),
          containsAllInOrder(['manual', 'screenshot', 'voice']));
    });
  });
}
