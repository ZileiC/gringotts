import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_providers.dart';
import '../ui/tokens.dart';
import 'ai_config_page.dart';

/// AI tab: the fourth peer tab of the M2.0 IA (分析  AI  资产  统计).
///
/// T-15 ships the unconfigured guide state only (DESIGN_AI.md section 2.2 item
/// 5). The month button, the analysis card, the conversation list and the
/// 唤醒 AI key belong to T-16 / T-17; nothing here fabricates data.
class AiPage extends ConsumerWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured =
        ref.watch(aiConfigProvider).valueOrNull?.configured ?? false;
    return Scaffold(
      key: const Key('ai_page'),
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const _AiTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  AppSpacing.s,
                  AppSpacing.m,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!configured) const _UnconfiguredGuide(),
                    if (!configured) const SizedBox(height: AppSpacing.m),
                    const _ComingCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiTopBar extends StatelessWidget {
  const _AiTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.s),
            const Text(
              'AI',
              style: TextStyle(
                fontFamily: AppFont.uiFamily,
                fontSize: AppFont.title,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const Key('ai_config_entry'),
              tooltip: 'AI 配置',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AiConfigPage()),
              ),
              icon: const Icon(
                Icons.settings_outlined,
                size: 20,
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnconfiguredGuide extends StatelessWidget {
  const _UnconfiguredGuide();

  @override
  Widget build(BuildContext context) {
    return _AiCard(
      key: const Key('ai_unconfigured_guide'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先接一个 AI 服务商',
            style: TextStyle(
              fontSize: AppFont.title,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          const Text(
            '自带一个 key；key 只存在手机的安全存储里，我们不会拿走它。',
            style: TextStyle(
              fontSize: AppFont.bodySm,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: AppSpacing.controlHeight,
            child: OutlinedButton(
              key: const Key('ai_go_configure'),
              onPressed: () => _openConfig(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.hairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
              child: const Text('去配置'),
            ),
          ),
        ],
      ),
    );
  }

  void _openConfig(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiConfigPage()),
    );
  }
}

class _ComingCard extends StatelessWidget {
  const _ComingCard();

  @override
  Widget build(BuildContext context) {
    return const _AiCard(
      key: Key('ai_coming_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '配好之后这页会有',
            style: TextStyle(
              fontSize: AppFont.body,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: AppSpacing.s),
          _ComingRow(label: '本月分析'),
          SizedBox(height: AppSpacing.xs),
          _ComingRow(label: '对话记录'),
          SizedBox(height: AppSpacing.xs),
          _ComingRow(label: '只发聚合统计'),
        ],
      ),
    );
  }
}

class _ComingRow extends StatelessWidget {
  const _ComingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.goldAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppFont.bodySm,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }
}
