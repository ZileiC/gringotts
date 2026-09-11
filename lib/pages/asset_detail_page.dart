import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app.dart';
import '../data/app_database.dart';
import '../data/repositories/asset_photo_repository.dart';
import '../data/repositories/repositories.dart';
import '../domain/models.dart';
import '../services/cpd_calculator.dart';
import '../services/photo_service.dart';
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditAssetSheet(asset: asset),
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
                key: const Key('detail_edit_button'),
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
        // T-09D: live rows are the hero wall source. They used to be dropped
        // here, so a photo added after creation never reached the wall.
        return _build(
          context,
          snapshot.data ?? const <AssetPhoto>[],
          dataArea,
          theme,
        );
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
    // Same source as the list tile cover (T-09D): live asset_photos rows,
    // legacy single photoPath only as a fallback when no rows exist.
    final paths = AssetPhotoRepository.displayPaths(
      photos: photos,
      legacyPath: asset.photoPath,
    );
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
          // Hero flight curve per DESIGN_T09 section 5E.
          curve: Curves.easeOutCubic,
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

/// Edit sheet (T-09D): name / value / category / purchase date + photos.
///
/// The purchase date feeds [CpdCalculator] and the holding-day count directly,
/// so saving it recomputes both from the same source the list page uses (never
/// a second algorithm). Photo actions are applied straight through
/// [AssetPhotoRepository] - add = append at the end (next sort), delete =
/// tombstone, set cover = sort swap. Drag reordering is deliberately out of
/// scope (T-09D).
class _EditAssetSheet extends ConsumerStatefulWidget {
  const _EditAssetSheet({required this.asset});

  final Asset asset;

  @override
  ConsumerState<_EditAssetSheet> createState() => _EditAssetSheetState();
}

class _EditAssetSheetState extends ConsumerState<_EditAssetSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late AssetCategory _category;
  late DateTime _purchasedAt;
  bool _busy = false;

  AssetRepository get _repo => ref.read(assetRepositoryProvider);
  AssetPhotoRepository get _photoRepo => ref.read(assetPhotoRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.asset.name);
    _valueController = TextEditingController(
      text: (widget.asset.valueCents / 100).toStringAsFixed(2),
    );
    _category = widget.asset.category;
    _purchasedAt = widget.asset.purchasedAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _purchasedAt = picked);
    }
  }

  /// Adds photos through the shared pipeline: picker -> PhotoService (compress
  /// + sha256 name) -> asset_photos row at the end of the strip.
  Future<void> _addPhotos(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final dir = await getApplicationSupportDirectory();
      final photosDir = '${dir.path}${Platform.pathSeparator}photos';
      final List<XFile?> picked;
      if (source == ImageSource.camera) {
        picked = <XFile?>[await picker.pickImage(source: source, imageQuality: 95)];
      } else {
        picked = (await picker.pickMultiImage(imageQuality: 95))
            .map<XFile?>((x) => x)
            .toList();
      }
      for (final x in picked) {
        if (x == null) continue;
        final bytes = await x.readAsBytes();
        final saved =
            await PhotoService.saveCompressed(bytes, directory: photosDir);
        final sort = await _photoRepo.nextSort(widget.asset.id);
        await _photoRepo.create(
          assetId: widget.asset.id,
          path: saved,
          sort: sort,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Removes a photo: tombstone only, the row is never physically deleted.
  Future<void> _removePhoto(AssetPhoto photo) async {
    await _photoRepo.softDelete(photo.id);
    if (mounted) setState(() {});
  }

  /// Promotes a photo to cover by swapping its sort with the current cover.
  Future<void> _setCover(AssetPhoto photo) async {
    await _photoRepo.setCover(assetId: widget.asset.id, photoId: photo.id);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final yuan = double.tryParse(_valueController.text.trim());
    if (name.isEmpty || yuan == null || yuan <= 0) return;
    // updateAsset refreshes updated_at; CPD / holding days recompute from
    // purchasedAt through CpdCalculator (same source as the list page).
    await _repo.updateAsset(
      id: widget.asset.id,
      name: name,
      category: _category,
      valueCents: (yuan * 100).round(),
      purchasedAt: _purchasedAt,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
          Text('编辑资产', style: theme.textTheme.titleLarge),
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
              ButtonSegment(
                  value: AssetCategory.hardCurrency, label: Text('硬通货')),
              ButtonSegment(value: AssetCategory.digital, label: Text('数码')),
              ButtonSegment(
                  value: AssetCategory.nonStandard, label: Text('非标品')),
              ButtonSegment(value: AssetCategory.ordinary, label: Text('普通')),
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              TextButton.icon(
                key: const Key('edit_date_button'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text('购买日期 ${_formatDate(_purchasedAt)}'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Text('照片', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                key: const Key('edit_photo_add_gallery'),
                onPressed: _busy ? null : () => _addPhotos(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('相册'),
              ),
              TextButton.icon(
                key: const Key('edit_photo_add_camera'),
                onPressed: _busy ? null : () => _addPhotos(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
              ),
            ],
          ),
          StreamBuilder<List<AssetPhoto>>(
            stream: _photoRepo.watchForAsset(widget.asset.id).watch(),
            builder: (context, snapshot) {
              final photos = snapshot.data ?? const <AssetPhoto>[];
              if (photos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Text('还没有照片', style: theme.textTheme.bodySmall),
                );
              }
              return SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.s),
                  itemBuilder: (context, index) => _EditPhotoThumb(
                    photo: photos[index],
                    index: index,
                    isCover: index == 0,
                    onDelete: () => _removePhoto(photos[index]),
                    onSetCover: () => _setCover(photos[index]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            key: const Key('edit_save'),
            onPressed: _save,
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
  }
}

/// One thumbnail in the edit sheet photo strip: delete (tombstone) + set cover.
class _EditPhotoThumb extends StatelessWidget {
  const _EditPhotoThumb({
    required this.photo,
    required this.index,
    required this.isCover,
    required this.onDelete,
    required this.onSetCover,
  });

  final AssetPhoto photo;
  final int index;
  final bool isCover;
  final VoidCallback onDelete;
  final VoidCallback onSetCover;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: Image.file(
                File(photo.path),
                key: Key('edit_photo_$index'),
                width: _size,
                height: _size,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                key: Key('edit_photo_delete_$index'),
                onTap: onDelete,
                child: const Icon(
                  Icons.cancel,
                  size: 20,
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (isCover)
          Text('封面', style: theme.textTheme.bodySmall)
        else
          TextButton(
            key: Key('edit_photo_cover_$index'),
            onPressed: onSetCover,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(56, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('设封面'),
          ),
      ],
    );
  }
}
