import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../services/cpd_calculator.dart';
import '../services/photo_service.dart';
import '../ui/tokens.dart';

/// Asset portfolio page: net-value dashboard, list with CPD badges, add
/// asset form (photo pipeline), sell dialog with realization review.
class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  AssetRepository get _repo => ref.read(assetRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资产档案')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Asset>>(
        stream: _repo.watchAll(),
        builder: (context, snapshot) {
          final assets = snapshot.data ?? const <Asset>[];
          final portfolio = AssetPortfolio.breakdown(assets);
          final inService =
              assets.where((a) => a.status == AssetStatus.inService).toList();
          final sold =
              assets.where((a) => a.status == AssetStatus.sold).toList();
          final retired =
              assets.where((a) => a.status == AssetStatus.retired).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.m),
            children: [
              _NetValueCard(portfolio: portfolio),
              const SizedBox(height: AppSpacing.l),
              if (inService.isNotEmpty) ...[
                Text('服役中', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s),
                ...inService.map((a) => _AssetTile(asset: a, repo: _repo)),
              ],
              if (retired.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.m),
                Text('已退役', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s),
                ...retired.map((a) => _AssetTile(asset: a, repo: _repo)),
              ],
              if (sold.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.m),
                Text('已卖出', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.s),
                ...sold.map((a) => _SoldTile(asset: a)),
              ],
              if (assets.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Text('还没有资产，点右下角 + 添加'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddAssetSheet(),
    );
  }
}

/// Net value dashboard card.
class _NetValueCard extends StatelessWidget {
  const _NetValueCard({required this.portfolio});

  final ({int inServiceCents, int soldRealizedCents, int retiredCents, int netCents})
      portfolio;

  String _yuan(int cents) {
    final display = cents % 100 == 0
        ? (cents ~/ 100).toString()
        : (cents / 100).toStringAsFixed(2);
    return '¥$display';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总资产净值', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _yuan(portfolio.netCents),
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: AppFont.display - 8,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                _Pill('服役 ${_yuan(portfolio.inServiceCents)}'),
                const SizedBox(width: AppSpacing.s),
                _Pill('退役 ${_yuan(portfolio.retiredCents)}'),
                const SizedBox(width: AppSpacing.s),
                _Pill('已实现 ${_yuan(portfolio.soldRealizedCents)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small info pill.
class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// In-service / retired asset row with CPD badge and service progress bar.
class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.repo});

  final Asset asset;
  final AssetRepository repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cpd = CpdCalculator.cpdForAsset(asset);
    final days = CpdCalculator.heldDays(
      purchasedAt: asset.purchasedAt,
      asOf: DateTime.now(),
      soldAt: asset.soldAt,
    );
    final cpdYuan = cpd % 100 == 0
        ? (cpd ~/ 100).toString()
        : (cpd / 100).toStringAsFixed(1);
    final display = asset.valueCents % 100 == 0
        ? (asset.valueCents ~/ 100).toString()
        : (asset.valueCents / 100).toStringAsFixed(2);

    // Service progress: 1 year reference bar (365 days).
    final progress = (days / 365).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (asset.photoPath != null &&
                    File(asset.photoPath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    child: Image.file(
                      File(asset.photoPath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: const Icon(Icons.inventory_2),
                  ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name, style: theme.textTheme.titleLarge),
                      Text(
                        '¥$display · $days 天',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
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
                    '¥$cpdYuan/天',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: AppSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => repo.markRetired(asset.id),
                  child: const Text('退役'),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton.tonal(
                  onPressed: () => _openSellDialog(context),
                  child: const Text('卖出'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSellDialog(BuildContext context) {
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
              final cents = (yuan * 100).round();
              repo.markSold(
                id: asset.id,
                soldPriceCents: cents,
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

/// Sold asset row with realization review (B8).
class _SoldTile extends StatelessWidget {
  const _SoldTile({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = CpdCalculator.realizedProfitCents(asset);
    final retention = CpdCalculator.retentionPermille(asset);
    final days = CpdCalculator.heldDays(
      purchasedAt: asset.purchasedAt,
      asOf: DateTime.now(),
      soldAt: asset.soldAt,
    );
    final totalCpd = CpdCalculator.cpdCents(
      valueCents: asset.soldPriceCents ?? 0,
      heldDays: days,
    );

    String yuan(int cents) => cents % 100 == 0
        ? '¥${cents ~/ 100}'
        : '¥${(cents / 100).toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(asset.name, style: theme.textTheme.titleLarge)),
                Text(
                  profit >= 0 ? '+${yuan(profit)}' : yuan(profit),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: profit >= 0
                      ? AppColors.semanticIncome
                      : AppColors.semanticExpense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              '买入 ${yuan(asset.valueCents)} → 卖出 ${yuan(asset.soldPriceCents ?? 0)}'
              ' · 保值率 ${(retention / 10).toStringAsFixed(1)}%'
              ' · 总成本 ${yuan(totalCpd)}/天 · 持有 $days 天',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet form to add an asset with photo pipeline.
class _AddAssetSheet extends ConsumerStatefulWidget {
  const _AddAssetSheet();

  @override
  ConsumerState<_AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends ConsumerState<_AddAssetSheet> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  AssetCategory _category = AssetCategory.ordinary;
  DateTime _purchasedAt = DateTime.now();
  String? _photoPath;
  bool _saving = false;

  AssetRepository get _repo => ref.read(assetRepositoryProvider);

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;
    final dir = await getApplicationSupportDirectory();
    final photosDir = '${dir.path}${Platform.pathSeparator}photos';
    final bytes = await picked.readAsBytes();
    final saved = await PhotoService.saveCompressed(bytes, directory: photosDir);
    setState(() => _photoPath = saved);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final yuan = double.tryParse(_valueController.text.trim());
    if (name.isEmpty || yuan == null || yuan <= 0 || _saving) return;
    setState(() => _saving = true);
    await _repo.create(
      name: name,
      category: _category,
      valueCents: (yuan * 100).round(),
      purchasedAt: _purchasedAt,
      photoPath: _photoPath,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        top: AppSpacing.l,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加资产', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '价值（元）'),
          ),
          const SizedBox(height: AppSpacing.m),
          SegmentedButton<AssetCategory>(
            segments: const [
              ButtonSegment(value: AssetCategory.hardCurrency, label: Text('硬通货')),
              ButtonSegment(value: AssetCategory.digital, label: Text('数码')),
              ButtonSegment(value: AssetCategory.nonStandard, label: Text('非标品')),
              ButtonSegment(value: AssetCategory.ordinary, label: Text('普通')),
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _purchasedAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _purchasedAt = date);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  '${_purchasedAt.year}-${_purchasedAt.month.toString().padLeft(2, '0')}-${_purchasedAt.day.toString().padLeft(2, '0')}',
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('相册'),
              ),
              TextButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
              ),
            ],
          ),
          if (_photoPath != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    child: Image.file(
                      File(_photoPath!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      '已压缩保存（hash 命名）',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
