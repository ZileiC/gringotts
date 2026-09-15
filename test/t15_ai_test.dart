import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/pages/ai_config_page.dart';
import 'package:gringotts/pages/ai_page.dart';
import 'package:gringotts/services/ai_client.dart';
import 'package:gringotts/services/ai_key_store.dart';
import 'package:gringotts/services/ai_providers.dart';
import 'package:gringotts/services/ai_settings.dart';
import 'package:gringotts/ui/tokens.dart';

/// T-15 acceptance (DESIGN_AI.md section 14 / TICKETS_M2A T-15):
/// - preset chips / folded advanced / privacy card chrome,
/// - 测试连接 three-state feedback driven by a fake transport,
/// - key + settings survive a "restart" (secure storage read back),
/// - the six-way error taxonomy,
/// - the probe is one minimal request (never an analysis payload),
/// - no key literal in the source, the key's only sink is secure storage.

/// Deterministic transport: the test swaps [onSend] to reproduce each state.
class _FakeTransport implements AiTransport {
  _FakeTransport(this.onSend);

  Future<AiHttpResponse> Function(Uri uri, String apiKey, String body) onSend;

  @override
  Future<AiHttpResponse> send({
    required Uri uri,
    required String apiKey,
    required String body,
    required Duration timeout,
  }) =>
      onSend(uri, apiKey, body);
}

const String _okBody = '{"choices":[{"message":{"content":"pong"}}]}';

