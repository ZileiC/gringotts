import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:gringotts/domain/models.dart';
import 'package:gringotts/pages/quick_entry_page.dart';
import 'package:gringotts/services/budget_engine.dart';
import 'package:integration_test/integration_test.dart';

/// T-13b full-chain evidence: the whole M2.0 pre-wave user path on the real
/// Windows engine, through the T-12c navigation (three peer tabs + 记一笔
/// pushing the speed-entry page + 明细 reached from the statistics page):
///
///   shell -> 记一笔 -> 立即入账(快记即正式) -> 统计 -> 资产 -> 详情 -> 编辑
///         -> 明细 -> 行内编辑 -> 导出(CSV/BOM + JSON)
///
/// Preconditions declared up front (AGENTS.md evidence clause):
/// - the development database was retired first (`tool/clean_dev_db.py --apply`,
///   evidence/t13b/dev_db_cleanup.json): no live transaction, no live asset, no
///   live budget row - asserted here before anything is written;
/// - the seeded asset uses a fixed purchase date (2026-01-01) and every row this
///   script creates is tombstoned again at teardown;
/// - the exported files are the app's own output written to the Documents
///   directory; only the files created by this run are deleted again.
Future<void> snap(WidgetTester tester, String name, List<Finder> required) async {
  for (final f in required) {
    expect(f, findsWidgets, reason: 'missing before snap $name');
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47],
      reason: 'frame $name must be PNG');
  final file = File('evidence/t13b/.t13b_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T13B_SNAP name=$name bytes=${bytes.length} '
      'md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

Future<void> tap(WidgetTester tester, Finder f, {int settle = 1}) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle(Duration(seconds: settle));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-13b full chain: 快记 -> 入账 -> 统计 -> 资产 -> 详情 -> 编辑 '
      '-> 明细 -> 导出', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final txRepo = container.read(transactionRepositoryProvider);
    final assetRepo = container.read(assetRepositoryProvider);
    final budgetRepo = container.read(budgetRepositoryProvider);

    // ---------- declared preconditions ----------
    final liveTx = await txRepo.watchAll().first;
    final liveAssets = await assetRepo.getLiveAssets();
    final liveBudget =
        await budgetRepo.getByMonth(BudgetEngine.monthKey(DateTime.now()));
    expect(liveTx, isEmpty,
        reason: 'PRECONDITION: dev database retired (tool/clean_dev_db.py --apply)');
    expect(liveAssets, isEmpty, reason: 'PRECONDITION: no live asset');
    expect(liveBudget, isNull, reason: 'PRECONDITION: no live budget row');
    // ignore: avoid_print
    print('T13B_PRECONDITION live_tx=0 live_assets=0 budget=null');

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('app_repaint_boundary'),
        child: UncontrolledProviderScope(
          container: container,
          child: const GringottsApp(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ---------- 1. shell: three peer tabs + 记一笔 ----------
    final cta = find.byKey(const Key('home_record_key'));
    expect(cta, findsOneWidget);
    expect(find.byKey(const Key('tab_home')), findsOneWidget);
    expect(find.byKey(const Key('tab_assets')), findsOneWidget);
    expect(find.byKey(const Key('tab_stats')), findsOneWidget);
    // ignore: avoid_print
    print('T13B_STEP shell tabs=3 cta=onstage');
    await snap(tester, '01_shell_home', [cta, find.byKey(const Key('tab_stats'))]);

    // ---------- 2. 记一笔 pushes the speed-entry page ----------
    await tap(tester, cta, settle: 1);
    expect(find.byType(QuickEntryPage), findsOneWidget);
    expect(cta, findsNothing, reason: 'the pushed page covers the shell');
    await tester.enterText(find.byKey(const Key('entry_name')), '瑞幸');
    await tester.pumpAndSettle();
    for (final key in <String>['1', '5']) {
      await tap(tester, find.byKey(Key('key_$key')), settle: 1);
    }
    await snap(tester, '02_quick_entry', [
      find.byKey(const Key('entry_name')),
      find.byKey(const Key('confirm_cta')),
    ]);

    // ---------- 3. 快记即正式: the row is live immediately ----------
    await tap(tester, find.byKey(const Key('confirm_cta')), settle: 2);
    final afterEntry = await txRepo.watchAll().first;
    expect(afterEntry, hasLength(1));
    final row = afterEntry.single;
    expect(row.merchant, '瑞幸');
    expect(row.amountCents, 1500);
    expect(row.isDraft, isFalse, reason: '快记即正式 (no confirmation step)');
    expect(row.type, TransactionType.expense);
    // ignore: avoid_print
    print('T13B_STEP entry id=${row.id} amount=${row.amountCents} '
        'draft=${row.isDraft}');

    await tap(tester, find.byKey(const Key('quick_back')), settle: 2);
    expect(find.byType(QuickEntryPage), findsNothing);
    expect(cta, findsOneWidget, reason: 'back lands on the analysis tab');
    expect(find.text('¥15 · 1 笔'), findsOneWidget,
        reason: 'the analysis page shows the new record at once');
    await snap(tester, '03_home_after_entry', [find.text('¥15 · 1 笔')]);

    // ---------- 4. 统计 ----------
    await tap(tester, find.byKey(const Key('tab_stats')), settle: 2);
    expect(find.text('统计'), findsWidgets);
    // The net card prints income - expense in one line: 收入 ¥0 · 支出 ¥15.
    expect(find.textContaining('支出 ¥15'), findsOneWidget,
        reason: 'statistics consumes the same row');
    expect(find.textContaining('-15'), findsWidgets,
        reason: 'net balance = income - expense = -15');
    // ignore: avoid_print
    print('T13B_STEP stats today_expense=15.00');
    await snap(tester, '04_stats', [find.byKey(const Key('stats_ledger_entry'))]);

    // ---------- 5. 明细 (entry point: the statistics page) ----------
    await tap(tester, find.byKey(const Key('stats_ledger_entry')), settle: 2);
    final ledgerRow = find.byKey(Key('ledger_row_${row.id}'));
    expect(ledgerRow, findsOneWidget);
    expect(find.text('瑞幸'), findsWidgets);
    // ignore: avoid_print
    print('T13B_STEP ledger rows=1 month=${BudgetEngine.monthKey(DateTime.now())}');
    await snap(tester, '05_ledger', [ledgerRow, find.byKey(const Key('ledger_back'))]);

    // ---------- 6. 行内编辑 (full-field edit sheet) ----------
    await tap(tester, ledgerRow, settle: 2);
    expect(find.text('编辑记录'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ledger_edit_merchant')), '瑞幸咖啡');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger_edit_amount')), '20');
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('ledger_edit_save')), settle: 2);
    final edited = (await txRepo.watchAll().first).single;
    expect(edited.id, row.id);
    expect(edited.merchant, '瑞幸咖啡');
    expect(edited.amountCents, 2000);
    expect(edited.isDraft, isFalse, reason: 'an edit keeps the row formal');
    // ignore: avoid_print
    print('T13B_STEP ledger_edit merchant=${edited.merchant} '
        'amount=${edited.amountCents}');
    await snap(tester, '06_ledger_edited', [find.text('瑞幸咖啡')]);

    // ---------- 7. 资产 ----------
    // 明细 is the statistics tab's child, so the shell (and its tab bar) is
    // offstage under it: pop back before switching tabs.
    await tap(tester, find.byKey(const Key('ledger_back')), settle: 2);
    expect(find.byKey(const Key('ledger_back')), findsNothing);
    // 明细 is the statistics tab's child, so popping back lands on the
    // statistics tab: the shell is on screen again, but the analysis-page
    // record key sits offstage under the shell's IndexedStack.
    expect(find.byKey(const Key('tab_home')), findsOneWidget,
        reason: 'back on the shell after 明细');
    expect(cta, findsNothing,
        reason: 'the record key belongs to the analysis tab (offstage here)');
    await tap(tester, find.byKey(const Key('tab_home')), settle: 2);
    expect(cta, findsOneWidget, reason: 'switching back to 分析 shows the CTA');
    await tap(tester, find.byKey(const Key('tab_assets')), settle: 2);
    expect(find.text('总资产净值'), findsOneWidget);
    await tap(tester, find.byIcon(Icons.add), settle: 1);
    expect(find.text('添加资产'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, '名称').first, 'T13B 相机');
    await tester.enterText(
        find.widgetWithText(TextField, '价值（元）').first, '6000');
    await tester.pumpAndSettle();
    await tap(tester, find.text('保存'), settle: 2);
    final withAsset = await assetRepo.getLiveAssets();
    expect(withAsset, hasLength(1));
    final asset = withAsset.single;
    expect(asset.valueCents, 600000);
    // ignore: avoid_print
    print('T13B_STEP asset id=${asset.id} value=${asset.valueCents}');
    await snap(tester, '07_assets_with_cpd',
        [find.text('T13B 相机'), find.textContaining('/天')]);

    // ---------- 8. 详情 ----------
    await tap(tester, find.text('T13B 相机'), settle: 2);
    expect(find.byKey(const Key('detail_edit_button')), findsOneWidget);
    expect(find.textContaining('持有'), findsWidgets);
    // ignore: avoid_print
    print('T13B_STEP asset_detail opened=true cpd_row=true');
    await snap(tester, '08_asset_detail',
        [find.byKey(const Key('detail_edit_button'))]);

    // ---------- 9. 编辑 (asset edit sheet) ----------
    await tap(tester, find.byKey(const Key('detail_edit_button')), settle: 1);
    await tester.enterText(
        find.widgetWithText(TextField, '名称').first, 'T13B 相机Pro');
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('edit_save')), settle: 2);
    final renamed = (await assetRepo.getLiveAssets()).single;
    expect(renamed.id, asset.id);
    expect(renamed.name, 'T13B 相机Pro');
    expect(renamed.valueCents, 600000, reason: 'the value survived the edit');
    // ignore: avoid_print
    print('T13B_STEP asset_edit name=${renamed.name}');
    await snap(tester, '09_asset_edited', [find.text('T13B 相机Pro')]);

    // ---------- 10. 导出 (CSV with BOM + JSON) ----------
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
    final exportDir = Directory('$home${Platform.pathSeparator}Documents');
    final before = exportDir.existsSync()
        ? exportDir.listSync().map((e) => e.path).toSet()
        : <String>{};
    // The asset detail is a pushed child of the assets tab: pop the route
    // directly - its SliverAppBar back button can be scrolled out of view.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // 详情 was pushed from the assets tab, so the shell is back but the
    // analysis CTA is offstage (same rule as the 明细 return above).
    expect(find.byKey(const Key('tab_home')), findsOneWidget,
        reason: 'back on the shell after 详情');
    expect(cta, findsNothing,
        reason: 'the assets tab is selected, so the analysis CTA is offstage');
    await tap(tester, find.byKey(const Key('tab_stats')), settle: 2);
    // Export: tap, then step only far enough for the snackbar (2 s) to be up.
    final exportButton = find.text('导出 CSV / JSON（带 BOM）');
    // The stats body is a lazy ListView: scroll the export action into range
    // (it sits below the trend and pie cards).
    await tester.scrollUntilVisible(exportButton, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(exportButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('已导出'), findsOneWidget,
        reason: 'the export reports the file count');
    final produced = exportDir
        .listSync()
        .map((e) => e.path)
        .where((p) => !before.contains(p))
        .toList()
      ..sort();
    expect(produced, hasLength(2), reason: 'one CSV + one JSON');

    final csvPath = produced.firstWhere((p) => p.endsWith('.csv'));
    final jsonPath = produced.firstWhere((p) => p.endsWith('.json'));
    final csvBytes = File(csvPath).readAsBytesSync();
    expect(csvBytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF],
        reason: 'the CSV carries the UTF-8 BOM');
    final csv = utf8.decode(csvBytes.sublist(3));
    expect(csv, contains('瑞幸咖啡'), reason: 'the edited merchant is exported');
    expect(csv, contains('2000'), reason: 'the edited amount is exported');
    final json = jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
    final exportedTx = (json['transactions'] as List).cast<Map<String, dynamic>>();
    expect(exportedTx.map((t) => t['merchant']), contains('瑞幸咖啡'));
    final exportedAssets = (json['assets'] as List).cast<Map<String, dynamic>>();
    expect(exportedAssets.map((a) => a['name']), contains('T13B 相机Pro'));
    // ignore: avoid_print
    print('T13B_STEP export files=2 bom=true csv_merchant=true '
        'json_asset=true schema=${json['version']}');
    // The snackbar is transient, so the frame asserts the stats header and the
    // export action instead.
    await snap(tester, '10_stats_exported', [exportButton, find.text('统计')]);

    // ---------- teardown: retire the seeds, drop the exported files ----------
    await txRepo.softDelete(edited.id);
    await assetRepo.softDelete(renamed.id);
    final txLeft = await txRepo.watchAll().first;
    final assetsLeft = await assetRepo.getLiveAssets();
    expect(txLeft, isEmpty, reason: 'seeded transaction tombstoned');
    expect(assetsLeft, isEmpty, reason: 'seeded asset tombstoned');
    for (final p in produced) {
      File(p).deleteSync();
    }
    expect(File(csvPath).existsSync(), isFalse);
    expect(File(jsonPath).existsSync(), isFalse);
    // ignore: avoid_print
    print('T13B_TEARDOWN live_tx=${txLeft.length} live_assets=${assetsLeft.length} '
        'exported_files_removed=${produced.length}');
  });
}
