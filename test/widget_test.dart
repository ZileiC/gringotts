import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/data/app_database.dart';
import 'package:gringotts/data/repositories/repositories.dart';

/// Fake category repository so the widget test never touches a real database
/// (drift stream stores leave pending timers in the fake-async test zone).
class _FakeCategoryRepository implements CategoryRepository {
  @override
  Stream<List<Category>> watchAll() => Stream.value(const <Category>[]);

  @override
  Future<Category> createCustom({
    required String name,
    String? icon,
    required int sort,
  }) =>
      throw UnimplementedError();

  @override
  List<String> get seedIds => const <String>[];
}

void main() {
  testWidgets('app skeleton renders with title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepository()),
        ],
        child: const GringottsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gringotts'), findsOneWidget);
    // The readiness line is rendered with the loaded category count.
    expect(find.textContaining('数据层已就绪'), findsOneWidget);
  });
}