Future<void> pumpConfig(
  WidgetTester tester, {
  required AiKeyStore store,
  AiTransport? transport,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiKeyStoreProvider.overrideWithValue(store),
        if (transport != null)
          aiClientProvider.overrideWithValue(AiClient(transport: transport)),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const AiConfigPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpAiPage(WidgetTester tester, AiKeyStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [aiKeyStoreProvider.overrideWithValue(store)],
      child: MaterialApp(theme: buildAppTheme(), home: const AiPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  test('T-15 presets carry baseURL + default model; defaults are frozen', () {
    expect(aiProviderPresets.map((p) => p.label).toList(),
        ['DeepSeek', 'OpenAI', '通义', 'Kimi', '自定义']);
    for (final preset in aiProviderPresets) {
      if (preset.id == AiProviderId.custom) continue;
      expect(preset.baseUrl, startsWith('https://'));
      expect(preset.model, isNotEmpty);
    }
    expect(aiDefaultProvider, AiProviderId.deepseek);
    expect(aiDefaultTimeoutSeconds, 20);

    final settings = AiSettings.fromPreset(AiProviderId.openai);
    expect(AiSettings.tryDecode(settings.encode()), settings);
  });

  test('T-15 client taxonomy: notConfigured/401/timeout/network/429/empty',
      () async {
    final settings = AiSettings.fromPreset(AiProviderId.deepseek);
    AiClient clientWith(Future<AiHttpResponse> Function() answer) => AiClient(
        transport: _FakeTransport((_, _, _) => answer()));

    Future<AiErrorKind?> kindOf(Future<AiHttpResponse> Function() answer,
            {String apiKey = 'k'}) async =>
        (await clientWith(answer)
                .testConnection(settings: settings, apiKey: apiKey))
            .error;

    expect(await kindOf(() async => const AiHttpResponse(200, _okBody),
            apiKey: ''), AiErrorKind.notConfigured);
    expect(await kindOf(() async => const AiHttpResponse(401, '{}')),
        AiErrorKind.unauthorized);
    expect(
        await kindOf(() async =>
            throw const AiTransportFailure(AiErrorKind.timeout)),
        AiErrorKind.timeout);
    expect(
        await kindOf(() async =>
            throw const AiTransportFailure(AiErrorKind.network)),
        AiErrorKind.network);
    expect(await kindOf(() async => const AiHttpResponse(429, '{}')),
        AiErrorKind.rateLimited);
    expect(
        await kindOf(() async =>
            const AiHttpResponse(200, '{"choices":[]}')),
        AiErrorKind.emptyReply);

    final ok = await clientWith(() async => const AiHttpResponse(200, _okBody))
        .testConnection(settings: settings, apiKey: 'k');
    expect(ok.ok, isTrue);
    expect(ok.latencyMs, isNotNull);
  });

  test('T-15 probe is one minimal request, never an analysis payload',
      () async {
    String? captured;
    final client = AiClient(
      transport: _FakeTransport((_, _, body) async {
        captured = body;
        return const AiHttpResponse(200, _okBody);
      }),
    );
    await client.testConnection(
      settings: AiSettings.fromPreset(AiProviderId.deepseek),
      apiKey: 'k',
    );
    final decoded = jsonDecode(captured!) as Map<String, dynamic>;
    expect(decoded['max_tokens'], 1);
    expect(decoded['stream'], false);
    expect((decoded['messages'] as List<dynamic>).length, 1);
  });

  test('T-15 restart: key + settings are read back from the store', () async {
    final store = InMemoryAiKeyStore();
    final first = ProviderContainer(
      overrides: [aiKeyStoreProvider.overrideWithValue(store)],
    );
    await first.read(aiConfigProvider.future);
    first.read(aiConfigProvider.notifier).updateApiKey('sk-roundtrip');
    first.read(aiConfigProvider.notifier)
        .updateSettings(AiSettings.fromPreset(AiProviderId.openai));
    first.dispose();

    final second = ProviderContainer(
      overrides: [aiKeyStoreProvider.overrideWithValue(store)],
    );
    final restored = await second.read(aiConfigProvider.future);
    expect(restored.apiKey, 'sk-roundtrip');
    expect(restored.settings.providerId, AiProviderId.openai);
    expect(restored.settings.baseUrl,
        aiPresetFor(AiProviderId.openai).baseUrl);
    expect(restored.configured, isTrue);
    second.dispose();
  });

  test('T-15 source audit: key never in source; secure storage is the sink',
      () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('flutter_secure_storage'));
    expect(File('lib/services/ai_key_store.dart').readAsStringSync(),
        contains('flutter_secure_storage'));

    final aiSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    expect(RegExp(r'sk-[A-Za-z0-9]{8,}').hasMatch(aiSources), isFalse,
        reason: 'no literal API key may live in the source tree');
    expect(RegExp(r'print\([^)]*[Kk]ey').hasMatch(aiSources), isFalse,
        reason: 'the key is never sent to a log');
    expect(File('lib/services/ai_key_store.dart').readAsStringSync(),
        contains('InMemoryAiKeyStore'));
  });

  testWidgets('T-15 config chrome: 5 chips / folded advanced / privacy card',
      (tester) async {
    await pumpConfig(tester, store: InMemoryAiKeyStore());

    for (final preset in aiProviderPresets) {
      expect(find.byKey(Key('ai_preset_${preset.id.name}')), findsOneWidget);
    }
    expect(find.byKey(const Key('ai_key_field')), findsOneWidget);
    expect(find.byKey(const Key('ai_key_paste')), findsOneWidget);
    expect(find.byKey(const Key('ai_test_button')), findsOneWidget);

    // Advanced is folded by default.
    expect(find.byKey(const Key('ai_base_url_field')), findsNothing);

    // Privacy card: the three plain-language lines.
    expect(find.byKey(const Key('ai_privacy_card')), findsOneWidget);
    expect(find.text('存放位置 = 系统安全存储'), findsOneWidget);
    expect(find.text('会不会进日志 = 不会'), findsOneWidget);
    expect(find.text('发送给模型的内容 = 只有聚合统计'), findsOneWidget);

    // DeepSeek is the default selection.
    Color? chipColor(String id) {
      final container = tester.widget<Container>(find
          .descendant(
              of: find.byKey(Key('ai_preset_$id')),
              matching: find.byType(Container))
          .first);
      return (container.decoration as BoxDecoration).color;
    }

    expect(chipColor('deepseek'), AppColors.goldContainer);
    expect(chipColor('custom'), Colors.transparent);

    // Selecting 自定义 auto-expands the advanced section.
    await tester.tap(find.byKey(const Key('ai_preset_custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai_base_url_field')), findsOneWidget);
    expect(chipColor('custom'), AppColors.goldContainer);

    await disposeTree(tester);
  });

  testWidgets('T-15 测试连接 three states: 可用 / key 无效 / 连不上',
      (tester) async {
    final transport =
        _FakeTransport((_, _, _) async => const AiHttpResponse(200, _okBody));
    await pumpConfig(
      tester,
      store: InMemoryAiKeyStore(),
      transport: transport,
    );
    await tester.enterText(find.byKey(const Key('ai_key_field')), 'sk-probe');
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('ai_test_button'));
    await tester.ensureVisible(button);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('可用 '), findsOneWidget);

    transport.onSend =
        (_, _, _) async => const AiHttpResponse(401, '{"error":"bad key"}');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('key 无效，请检查是否复制完整'), findsOneWidget);

    transport.onSend = (_, _, _) async =>
        throw const AiTransportFailure(AiErrorKind.network);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('连不上，检查网络或接口地址'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('T-15 AI tab: 未配置 guide, no fake data, reaches the config page',
      (tester) async {
    await pumpAiPage(tester, InMemoryAiKeyStore());

    expect(find.byKey(const Key('ai_unconfigured_guide')), findsOneWidget);
    expect(find.text('先接一个 AI 服务商'), findsOneWidget);
    expect(find.byKey(const Key('ai_coming_card')), findsOneWidget);
    expect(find.text('本月分析'), findsOneWidget);
    expect(find.text('对话记录'), findsOneWidget);
    expect(find.text('只发聚合统计'), findsOneWidget);
    expect(find.textContaining('唤醒'), findsNothing,
        reason: 'T-15 must not draw the 唤醒 AI key');

    await tester.tap(find.byKey(const Key('ai_go_configure')));
    await tester.pumpAndSettle();
    expect(find.byType(AiConfigPage), findsOneWidget);

    await disposeTree(tester);
  });

  test('T-15 production store is the platform secure store', () {
    final container = ProviderContainer();
    expect(container.read(aiKeyStoreProvider), isA<SecureAiKeyStore>());
    container.dispose();
  });

  testWidgets('T-15 AI tab drops the guide once a key is stored',
      (tester) async {
    await pumpAiPage(tester, InMemoryAiKeyStore(apiKey: 'sk-stored'));
    expect(find.byKey(const Key('ai_unconfigured_guide')), findsNothing);
    expect(find.byKey(const Key('ai_coming_card')), findsOneWidget);
    await disposeTree(tester);
  });
}
