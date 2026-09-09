import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/services/photo_service.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gringotts_photo_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Uint8List makePng(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgba8(0, 255, 0, 255));
    return Uint8List.fromList(img.encodePng(image));
  }

  group('PhotoService.saveCompressed (hash naming + downscale)', () {
    test('saves jpg under content-hash name; same content same name', () async {
      final bytes = makePng(800, 600);
      final path1 = await PhotoService.saveCompressed(
        bytes,
        directory: tempDir.path,
      );
      final path2 = await PhotoService.saveCompressed(
        bytes,
        directory: tempDir.path,
      );
      expect(path1, path2, reason: 'content hash must dedupe');
      final file = File(path1);
      expect(file.existsSync(), isTrue);
      expect(path1.endsWith('.jpg'), isTrue);
      // Decoded size preserved (<= max edge).
      final decoded = img.decodeImage(await file.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, 800);
    });

    test('downscales images longer than max edge', () async {
      final bytes = makePng(3200, 2400);
      final path = await PhotoService.saveCompressed(
        bytes,
        directory: tempDir.path,
      );
      final decoded = img.decodeImage(await File(path).readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, PhotoService.maxEdge);
      expect(decoded.height, PhotoService.maxEdge * 2400 ~/ 3200);
    });

    test('throws on non-image bytes', () async {
      expect(
        () => PhotoService.saveCompressed(
          Uint8List.fromList([1, 2, 3, 4]),
          directory: tempDir.path,
        ),
        throwsFormatException,
      );
    });
  });
}
