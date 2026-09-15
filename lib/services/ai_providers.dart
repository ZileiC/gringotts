import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_client.dart';
import 'ai_key_store.dart';
import 'ai_settings.dart';

/// The secure store used by the AI pages. Widget tests override it with
/// [InMemoryAiKeyStore].
final Provider<AiKeyStore> aiKeyStoreProvider =
    Provider<AiKeyStore>((ref) => SecureAiKeyStore());

/// One client instance for the whole app.
final Provider<AiClient> aiClientProvider =
    Provider<AiClient>((ref) => AiClient());

/// Loaded configuration + the in-memory copy of the key (never persisted
/// anywhere but the secure store).
class AiConfigState {
  const AiConfigState({required this.settings, this.apiKey = ''});

  final AiSettings settings;
  final String apiKey;

  bool get configured => apiKey.trim().isNotEmpty;

  AiConfigState copyWith({AiSettings? settings, String? apiKey}) =>
      AiConfigState(
        settings: settings ?? this.settings,
        apiKey: apiKey ?? this.apiKey,
      );
}

/// Loads / persists the AI settings + key. The key goes straight to the secure
/// store; this controller is the only writer.
class AiConfigController extends AsyncNotifier<AiConfigState> {
  @override
  Future<AiConfigState> build() async {
    final store = ref.watch(aiKeyStoreProvider);
    try {
      final settings = await store.readSettings() ??
          AiSettings.fromPreset(aiDefaultProvider);
      final apiKey = await store.readApiKey() ?? '';
      return AiConfigState(settings: settings, apiKey: apiKey);
    } catch (_) {
      // A missing platform channel must not white-screen the AI tab; fall back
      // to the unconfigured guide.
      return AiConfigState(settings: AiSettings.fromPreset(aiDefaultProvider));
    }
  }

  /// Selecting a preset restores that preset's baseURL + default model.
  void selectProvider(AiProviderId id) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = current.copyWith(settings: AiSettings.fromPreset(id));
    state = AsyncData(next);
    unawaited(ref.read(aiKeyStoreProvider).writeSettings(next.settings));
  }

  void updateSettings(AiSettings settings) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(settings: settings));
    unawaited(ref.read(aiKeyStoreProvider).writeSettings(settings));
  }

  void updateApiKey(String apiKey) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(apiKey: apiKey));
    unawaited(ref.read(aiKeyStoreProvider).writeApiKey(apiKey));
  }
}

final AsyncNotifierProvider<AiConfigController, AiConfigState> aiConfigProvider =
    AsyncNotifierProvider<AiConfigController, AiConfigState>(
        AiConfigController.new);
