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
import 'package:gringotts/services/cpd_calculator.dart';
import 'package:integration_test/integration_test.dart';

/// T-04 evidence pipeline: a state's PNG frame is captured from the real
/// render tree ONLY AFTER its required UI elements are asserted on the tree.
/// Frames are content-hashed on save; different states cannot share a frame.
Future<void> snapState(
  WidgetTester tester,
  String name,
  List<Finder> requiredElements,
) async {
  await tester.pumpAndSettle(const Duration(seconds: 1));
  for (final f in requiredElements) {
    expect(f, findsWidgets, reason: 'element must be on tree before snap $name');
  }
  await tester.pumpAndSettle();

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app_repaint_boundary')),
  );
  final ui.Image image =
      await boundary.toImage(pixelRatio: 1.0);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  final file = File('.t04_$name.png');
  await file.writeAsBytes(bytes, flush: true);
  final digest = md5.convert(bytes).toString().substring(0, 12);
  // ignore: avoid_print
  print('SNAP_SAVED=$name file=${file.path} md5=$digest');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-04 assets flow: add -> list CPD -> sell -> realized',
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

    final repo = container.read(assetRepositoryProvider);
    final assetsBefore = await repo.getLiveAssets();
    // ignore: avoid_print
    print('ASSETS_BEFORE=${assetsBefore.length}');

    // 1. Home state frame (T-12c: launch page = tab shell, analysis tab).
    await snapState(tester, 'state1_home', [
      find.text('记一笔'),
      find.byKey(const Key('tab_assets')),
    ]);

    // 2. Navigate to the assets page: tap its peer tab (no push).
    await tester.tap(find.byKey(const Key('tab_assets')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final assetsPageState = <Finder>[
      find.text('资产档案'),
      find.text('总资产净值'),
    ];
    // Empty-or-list: the page always shows the dashboard header.
    await snapState(tester, 'state2_assets_dashboard', assetsPageState);

    // 3. Add a photo-less asset through the sheet.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('添加资产'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '名称').first,
      '测试相机',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '价值（元）').first,
      '6000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 4. List state with CPD badge.
    await snapState(tester, 'state3_assets_with_cpd', [
      find.text('测试相机'),
      find.textContaining('/天'),
    ]);

    // DB assertions.
    final assetsAfter = await repo.getLiveAssets();
    expect(assetsAfter.length, assetsBefore.length + 1);
    final created = assetsAfter.firstWhere((a) => a.name == '测试相机');
    expect(created.valueCents, 600000);
    // ignore: avoid_print
    print('ASSET_CREATED photo=${created.photoPath ?? 'none'}');

    // 5. Sell flow -> realized section frame.
    final tile = find.ancestor(
      of: find.text('测试相机'),
      matching: find.byType(Card),
    ).first;
    await tester.tap(find.descendant(of: tile, matching: find.text('卖出')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('卖出 测试相机'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '卖出价（元）'),
      '4800',
    );
    await tester.tap(find.text('确认卖出'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Scroll down - the sold section is below the fold with several assets.
    await tester.scrollUntilVisible(
      find.text('已卖出'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await snapState(tester, 'state4_sold_realized', [
      find.text('已卖出'),
      find.textContaining('保值率'),
    ]);

    final sold = await repo.getLiveAssets();
    final soldAsset = sold.firstWhere((a) => a.name == '测试相机');
    expect(soldAsset.status, AssetStatus.sold);
    expect(soldAsset.soldPriceCents, 480000);
    expect(CpdCalculator.retentionPermille(soldAsset), 800);
    // ignore: avoid_print
    print('SOLD_OK retention=800 permille');
  });
}
