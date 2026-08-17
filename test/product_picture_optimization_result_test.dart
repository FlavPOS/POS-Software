import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/product_picture_optimization_result.dart';

ProductPictureOptimizationResult buildResult({
  int originalBytes = 5 * 1024 * 1024,
  int optimizedBytes = 200 * 1024,
  int originalWidth = 4032,
  int originalHeight = 3024,
  int optimizedWidth = 600,
  int optimizedHeight = 600,
}) {
  return ProductPictureOptimizationResult(
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    fileName: '12345617.jpg',
    mimeType: 'image/jpeg',
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    optimizedWidth: optimizedWidth,
    optimizedHeight: optimizedHeight,
    originalBytes: originalBytes,
    optimizedBytes: optimizedBytes,
    jpegQuality: 80,
  );
}

void main() {
  group('ProductPictureOptimizationResult', () {
    test('stores optimized metadata', () {
      final result = buildResult();

      expect(result.fileName, '12345617.jpg');

      expect(result.mimeType, 'image/jpeg');

      expect(result.jpegQuality, 80);

      expect(result.isNotEmpty, isTrue);
    });

    test('recognizes 600 by 600 master output', () {
      final result = buildResult();

      expect(result.isSquare, isTrue);

      expect(result.isMasterSize, isTrue);

      expect(result.longestOptimizedSide, 600);
    });

    test('recognizes 240 by 240 thumbnail output', () {
      final result = buildResult(optimizedWidth: 240, optimizedHeight: 240);

      expect(result.isThumbnailSize, isTrue);

      expect(result.isMasterSize, isFalse);
    });

    test('calculates reduced byte count', () {
      final result = buildResult(originalBytes: 1000, optimizedBytes: 250);

      expect(result.bytesSaved, 750);

      expect(result.wasReduced, isTrue);
    });

    test('calculates reduction percentage', () {
      final result = buildResult(originalBytes: 1000, optimizedBytes: 250);

      expect(result.reductionPercentage, 75);

      expect(result.reductionPercentageLabel, '75.0%');
    });

    test('clamps negative reduction to zero', () {
      final result = buildResult(originalBytes: 500, optimizedBytes: 600);

      expect(result.wasReduced, isFalse);

      expect(result.bytesSaved, 0);

      expect(result.reductionPercentage, 0);
    });

    test('handles zero original bytes safely', () {
      final result = buildResult(originalBytes: 0, optimizedBytes: 0);

      expect(result.sizeRatio, 0);

      expect(result.reductionPercentage, 0);

      expect(result.originalSizeLabel, '0 B');
    });

    test('checks one megabyte limit', () {
      final valid = buildResult(optimizedBytes: 1024 * 1024);

      final invalid = buildResult(optimizedBytes: 1024 * 1024 + 1);

      expect(valid.isWithinOneMegabyte, isTrue);

      expect(invalid.isWithinOneMegabyte, isFalse);
    });

    test('formats dimension labels', () {
      final result = buildResult();

      expect(result.originalDimensionsLabel, '4032 × 3024');

      expect(result.optimizedDimensionsLabel, '600 × 600');
    });

    test('copies input bytes defensively', () {
      final source = Uint8List.fromList(<int>[1, 2, 3]);

      final result = ProductPictureOptimizationResult(
        bytes: source,
        fileName: 'TEST.jpg',
        mimeType: 'image/jpeg',
        originalWidth: 1000,
        originalHeight: 1000,
        optimizedWidth: 600,
        optimizedHeight: 600,
        originalBytes: source.lengthInBytes,
        optimizedBytes: source.lengthInBytes,
        jpegQuality: 80,
      );

      source[0] = 99;

      expect(result.bytes.first, 1);
    });

    test('creates exportable metadata map', () {
      final result = buildResult(originalBytes: 1000, optimizedBytes: 250);

      final map = result.toMap();

      expect(map['fileName'], '12345617.jpg');

      expect(map['bytesSaved'], 750);

      expect(map['reductionPercentage'], 75);
    });
  });
}
