import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/services/cpd_calculator.dart';

Asset _asset({
  required int valueCents,
  required DateTime purchasedAt,
  AssetStatus status = AssetStatus.inService,
  int? soldPriceCents,
  DateTime? soldAt,
}) =>
    Asset(
      id: 'test-id',
      name: 'test',
      category: AssetCategory.digital,
      valueCents: valueCents,
      purchasedAt: purchasedAt,
      photoPath: null,
      status: status,
      soldPriceCents: soldPriceCents,
      soldAt: soldAt,
      createdAt: purchasedAt,
      updatedAt: purchasedAt,
      deletedAt: null,
    );

void main() {
  group('CPD calculation (ticket acceptance: cross-day / same-day / sold)',
      () {
    test('same-day purchase counts as 1 day, CPD = full value', () {
      final now = DateTime(2026, 9, 9, 12);
      final asset = _asset(
        valueCents: 600000,
        purchasedAt: DateTime(2026, 9, 9, 8),
      );
      final days = CpdCalculator.heldDays(
        purchasedAt: asset.purchasedAt,
        asOf: now,
      );
      expect(days, 1);
      expect(CpdCalculator.cpdForAsset(asset, asOf: now), 600000);
    });

    test('cross-day holding spreads value over days (9999 days -> ¥0.88)', () {
      final asOf = DateTime(2026, 9, 9);
      final purchased = DateTime(2024, 1, 1);
      final asset = _asset(valueCents: 879900, purchasedAt: purchased);
      final days = CpdCalculator.heldDays(
        purchasedAt: purchased,
        asOf: asOf,
      );
      // 2024-01-01 .. 2026-09-09 inclusive: 983 days.
      expect(days, 983);
      final cpd = CpdCalculator.cpdForAsset(asset, asOf: asOf);
      expect(cpd, (879900 / days).round());
      expect(cpd, lessThan(879900));
    });

    test('sold asset uses sold price and sold date (realized CPD)', () {
      final purchased = DateTime(2026, 1, 1);
      final soldAt = DateTime(2026, 3, 1); // 60 days inclusive.
      final asset = _asset(
        valueCents: 600000,
        purchasedAt: purchased,
        status: AssetStatus.sold,
        soldPriceCents: 480000,
        soldAt: soldAt,
      );
      final days = CpdCalculator.heldDays(
        purchasedAt: purchased,
        asOf: DateTime.now(),
        soldAt: soldAt,
      );
      expect(days, 60);
      final cpd = CpdCalculator.cpdForAsset(asset);
      expect(cpd, (480000 / 60).round()); // 8000 cents = ¥80/day.
      // Realized profit: sold 4800 - bought 6000 = -1200 yuan.
      expect(CpdCalculator.realizedProfitCents(asset), -120000);
      // Retention: 4800/6000 = 80%.
      expect(CpdCalculator.retentionPermille(asset), 800);
    });

    test('day boundary: purchase yesterday + sold today = 2 days', () {
      final days = CpdCalculator.heldDays(
        purchasedAt: DateTime(2026, 9, 8),
        asOf: DateTime(2026, 9, 9),
        soldAt: DateTime(2026, 9, 9),
      );
      expect(days, 2);
    });

    test('future purchase clamps to 1 day (no negative CPD)', () {
      final days = CpdCalculator.heldDays(
        purchasedAt: DateTime(2027, 1, 1),
        asOf: DateTime(2026, 9, 9),
      );
      expect(days, 1);
    });
  });

  group('AssetPortfolio.breakdown (net value dashboard)', () {
    test('in-service + sold realized + retired excluded-from-service', () {
      final now = DateTime(2026, 9, 9);
      final assets = [
        _asset(valueCents: 100000, purchasedAt: now), // in service
        _asset(
          valueCents: 200000,
          purchasedAt: now,
          status: AssetStatus.sold,
          soldPriceCents: 150000,
          soldAt: now,
        ),
        _asset(
          valueCents: 50000,
          purchasedAt: now,
          status: AssetStatus.retired,
        ),
      ];
      final b = AssetPortfolio.breakdown(assets);
      expect(b.inServiceCents, 100000);
      expect(b.soldRealizedCents, 150000);
      expect(b.retiredCents, 50000);
      expect(b.netCents, 300000);
    });

    test('empty portfolio is all zeros', () {
      final b = AssetPortfolio.breakdown(const []);
      expect(b.netCents, 0);
    });
  });
}
