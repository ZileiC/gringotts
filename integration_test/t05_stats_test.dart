import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:integration_test/integration_test.dart';

/// T-05 evidence pipeline: same assert-first + toImage + md5 protocol as T-04.
Future<void> snapState(
  WidgetTester tester,
  String name,
  List<Finder> requiredElements,
) async {
  await tester.pumpAndSettle(const Duration(seconds: 1));
  for (final f in requiredElements) {
    expect(f, findsWidgets, reason: 'element must be on tree before snap $name');
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  final file = File('.t05_$name.png');
  await file.writeAsBytes(bytes, flush: true);
  final digest = md5.convert(bytes).toString().substring(0, 12);
  // ignore: avoid_print
  print('SNAP_SAVED=$name file=${file.path} md5=$digest');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-05 stats flow: range switch -> pie -> trend -> export',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
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

    // 1. Navigate to stats: home -> speed entry -> 统计 (T-10b IA).
    await tester.tap(find.byKey(const Key('home_record_cta')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('quick_stats')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await snapState(tester, 'state1_stats_daily', [
      find.text('净结余（收入 − 支出）'),
      find.text('支出类别占比'),
    ]);

    // 2. Switch to monthly range.
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snapState(tester, 'state2_stats_monthly', [
      find.text('月'),
      find.text('净结余（收入 − 支出）'),
    ]);

    // 3. Switch to yearly range.
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snapState(tester, 'state3_stats_yearly', [
      find.text('年'),
      find.text('净结余（收入 − 支出）'),
    ]);

    // 4. Export produces CSV + JSON in documents dir.
    await tester.scrollUntilVisible(
      find.text('导出 CSV / JSON（带 BOM）'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 CSV / JSON（带 BOM）'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // SnackBar confirmation is the UI proof; the files are verified in unit
    // tests (BOM) + we re-verify by listing the export dir in WORKLOG.
    expect(find.textContaining('已导出'), findsOneWidget);
    // ignore: avoid_print
    print('EXPORT_SNACKBAR_OK');
  });
}
