import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/app_database.dart';

/// Full-data export service (T-05).
///
/// CSV carries a UTF-8 BOM so Excel opens Chinese correctly; JSON is the
/// complete raw dump including tombstones (backup-grade).
class ExportService {
  ExportService._();

  /// CSV BOM: Excel detects UTF-8 only when this prefix exists.
  static const List<int> utf8Bom = <int>[0xEF, 0xBB, 0xBF];

  static String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    final needsQuote =
        text.contains(',') || text.contains('"') || text.contains('\n');
    final escaped = text.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  /// Builds the transactions CSV (UTF-8 with BOM when written via [writeCsv]).
  static String transactionsCsv(List<Transaction> rows) {
    final header = [
      'id', 'amount_cents', 'type', 'category_id', 'merchant', 'note',
      'occurred_at', 'is_draft', 'source', 'created_at', 'updated_at',
      'deleted_at',
    ];
    final buffer = StringBuffer();
    buffer.writeln(header.join(','));
    for (final t in rows) {
      buffer.writeln([
        _csvCell(t.id),
        _csvCell(t.amountCents),
        _csvCell(t.type.name),
        _csvCell(t.categoryId),
        _csvCell(t.merchant),
        _csvCell(t.note),
        _csvCell(t.occurredAt.toIso8601String()),
        _csvCell(t.isDraft),
        _csvCell(t.source.name),
        _csvCell(t.createdAt.toIso8601String()),
        _csvCell(t.updatedAt.toIso8601String()),
        _csvCell(t.deletedAt?.toIso8601String() ?? ''),
      ].join(','));
    }
    return buffer.toString();
  }

  /// Writes [content] as UTF-8 (CSV adds BOM) into [directory] with a
  /// timestamped name. Returns the absolute file path.
  static Future<String> writeExport({
    required String directory,
    required String baseName,
    required String content,
    required bool bom,
  }) async {
    await Directory(directory).create(recursive: true);
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final filePath = p.join(directory, '${baseName}_$stamp.csv');
    final bytes = <int>[
      if (bom) ...utf8Bom,
      ...utf8.encode(content),
    ];
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }

  /// Export everything the database currently holds, all tables.
  static Future<List<String>> exportAll({
    required AppDatabase db,
    required String directory,
  }) async {
    final transactions = await db.select(db.transactions).get();
    final categories = await db.select(db.categories).get();
    final assets = await db.select(db.assets).get();

    final csvContent = transactionsCsv(transactions);

    final jsonContent = jsonEncode(<String, dynamic>{
      'version': db.schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'transactions': [
        for (final t in transactions)
          <String, dynamic>{
            'id': t.id,
            'amount_cents': t.amountCents,
            'type': t.type.name,
            'category_id': t.categoryId,
            'merchant': t.merchant,
            'note': t.note,
            'occurred_at': t.occurredAt.toIso8601String(),
            'is_draft': t.isDraft,
            'source': t.source.name,
            'created_at': t.createdAt.toIso8601String(),
            'updated_at': t.updatedAt.toIso8601String(),
            'deleted_at': t.deletedAt?.toIso8601String(),
          },
      ],
      'categories': [
        for (final c in categories)
          <String, dynamic>{
            'id': c.id,
            'name': c.name,
            'icon': c.icon,
            'sort': c.sort,
            'is_custom': c.isCustom,
            'created_at': c.createdAt.toIso8601String(),
            'updated_at': c.updatedAt.toIso8601String(),
            'deleted_at': c.deletedAt?.toIso8601String(),
          },
      ],
      'assets': [
        for (final a in assets)
          <String, dynamic>{
            'id': a.id,
            'name': a.name,
            'category': a.category.name,
            'value_cents': a.valueCents,
            'purchased_at': a.purchasedAt.toIso8601String(),
            'photo_path': a.photoPath,
            'status': a.status.name,
            'sold_price_cents': a.soldPriceCents,
            'sold_at': a.soldAt?.toIso8601String(),
            'created_at': a.createdAt.toIso8601String(),
            'updated_at': a.updatedAt.toIso8601String(),
            'deleted_at': a.deletedAt?.toIso8601String(),
          },
      ],
    });

    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    await Directory(directory).create(recursive: true);

    final csvPath = p.join(directory, 'gringotts_transactions_$stamp.csv');
    await File(csvPath).writeAsBytes(
      <int>[...utf8Bom, ...utf8.encode(csvContent)],
      flush: true,
    );

    final jsonPath = p.join(directory, 'gringotts_full_$stamp.json');
    await File(jsonPath).writeAsBytes(utf8.encode(jsonContent), flush: true);

    return [csvPath, jsonPath];
  }
}
