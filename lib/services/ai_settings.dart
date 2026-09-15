import 'dart:convert';

/// AI provider presets and the persisted, key-free settings (DESIGN_AI.md
/// section 5, direction B).
///
/// The API key is deliberately *not* part of [AiSettings]: it only ever lives
/// in the platform secure storage (see `AiKeyStore`), never in the database,
/// the source tree, git or a log line.
enum AiProviderId { deepseek, openai, qwen, kimi, custom }

/// One preset chip: a label plus the baseURL and default model it fills in.
class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
  });

  final AiProviderId id;
  final String label;
  final String baseUrl;
  final String model;
}

/// Preset chips in row order (DESIGN_AI.md section 5 item 1). Each preset
/// carries its own baseURL and default model; `custom` starts empty so the
/// advanced section asks for the endpoint.
const List<AiProviderPreset> aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: AiProviderId.deepseek,
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    model: 'deepseek-chat',
  ),
  AiProviderPreset(
    id: AiProviderId.openai,
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
  ),
  AiProviderPreset(
    id: AiProviderId.qwen,
    label: '通义',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
  ),
  AiProviderPreset(
    id: AiProviderId.kimi,
    label: 'Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    model: 'moonshot-v1-8k',
  ),
  AiProviderPreset(
    id: AiProviderId.custom,
    label: '自定义',
    baseUrl: '',
    model: '',
  ),
];

/// The provider selected on a fresh install (DESIGN_AI.md section 5).
const AiProviderId aiDefaultProvider = AiProviderId.deepseek;

/// One-request timeout default (DESIGN_AI.md section 5 item 4).
const int aiDefaultTimeoutSeconds = 20;

/// Default sampling temperature shown in the advanced section.
const double aiDefaultTemperature = 0.2;

AiProviderPreset aiPresetFor(AiProviderId id) =>
    aiProviderPresets.firstWhere((preset) => preset.id == id);

/// The persisted AI settings; the key is stored separately.
class AiSettings {
  const AiSettings({
    required this.providerId,
    required this.baseUrl,
    required this.model,
    this.timeoutSeconds = aiDefaultTimeoutSeconds,
    this.temperature = aiDefaultTemperature,
  });

  factory AiSettings.fromPreset(AiProviderId id) {
    final preset = aiPresetFor(id);
    return AiSettings(
      providerId: id,
      baseUrl: preset.baseUrl,
      model: preset.model,
    );
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
        providerId: AiProviderId.values.firstWhere(
          (id) => id.name == json['providerId'],
          orElse: () => aiDefaultProvider,
        ),
        baseUrl: json['baseUrl'] as String? ?? '',
        model: json['model'] as String? ?? '',
        timeoutSeconds:
            (json['timeoutSeconds'] as num?)?.toInt() ?? aiDefaultTimeoutSeconds,
        temperature:
            (json['temperature'] as num?)?.toDouble() ?? aiDefaultTemperature,
      );

  final AiProviderId providerId;
  final String baseUrl;
  final String model;
  final int timeoutSeconds;
  final double temperature;

  AiSettings copyWith({
    AiProviderId? providerId,
    String? baseUrl,
    String? model,
    int? timeoutSeconds,
    double? temperature,
  }) =>
      AiSettings(
        providerId: providerId ?? this.providerId,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
        temperature: temperature ?? this.temperature,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'providerId': providerId.name,
        'baseUrl': baseUrl,
        'model': model,
        'timeoutSeconds': timeoutSeconds,
        'temperature': temperature,
      };

  String encode() => jsonEncode(toJson());

  /// Decodes a persisted settings blob; anything unreadable is treated as
  /// "no settings yet" instead of throwing on the startup path.
  static AiSettings? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AiSettings.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AiSettings &&
      other.providerId == providerId &&
      other.baseUrl == baseUrl &&
      other.model == model &&
      other.timeoutSeconds == timeoutSeconds &&
      other.temperature == temperature;

  @override
  int get hashCode => Object.hash(
        providerId,
        baseUrl,
        model,
        timeoutSeconds,
        temperature,
      );
}
