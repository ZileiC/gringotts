import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_client.dart';
import '../services/ai_providers.dart';
import '../services/ai_settings.dart';
import '../ui/tokens.dart';

/// AI 配置页 (DESIGN_AI.md section 5, direction B).
///
/// Frozen block order: preset chips -> key + paste -> 测试连接 -> advanced
/// (folded by default) -> storage & privacy card. The key only travels to
/// flutter_secure_storage through [AiConfigController.updateApiKey]; this page
/// never logs it and never puts it anywhere else.
class AiConfigPage extends ConsumerWidget {
  const AiConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(aiConfigProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const _ConfigTopBar(),
            Expanded(
              child: config.when(
                data: (state) => _ConfigBody(initial: state),
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.goldAccent,
                    ),
                  ),
                ),
                error: (_, _) => const Center(
                  child: Text(
                    '配置读取失败',
                    style: TextStyle(color: AppColors.inkSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigTopBar extends StatelessWidget {
  const _ConfigTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.topBarHeight,
      child: Row(
        children: [
          TextButton.icon(
            key: const Key('ai_config_back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.chevron_left,
              size: 20,
              color: AppColors.ink,
            ),
            label: const Text(
              '返回',
              style: TextStyle(color: AppColors.ink, fontSize: AppFont.bodySm),
            ),
          ),
          const Expanded(
            child: Text(
              'AI 配置',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFont.title,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(
            key: const Key('ai_config_help'),
            onPressed: () => _showHelp(context),
            child: const Text(
              '帮助',
              style: TextStyle(
                color: AppColors.inkSecondary,
                fontSize: AppFont.bodySm,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于 AI 配置'),
        content: const Text(
          '自带一个 OpenAI 兼容服务的 key。key 只保存在手机的系统安全存储里，'
          '不会上传，也不会进入日志。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _ConfigBody extends ConsumerStatefulWidget {
  const _ConfigBody({required this.initial});

  final AiConfigState initial;

  @override
  ConsumerState<_ConfigBody> createState() => _ConfigBodyState();
}

class _ConfigBodyState extends ConsumerState<_ConfigBody> {
  late final TextEditingController _key;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _timeout;
  late final TextEditingController _temperature;

  late AiProviderId _providerId;
  late bool _advancedOpen;
  bool _testing = false;
  AiTestResult? _result;

  @override
  void initState() {
    super.initState();
    final settings = widget.initial.settings;
    _providerId = settings.providerId;
    _advancedOpen = settings.providerId == AiProviderId.custom;
    _key = TextEditingController(text: widget.initial.apiKey);
    _baseUrl = TextEditingController(text: settings.baseUrl);
    _model = TextEditingController(text: settings.model);
    _timeout = TextEditingController(text: '${settings.timeoutSeconds}');
    _temperature = TextEditingController(text: '${settings.temperature}');
  }

  @override
  void didUpdateWidget(covariant _ConfigBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final settings = widget.initial.settings;
    if (settings.providerId != oldWidget.initial.settings.providerId) {
      _providerId = settings.providerId;
      if (settings.providerId == AiProviderId.custom) _advancedOpen = true;
      _baseUrl.text = settings.baseUrl;
      _model.text = settings.model;
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _timeout.dispose();
    _temperature.dispose();
    super.dispose();
  }

  AiSettings _collect() => widget.initial.settings.copyWith(
        providerId: _providerId,
        baseUrl: _baseUrl.text.trim(),
        model: _model.text.trim(),
        timeoutSeconds:
            int.tryParse(_timeout.text.trim()) ?? aiDefaultTimeoutSeconds,
        temperature:
            double.tryParse(_temperature.text.trim()) ?? aiDefaultTemperature,
      );

  void _persist() =>
      ref.read(aiConfigProvider.notifier).updateSettings(_collect());

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板里没有文字')),
      );
      return;
    }
    _key.text = text;
    ref.read(aiConfigProvider.notifier).updateApiKey(text);
  }

  Future<void> _testConnection() async {
    final settings = _collect();
    final apiKey = _key.text.trim();
    final notifier = ref.read(aiConfigProvider.notifier);
    notifier.updateSettings(settings);
    notifier.updateApiKey(apiKey);
    setState(() {
      _testing = true;
      _result = null;
    });
    final result = await ref
        .read(aiClientProvider)
        .testConnection(settings: settings, apiKey: apiKey);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('选一家'),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final preset in aiProviderPresets)
                _PresetChip(
                  key: Key('ai_preset_${preset.id.name}'),
                  label: preset.label,
                  selected: preset.id == _providerId,
                  onTap: () => _selectPreset(preset.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _sectionLabel('API Key'),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ai_key_field'),
                  controller: _key,
                  obscureText: true,
                  onChanged: (value) =>
                      ref.read(aiConfigProvider.notifier).updateApiKey(value),
                  decoration: const InputDecoration(hintText: '粘贴你的 API Key'),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              _OutlinedKeyButton(
                key: const Key('ai_key_paste'),
                label: '粘贴',
                onTap: _pasteKey,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              _OutlinedKeyButton(
                key: const Key('ai_test_button'),
                label: _testing ? '测试中' : '测试连接',
                onTap: _testing ? null : _testConnection,
              ),
              const SizedBox(width: AppSpacing.m),
              if (_result != null)
                _TestFeedback(key: const Key('ai_test_result'), result: _result!),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          InkWell(
            key: const Key('ai_advanced_toggle'),
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Row(
                children: [
                  _sectionLabel('高级'),
                  const Spacer(),
                  Icon(
                    _advancedOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.inkSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_advancedOpen) ...[
            const SizedBox(height: AppSpacing.s),
            _FieldRow(
              label: '接口地址',
              child: TextField(
                key: const Key('ai_base_url_field'),
                controller: _baseUrl,
                onChanged: (_) => _persist(),
                decoration: const InputDecoration(hintText: 'https://'),
              ),
            ),
            _FieldRow(
              label: '模型',
              child: TextField(
                key: const Key('ai_model_field'),
                controller: _model,
                onChanged: (_) => _persist(),
                decoration: const InputDecoration(hintText: 'model'),
              ),
            ),
            _FieldRow(
              label: '超时',
              child: TextField(
                key: const Key('ai_timeout_field'),
                controller: _timeout,
                keyboardType: TextInputType.number,
                onChanged: (_) => _persist(),
                decoration: const InputDecoration(suffixText: '秒'),
              ),
            ),
            _FieldRow(
              label: '温度',
              child: TextField(
                key: const Key('ai_temperature_field'),
                controller: _temperature,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _persist(),
                decoration: const InputDecoration(hintText: '0.2'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          _sectionLabel('存储与隐私'),
          const SizedBox(height: AppSpacing.s),
          const _PrivacyCard(),
        ],
      ),
    );
  }

  void _selectPreset(AiProviderId id) {
    setState(() {
      _providerId = id;
      if (id == AiProviderId.custom) _advancedOpen = true;
    });
    ref.read(aiConfigProvider.notifier).selectProvider(id);
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: AppFont.caption,
          letterSpacing: 0.8,
          color: AppColors.inkSecondary,
        ),
      );
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: AppSpacing.aiChipHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.goldAccent : AppColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFont.bodySm,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.onGoldContainer : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _OutlinedKeyButton extends StatelessWidget {
  const _OutlinedKeyButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.controlHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFont.bodySm,
            color: onTap == null ? AppColors.inkSecondary : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppFont.bodySm,
                color: AppColors.inkSecondary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TestFeedback extends StatelessWidget {
  const _TestFeedback({super.key, required this.result});

  final AiTestResult result;

  @override
  Widget build(BuildContext context) {
    final color =
        result.ok ? AppColors.semanticIncome : AppColors.semanticExpense;
    final text = result.ok
        ? '可用  ${result.latencyMs ?? 0}ms'
        : _messageFor(result.error);
    return Text(
      text,
      style: TextStyle(fontSize: AppFont.bodySm, color: color),
    );
  }

  static String _messageFor(AiErrorKind? kind) => switch (kind) {
        AiErrorKind.unauthorized => 'key 无效，请检查是否复制完整',
        AiErrorKind.notConfigured => '还没有填 API Key',
        _ => '连不上，检查网络或接口地址',
      };
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ai_privacy_card'),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.hairline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PrivacyRow(label: '存放位置', value: '系统安全存储'),
          SizedBox(height: AppSpacing.s),
          _PrivacyRow(label: '会不会进日志', value: '不会'),
          SizedBox(height: AppSpacing.s),
          _PrivacyRow(label: '发送给模型的内容', value: '只有聚合统计'),
        ],
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label = $value',
      style: const TextStyle(fontSize: AppFont.bodySm, color: AppColors.ink),
    );
  }
}
