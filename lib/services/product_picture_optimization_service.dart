import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/product_picture_optimization_result.dart';

class ProductPictureOptimizationException implements Exception {
  const ProductPictureOptimizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductPictureOptimizationService {
  ProductPictureOptimizationService._();

  static final ProductPictureOptimizationService instance =
      ProductPictureOptimizationService._();

  static const int maximumInputBytes = 10 * 1024 * 1024;

  static const int maximumOutputBytes = 1 * 1024 * 1024;

  static const int masterSize = 600;
  static const int thumbnailSize = 240;

  static const int masterJpegQuality = 80;
  static const int thumbnailJpegQuality = 76;

  static const String outputMimeType = 'image/jpeg';

  ProductPictureOptimizationResult optimizeMaster({
    required Uint8List sourceBytes,
    required String sku,
  }) {
    return _optimize(
      sourceBytes: sourceBytes,
      sku: sku,
      targetSize: masterSize,
      jpegQuality: masterJpegQuality,
      fileSuffix: '',
    );
  }

  ProductPictureOptimizationResult optimizeThumbnail({
    required Uint8List sourceBytes,
    required String sku,
  }) {
    return _optimize(
      sourceBytes: sourceBytes,
      sku: sku,
      targetSize: thumbnailSize,
      jpegQuality: thumbnailJpegQuality,
      fileSuffix: '_thumb',
    );
  }

  ProductPictureOptimizationResult optimize({
    required Uint8List sourceBytes,
    required String sku,
    required int targetSize,
    required int jpegQuality,
    String fileSuffix = '',
  }) {
    if (targetSize <= 0) {
      throw const ProductPictureOptimizationException(
        'The target picture size must be '
        'greater than zero.',
      );
    }

    if (jpegQuality < 1 || jpegQuality > 100) {
      throw const ProductPictureOptimizationException(
        'JPEG quality must be between '
        '1 and 100.',
      );
    }

    return _optimize(
      sourceBytes: sourceBytes,
      sku: sku,
      targetSize: targetSize,
      jpegQuality: jpegQuality,
      fileSuffix: fileSuffix,
    );
  }

  ProductPictureOptimizationResult _optimize({
    required Uint8List sourceBytes,
    required String sku,
    required int targetSize,
    required int jpegQuality,
    required String fileSuffix,
  }) {
    final normalizedSku = _normalizeSku(sku);

    _validateSource(sourceBytes: sourceBytes, normalizedSku: normalizedSku);

    final img.Image? decoded;

    try {
      decoded = img.decodeImage(sourceBytes);
    } on Object {
      throw const ProductPictureOptimizationException(
        'The selected file is corrupted or '
        'is not a valid supported picture.',
      );
    }

    if (decoded == null) {
      throw const ProductPictureOptimizationException(
        'The selected file is corrupted or '
        'is not a valid supported picture.',
      );
    }

    if (decoded.width <= 0 || decoded.height <= 0) {
      throw const ProductPictureOptimizationException(
        'The selected picture has invalid '
        'dimensions.',
      );
    }

    final originalWidth = decoded.width;
    final originalHeight = decoded.height;

    final oriented = img.bakeOrientation(decoded);

    final resized = img.copyResize(
      oriented,
      width: targetSize,
      height: targetSize,
      maintainAspect: true,
      backgroundColor: img.ColorRgb8(255, 255, 255),
      interpolation: img.Interpolation.average,
    );

    final encoded = Uint8List.fromList(
      img.encodeJpg(resized, quality: jpegQuality),
    );

    if (encoded.isEmpty) {
      throw const ProductPictureOptimizationException(
        'Unable to encode the optimized '
        'product picture.',
      );
    }

    if (encoded.lengthInBytes > maximumOutputBytes) {
      throw ProductPictureOptimizationException(
        'The optimized picture is larger '
        'than the 1 MB output limit. '
        'Generated size: '
        '${_formatBytes(encoded.lengthInBytes)}.',
      );
    }

    final safeSuffix = _safeFileSuffix(fileSuffix);

    return ProductPictureOptimizationResult(
      bytes: encoded,
      fileName: '$normalizedSku$safeSuffix.jpg',
      mimeType: outputMimeType,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      optimizedWidth: resized.width,
      optimizedHeight: resized.height,
      originalBytes: sourceBytes.lengthInBytes,
      optimizedBytes: encoded.lengthInBytes,
      jpegQuality: jpegQuality,
    );
  }

  void _validateSource({
    required Uint8List sourceBytes,
    required String normalizedSku,
  }) {
    if (normalizedSku.isEmpty) {
      throw const ProductPictureOptimizationException(
        'SKU is required before optimizing '
        'the product picture.',
      );
    }

    if (sourceBytes.isEmpty) {
      throw const ProductPictureOptimizationException(
        'The selected product picture is empty.',
      );
    }

    if (sourceBytes.lengthInBytes > maximumInputBytes) {
      throw ProductPictureOptimizationException(
        'The selected picture is larger '
        'than the 10 MB input limit. '
        'Selected size: '
        '${_formatBytes(sourceBytes.lengthInBytes)}.',
      );
    }
  }

  String _normalizeSku(String value) {
    final normalized = value.trim().toUpperCase();

    if (normalized.isEmpty) {
      return '';
    }

    return normalized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _safeFileSuffix(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

    if (safe.startsWith('_')) {
      return safe;
    }

    return '_$safe';
  }

  static String _formatBytes(int value) {
    if (value <= 0) {
      return '0 B';
    }

    if (value < 1024) {
      return '$value B';
    }

    final kilobytes = value / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;

    return '${megabytes.toStringAsFixed(2)} MB';
  }
}
