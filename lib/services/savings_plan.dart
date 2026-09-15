/// T-21 / DESIGN_MAIN 11.5: planned savings -> asset.
///
/// The plan itself lives on the monthly budget row (`savings_target_cents`).
/// Nothing is written until the user decides: confirming stamps
/// `savingsConfirmedAt` and creates exactly one savings-category asset;
/// skipping only stamps `savingsSkippedAt` and writes zero assets. The derived
/// figures (day allowance, amortised income) stay computed - this feature adds
/// confirmation timestamps only.
library;

import '../data/app_database.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import 'budget_engine.dart';

/// Pure rules of the planned-savings flow (unit-testable without a database).
class SavingsPlan {
  SavingsPlan._();

  /// Note written on the generated asset (frozen spec text).
  static const String assetNote = '由月度计划存款确认生成';

  /// The card shows only when the month still plans savings > 0 and the user
  /// has neither confirmed nor skipped it.
  static bool shouldPrompt(BudgetMonth? budget) =>
      budget != null &&
      budget.deletedAt == null &&
      budget.savingsTargetCents > 0 &&
      budget.savingsConfirmedAt == null &&
      budget.savingsSkippedAt == null;

  /// Purchase date of the generated asset: the month's last day, 12:00.
  static DateTime lastDayNoon(DateTime month) {
    final days = BudgetEngine.daysInMonth(month.year, month.month);
    return DateTime(month.year, month.month, days, 12);
  }

  /// Name of the generated asset, e.g. "9 月计划存款".
  static String assetName(DateTime month) => '${month.month} 月计划存款';

  /// True on the last three days of [month] (the gentle month-end hint).
  static bool isMonthEnd(DateTime today, DateTime month) {
    if (today.year != month.year || today.month != month.month) return false;
    final days = BudgetEngine.daysInMonth(month.year, month.month);
    return days - today.day < 3;
  }

  /// Parses the `YYYY-MM` budget key back to the month's first day.
  static DateTime monthOfKey(String yearMonth) {
    final parts = yearMonth.split('-');
    final y = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (y == null || m == null) return DateTime.now();
    return DateTime(y, m, 1);
  }
}

/// Repository orchestration of the two confirmation actions.
class SavingsPlanService {
  SavingsPlanService({required this.budgetRepo, required this.assetRepo});

  final BudgetRepository budgetRepo;
  final AssetRepository assetRepo;

  /// Confirms the month's plan and returns the savings asset.
  ///
  /// Idempotent: when the month already produced an asset, that row is returned
  /// and no second asset is ever created.
  Future<Asset> confirm(BudgetMonth budget) async {
    final month = SavingsPlan.monthOfKey(budget.yearMonth);
    final lastDayNoon = SavingsPlan.lastDayNoon(month);
    final existing = await assetRepo.findPlannedSavingsAsset(lastDayNoon);
    if (existing != null) {
      if (budget.savingsConfirmedAt == null) {
        await budgetRepo.markSavingsConfirmed(budget.id);
      }
      return existing;
    }
    final asset = await assetRepo.create(
      name: SavingsPlan.assetName(month),
      category: AssetCategory.savings,
      valueCents: budget.savingsTargetCents,
      purchasedAt: lastDayNoon,
      note: SavingsPlan.assetNote,
    );
    await budgetRepo.markSavingsConfirmed(budget.id);
    return asset;
  }

  /// Answers 这个月没攒够: only the timestamp is written, zero assets land.
  Future<void> skip(BudgetMonth budget) =>
      budgetRepo.markSavingsSkipped(budget.id);
}