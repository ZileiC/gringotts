import 'dart:math';

import '../data/app_database.dart';
import '../domain/models.dart';

/// Cost-per-day (CPD) calculator for assets (ticket T-04 / feature B8).
///
/// Pure functions over integer-cents values only.
class CpdCalculator {
  CpdCalculator._();

  /// Full days the asset has been (or was) held as of [asOf].
  /// Same-day purchase counts as day 1 (a day with the asset present).
  static int heldDays({
    required DateTime purchasedAt,
    required DateTime asOf,
    DateTime? soldAt,
  }) {
    final end = soldAt ?? asOf;
    final start = DateTime(purchasedAt.year, purchasedAt.month, purchasedAt.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final days = endDate.difference(start).inDays + 1;
    return max(days, 1);
  }

  /// CPD in integer cents: current value spread over holding days.
  ///
  /// `sold` assets use the SOLD price (what the item actually cost per day).
  static int cpdCents({
    required int valueCents,
    required int heldDays,
  }) {
    assert(heldDays >= 1);
    return (valueCents / heldDays).round();
  }

  /// Full CPD breakdown for one asset.
  static int cpdForAsset(Asset asset, {DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final days = heldDays(
      purchasedAt: asset.purchasedAt,
      asOf: now,
      soldAt: asset.soldAt,
    );
    final effectiveCents =
        asset.status == AssetStatus.sold && asset.soldPriceCents != null
            ? asset.soldPriceCents!
            : asset.valueCents;
    return cpdCents(valueCents: effectiveCents, heldDays: days);
  }

  /// Realized P/L in cents for a sold asset (sold - purchased).
  static int realizedProfitCents(Asset asset) {
    assert(asset.status == AssetStatus.sold);
    return (asset.soldPriceCents ?? 0) - asset.valueCents;
  }

  /// Value retention rate in thousandths (permille, integer).
  /// 8799/9999 buy-sell example: sold 8000 => 909 permille (90.9%).
  static int retentionPermille(Asset asset) {
    assert(asset.status == AssetStatus.sold);
    if (asset.valueCents == 0) return 0;
    return ((asset.soldPriceCents ?? 0) * 1000 ~/ asset.valueCents);
  }
}

/// Portfolio-level aggregation (net value dashboard).
class AssetPortfolio {
  AssetPortfolio._();

  /// Net value: in-service assets at current value; sold assets at sale price
  /// (realized); retired assets excluded (they are still owned but idle -
  /// keep current value? Ticket says in-service sum + sold realized; retired
  /// keeps current value to avoid losing sight of stored wealth).
  static ({int inServiceCents, int soldRealizedCents, int retiredCents, int netCents})
      breakdown(List<Asset> assets) {
    var inService = 0;
    var soldRealized = 0;
    var retired = 0;
    for (final a in assets) {
      switch (a.status) {
        case AssetStatus.inService:
          inService += a.valueCents;
        case AssetStatus.sold:
          soldRealized += a.soldPriceCents ?? 0;
        case AssetStatus.retired:
          retired += a.valueCents;
      }
    }
    return (
      inServiceCents: inService,
      soldRealizedCents: soldRealized,
      retiredCents: retired,
      netCents: inService + soldRealized + retired,
    );
  }
}
