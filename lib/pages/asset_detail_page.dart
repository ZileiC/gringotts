import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/asset_photo_repository.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../services/cpd_calculator.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

/// Asset detail page (T-09B, DESIGN_T09 section 6).
///
/// Entered from the list tile via Hero relay on the cover photo. All numbers
/// come from [CpdCalculator] - the same source as the list page.
class AssetDetailPage extends ConsumerStatefulWidget {
  const AssetDetailPage({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  AssetRepository get _repo => ref.read(assetRepositoryProvider);
  AssetPhotoRepository get _photoRepo => ref.read(assetPhotoRepositoryProvider);

  Future<void> _confirmDelete(BuildContext context, Asset asset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除资产'),
        content: Text('确定删除「${asset.name}」吗？记录将标记为墓碑，不会物理删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.semanticExpense,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.softDelete(asset.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Asset>>(
        stream: _repo.watchAll(),
        builder: (context, snapshot) {
          final assets = snapshot.data ?? const <Asset>[];
          Asset? asset;
          for (final a in assets) {
            if (a.id == widget.assetId) {
              asset = a;
              break;
            }
          }
          if (asset == null) {
            return const Center(child: Text('资产不存在'));
          }
          final current = asset;
          return _DetailBody(
            key: ValueKey('detail_${asset.id}'),
            asset: asset,
            photoRepo: _photoRepo,
            onEdit: () => _openEditSheet(context, current),
            onSell: () {
              final current = asset;
              if (current != null) _openSellDialog(context, current);
            },
            onRetire: () => _repo.markRetired(current.id),
            onDelete: () {
              final current = asset;
              if (current != null) _confirmDelete(context, current);
            },
          );
        },
      ),
    );
  }

  void _openEditSheet(BuildContext context, Asset asset) {
    final nameCtrl = TextEditingController(text: asset.name);
    final valueCtrl = TextEditingController(
      text: (asset.valueCents / 100).toStringAsFixed(2),
    );
    var category = asset.category;
    var purchasedAt = asset.purchasedAt;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.l,
          right: AppSpacing.l,
          top: AppSpacing.l,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('编辑资产', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '价值（元）'),
            ),
            const SizedBox(height: AppSpacing.m),
            SegmentedButton<AssetCategory>(
              segments: const [
                ButtonSegment(
                    value: AssetCategory.hardCurrency, label: Text('硬通货')),
                ButtonSegment(
                    value: AssetCategory.digital, label: Text('数码')),
                ButtonSegment(
                    value: AssetCategory.nonStandard, label: Text('非标品')),
                ButtonSegment(
                    value: AssetCategory.ordinary, label: Text('普通')),
              ],
              selected: {category},
              onSelectionChanged: (s) => category = s.first,
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              onPressed: () {
                final yuan = double.tryParse(valueCtrl.text.trim());
                if (yuan == null || yuan <= 0) return;
                _repo.updateAsset(
                  id: asset.id,
                  name: nameCtrl.text.trim(),
                  category: category,
                  valueCents: (yuan * 100).round(),
                  purchasedAt: purchasedAt,
                );
                Navigator.of(sheetContext).pop();
              },
              child: const Text('保存修改'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSellDialog(BuildContext context, Asset asset) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('卖出 ${asset.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '卖出价（元）',
            hintText: '如 6800 或 6800.50',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final yuan = double.tryParse(controller.text.trim());
              if (yuan == null || yuan < 0) return;
              _repo.markSold(
                id: asset.id,
                soldPriceCents: (yuan * 100).round(),
                soldAt: DateTime.now(),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('确认卖出'),
          ),
        ],
      ),
    );
  }
}

