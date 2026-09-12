import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-03 full flow', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GringottsApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final repo = container.read(transactionRepositoryProvider);

    // DB-driven baseline BEFORE creating anything.
    final draftsBefore = await repo.watchDrafts().first;
    // ignore: avoid_print
    print('DB_DRAFTS_BEFORE=${draftsBefore.length}');

    // T-10b IA: the launch page is the analysis home; the keypad is secondary.
    await tester.tap(find.byKey(const Key('home_record_cta')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(QuickEntryPage), findsOneWidget);

    // The speed-entry page scrolls on short surfaces: bring keys into view.
    await tester.ensureVisible(find.byKey(const Key('key_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('key_1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('key_5')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('¥ 15'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_cta')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('已记'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Confirm clears the amount (T-11: no C key, clear is a text action).
    expect(find.text('¥ 0'), findsOneWidget);

    // After creation: drafts = before + 1.
    final draftsAfterCreate = await repo
        .watchDrafts()
        .firstWhere((l) => l.length == draftsBefore.length + 1)
        .timeout(const Duration(seconds: 10));
    // ignore: avoid_print
    print('DB_DRAFTS_AFTER_CREATE=${draftsAfterCreate.length}');

    await tester.tap(find.byKey(const Key('quick_review')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('批量补类别'));
    await tester.pumpAndSettle();
    // The picker menu renders in the root overlay (above the speed-entry grid's
    // 餐饮 cell), so the last match is the menu item being chosen.
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('确认 '));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('已确认'), findsOneWidget);

    // After confirm: drafts return to baseline count (created one got confirmed).
    final draftsAfterConfirm = await repo
        .watchDrafts()
        .firstWhere((l) => l.length == draftsBefore.length)
        .timeout(const Duration(seconds: 10));
    // ignore: avoid_print
    print('DB_DRAFTS_AFTER_CONFIRM=${draftsAfterConfirm.length}');
    expect(draftsAfterConfirm.length, draftsBefore.length,
        reason: 'created draft left the draft list after confirmation');
  });
}
