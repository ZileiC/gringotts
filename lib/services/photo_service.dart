import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Photo pipeline: compress to max dimension + save with content-hash name.
///
/// The DB stores only the returned absolute path (data rule: DB stores path,
/// files live on disk named by content hash).
class PhotoService {
  PhotoService._();

  /// Max edge length after downscale (long edge).
  static const int maxEdge = 1600;
  static const int jpegQuality = 82;

  /// Compresses [bytes] (any decodable image) and writes it under [directory]
  /// named `<sha256>.jpg`. Returns the absolute file path.
  ///
  /// Idempotent: the same content produces the same file name (hash), so a
  /// re-import does not duplicate files.
  static Future<String> saveCompressed(
    Uint8List bytes, {
    required String directory,
  }) async {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      throw const FormatException('unsupported image data');
    }
    if (decoded == null) {
      throw const FormatException('unsupported image data');
    }
    var image = decoded;
    final longest = max(image.width, image.height);
    if (longest > maxEdge) {
      final scale = maxEdge / longest;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }
    if (image.width <= 0 || image.height <= 0) {
      throw const FormatException('unsupported image data');
    }
    final Uint8List encoded;
    try {
      encoded = img.encodeJpg(image, quality: jpegQuality);
    } on Object {
      throw const FormatException('unsupported image data');
    }

    final hash = sha256.convert(encoded).toString();
    await Directory(directory).create(recursive: true);
    final filePath = p.join(directory, '$hash.jpg');
    await File(filePath).writeAsBytes(encoded, flush: true);
    return filePath;
  }
  /// Test-only bridge: raw RGB bytes -> encode -> hash-named file. Keeps the
  /// compression/hash pipeline exercised by integration tests without needing
  /// a real image file on disk.
  static Future<String> saveCompressedBridge(
    List<int> rawRgb, {
    required String directory,
  }) async {
    const side = 64;
    final image = img.Image(width: side, height: side);
    var i = 0;
    for (final y in List<int>.generate(side, (y) => y)) {
      for (final x in List<int>.generate(side, (x) => x)) {
        image.setPixelRgba(
          x,
          y,
          rawRgb[i] & 0xff,
          rawRgb[i + 1] & 0xff,
          rawRgb[i + 2] & 0xff,
          255,
        );
        i += 3;
      }
    }
    final encoded = img.encodeJpg(image, quality: jpegQuality);
    final hash = sha256.convert(encoded).toString();
    await Directory(directory).create(recursive: true);
    final filePath = p.join(directory, '$hash.jpg');
    await File(filePath).writeAsBytes(encoded, flush: true);
    return filePath;
  }}