/// Detail content: hero photo wall with 0.5x parallax + data + actions.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    super.key,
    required this.asset,
    required this.photoRepo,
    required this.onEdit,
    required this.onSell,
    required this.onRetire,
    required this.onDelete,
  });

  final Asset asset;
  final AssetPhotoRepository photoRepo;
  final VoidCallback onEdit;
  final VoidCallback onSell;
  final VoidCallback onRetire;
  final VoidCallback onDelete;

  String _yuan(int cents) => cents % 100 == 0
      ? '¥${cents ~/ 100}'
      : '¥${(cents / 100).toStringAsFixed(2)}';

  String _categoryLabel(AssetCategory category) {
    switch (category) {
      case AssetCategory.hardCurrency:
        return '硬通货';
      case AssetCategory.digital:
        return '数码';
      case AssetCategory.nonStandard:
        return '非标品';
      case AssetCategory.ordinary:
        return '普通物品';
    }
  }

  String _statusLabel(AssetStatus status) {
    switch (status) {
      case AssetStatus.inService:
        return '服役中';
      case AssetStatus.retired:
        return '已退役';
      case AssetStatus.sold:
        return '已卖出';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = CpdCalculator.heldDays(
      purchasedAt: asset.purchasedAt,
      asOf: DateTime.now(),
      soldAt: asset.soldAt,
    );
    final cpd = CpdCalculator.cpdForAsset(asset);
    final cpdYuan = cpd % 100 == 0
        ? (cpd ~/ 100).toString()
        : (cpd / 100).toStringAsFixed(1);
    final progress = (days / 365).clamp(0.0, 1.0);

    final Widget dataArea = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                asset.name,
                style: theme.textTheme.displaySmall,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.goldContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                _statusLabel(asset.status),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onGoldContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(_categoryLabel(asset.category),
            style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.xs,
          children: [
            _DataRow('价值 ${_yuan(asset.valueCents)}'),
            _DataRow(
              '购买 ${asset.purchasedAt.year}-${asset.purchasedAt.month.toString().padLeft(2, '0')}-${asset.purchasedAt.day.toString().padLeft(2, '0')}',
            ),
            _DataRow('持有 $days 天'),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.goldContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '¥$cpdYuan/天',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onGoldContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.hairline,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.goldAccent),
                ),
              ),
            ),
          ],
        ),
        if (asset.status == AssetStatus.sold) ...[
          const SizedBox(height: AppSpacing.m),
          _SoldReview(asset: asset),
        ],
        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.hairline),
                  foregroundColor: AppColors.ink,
                ),
                child: const Text('编辑'),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: OutlinedButton(
                onPressed: onSell,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.goldAccent),
                  foregroundColor: AppColors.goldAccent,
                ),
                child: Text(asset.status == AssetStatus.sold ? '已卖出' : '卖出'),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: OutlinedButton(
                onPressed: onRetire,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.hairline),
                  foregroundColor: AppColors.inkSecondary,
                ),
                child: const Text('退役'),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.semanticExpense),
                  foregroundColor: AppColors.semanticExpense,
                ),
                child: const Text('删除'),
              ),
            ),
          ],
        ),
      ],
    );

    return StreamBuilder<List<AssetPhoto>>(
      stream: photoRepo.watchForAsset(asset.id).watch(),
      builder: (context, snapshot) {
        return _build(context, const <AssetPhoto>[], dataArea, theme);
      },
    );
  }

  Widget _build(
    BuildContext context,
    List<AssetPhoto> photos,
    Widget dataArea,
    ThemeData theme,
  ) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 260,
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroWall(
              asset: asset,
              photos: photos,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: StaggerIn(children: [dataArea]),
          ),
        ),
      ],
    );
  }
}

/// Hero photo wall: PageView with dots; photo scrolls at 0.5x (max 48 px).
class _HeroWall extends StatelessWidget {
  const _HeroWall({required this.asset, required this.photos});

  final Asset asset;
  final List<AssetPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final paths = <String>[
      if (asset.photoPath != null) asset.photoPath!,
      ...photos.map((p) => p.path),
    ];
    if (paths.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.inventory_2, size: 64, color: AppColors.inkSecondary),
        ),
      );
    }
    return PageView.builder(
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final tag = 'asset_photo_${asset.id}_$index';
        return Hero(
          tag: tag,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 0.5x parallax with a hard 48 px budget (motion red line).
              final scrollable = Scrollable.of(context);
              return AnimatedBuilder(
                animation: scrollable.position,
                builder: (context, child) {
                  final offset = (scrollable.position.pixels * 0.5)
                      .clamp(-48.0, 48.0);
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child,
                  );
                },
                child: Image.file(
                  File(paths[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// One key-value chip in the data area.
class _DataRow extends StatelessWidget {
  const _DataRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontFeatures: AppFont.tabularFigures,
            ),
      ),
    );
  }
}

/// Realization review for sold assets.
///
/// Net cost/day = (buy - sell) / held days. This is the D1 ruling口径.
class _SoldReview extends StatelessWidget {
  const _SoldReview({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = CpdCalculator.realizedProfitCents(asset);
    final retention = CpdCalculator.retentionPermille(asset);
    final netCost = CpdCalculator.netCostCentsForAsset(asset);

    String yuan(int cents) => cents % 100 == 0
        ? '¥${cents ~/ 100}'
        : '¥${(cents / 100).toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('变现复盘', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '买入 ${yuan(asset.valueCents)} → 卖出 ${yuan(asset.soldPriceCents ?? 0)}'
            ' · 差价 ${profit >= 0 ? '+' : ''}${yuan(profit)}'
            ' · 保值率 ${(retention / 10).toStringAsFixed(1)}%'
            ' · 净成本 ${yuan(netCost)}/天',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: AppFont.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
