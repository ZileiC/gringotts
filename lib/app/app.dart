import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/repositories/repositories.dart';

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
      home: const SkeletonPage(),
    );
  }
}

/// Temporary skeleton page proving that the database is wired up.
///
/// Replaced by the speed-entry page in T-02.
class SkeletonPage extends ConsumerWidget {
  const SkeletonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    return Scaffold(
      body: StreamBuilder<List<Category>>(
        stream: categoryRepo.watchAll(),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? const <Category>[];
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Gringotts',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '数据层已就绪 · 已加载 ${categories.length} 个内置分类',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: categories
                        .map((c) => Chip(label: Text(c.name)))
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
