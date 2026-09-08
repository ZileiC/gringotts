import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../pages/quick_entry_page.dart';

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

/// Root widget of the app. Theme setup only; M1.0 skeleton page.
class GringottsApp extends ConsumerWidget {
  const GringottsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Material 3, dark theme is the only theme (no switching entry).
    return MaterialApp(
      title: 'Gringotts',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
      ),
      home: const QuickEntryPage(),
    );
  }
}
