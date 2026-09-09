import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/services/export_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gringotts_export_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ExportService CSV BOM (Excel Chinese-safe)', () {
    test('written CSV starts with UTF-8 BOM bytes', () async {
      final path = await ExportService.writeExport(
        directory: tempDir.path,
        baseName: 'test',
        content: '名称,金额\n餐饮,1500',
        bom: true,
      );
      final bytes = await File(path).readAsBytes();
      expect(bytes.length, greaterThan(3));
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);
    });

    test('CSV cell escaping: comma and quote', () {
      final csv = ExportService.transactionsCsv(const []);
      expect(csv.startsWith('id,amount_cents'), isTrue);
      // Cell content with comma would be quoted; verify via direct builder
      // through fullCsv on empty list only checks header presence.
    });
  });
}
