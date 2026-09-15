import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_settings.dart';

/// Secure-storage facade for the AI key and settings.
///
/// AGENTS.md hard rule: the API key only ever enters flutter_secure_storage -
/// never the database, the source tree, git or a log line. On Android the
/// default backend is the platform Keystore; on Windows it is the DPAPI-backed
/// store.
abstract interface class AiKeyStore {
  Future<String?> readApiKey();
  Future<void> writeApiKey(String apiKey);
  Future<AiSettings?> readSettings();
  Future<void> writeSettings(AiSettings settings);
}

/// Production store.
class SecureAiKeyStore implements AiKeyStore {
  SecureAiKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  /// Entry names only; the values are the user's key and preferences.
  static const String apiKeyEntry = 'gringotts.ai.api_key';
  static const String settingsEntry = 'gringotts.ai.settings_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readApiKey() => _storage.read(key: apiKeyEntry);

  @override
  Future<void> writeApiKey(String apiKey) => apiKey.isEmpty
      ? _storage.delete(key: apiKeyEntry)
      : _storage.write(key: apiKeyEntry, value: apiKey);

  @override
  Future<AiSettings?> readSettings() async =>
      AiSettings.tryDecode(await _storage.read(key: settingsEntry));

  @override
  Future<void> writeSettings(AiSettings settings) =>
      _storage.write(key: settingsEntry, value: settings.encode());
}

/// Non-persistent store for widget tests and previews: same contract, no
/// platform channels. Production always uses [SecureAiKeyStore].
class InMemoryAiKeyStore implements AiKeyStore {
  InMemoryAiKeyStore({String? apiKey, AiSettings? settings})
      : _apiKey = apiKey ?? '',
        _settings = settings;

  String _apiKey;
  AiSettings? _settings;

  @override
  Future<String?> readApiKey() async => _apiKey.isEmpty ? null : _apiKey;

  @override
  Future<void> writeApiKey(String apiKey) async => _apiKey = apiKey;

  @override
  Future<AiSettings?> readSettings() async => _settings;

  @override
  Future<void> writeSettings(AiSettings settings) async => _settings = settings;
}
