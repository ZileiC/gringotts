import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/repositories/asset_photo_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/repositories.dart';
import '../pages/home_shell.dart';
import '../ui/splash.dart';
import '../ui/tokens.dart';

/// Selected calendar month (first day), shared by the analysis page, the
/// ledger page and the statistics page (DESIGN_MAIN 11.4: one source).
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Switches every page that watches the shared month.
  void select(DateTime month) => state = DateTime(month.year, month.month, 1);
}

final NotifierProvider<SelectedMonth, DateTime> selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

/// Provides the singleton [AppDatabase] for the whole app.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  final db = openConnection();
  ref.onDispose(db.close);
  return db;
});

/// Transaction repository.
final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

/// Category repository.
final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

/// Asset repository.
final Provider<AssetRepository> assetRepositoryProvider =
    Provider<AssetRepository>((ref) {
  return AssetRepository(ref.watch(databaseProvider));
});

/// Asset photo repository (T-09B multi-photo support).
final Provider<AssetPhotoRepository> assetPhotoRepositoryProvider =
    Provider<AssetPhotoRepository>((ref) {
  return AssetPhotoRepository(ref.watch(databaseProvider));
});

/// Monthly budget repository (T-10).
final Provider<BudgetRepository> budgetRepositoryProvider =
    Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

/// Root widget of the app. Theme setup only; M1.0 skeleton page.
class GringottsApp extends ConsumerWidget {
  const GringottsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Material 3, dark theme is the only theme (no switching entry).
    return MaterialApp(
      title: 'Gringotts',
      theme: buildAppTheme(),
      // T-09E: the brand splash wraps the navigator (canvas + logo 38% +
      // Playfair wordmark). It is a presentation overlay only - the keyboard
      // home is mounted underneath from the first frame.
      builder: (context, child) =>
          SplashGate(child: child ?? const SizedBox.shrink()),
      // T-12c IA: the launch route is the tab shell (analysis / assets /
      // stats peers); the speed-entry keypad is pushed from the 记一笔 action.
      home: const HomeShell(),
    );
  }
}
