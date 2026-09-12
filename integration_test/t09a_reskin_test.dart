import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/app/app.dart';
import 'package:integration_test/integration_test.dart';

Future<void> snap(
  WidgetTester tester,
  String name,
  List<Finder> required,
) async {
  await tester.pumpAndSettle(const Duration(seconds: 1));
  for (final f in required) {
    expect(f, findsWidgets, reason: 'missing before snap $name');
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List();
  expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47]);
  // T-10b IA update: reruns must not overwrite the original ticket evidence.
  final file = File('evidence/t10b/regression/.t09a_$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  // ignore: avoid_print
  print('T09A_SNAP name=$name md5=${md5.convert(bytes).toString().substring(0, 12)}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-09A reskin evidence frames', (tester) async {
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

    // T-10b IA: launch = analysis home; the keypad is a secondary page.
    await tester.tap(find.byKey(const Key('home_record_cta')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await snap(tester, '01_quick_entry', [
      find.text('GRINGOTTS'),
      find.byKey(const Key('confirm_cta')),
      find.text('支出'),
    ]);

    await tester.tap(find.byKey(const Key('quick_assets')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await snap(tester, '02_assets', [
      find.text('资产档案'),
      find.text('总资产净值'),
    ]);
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('quick_stats')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await snap(tester, '03_stats', [
      find.text('净结余（收入 − 支出）'),
      find.text('支出类别占比'),
    ]);
  });
}
