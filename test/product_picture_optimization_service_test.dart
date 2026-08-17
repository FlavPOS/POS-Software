import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:simple_pos/services/product_picture_optimization_service.dart';

Uint8List createPicture({
  required int width,
  required int height,
  int red = 40,
  int green = 120,
  int blue = 220,
}) {
  final image = img.Image(width: width, height: height);

  img.fill(image, color: img.ColorRgb8(red, green, blue));

  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  final service = ProductPictureOptimizationService.instance;

  group('ProductPictureOptimizationService', () {
    test('optimizes landscape picture to master size', () {
      final source = createPicture(width: 1200, height: 800);

      final result = service.optimizeMaster(
        sourceBytes: source,
        sku: '12345617',
      );

      expect(result.fileName, '12345617.jpg');

      expect(result.mimeType, 'image/jpeg');

      expect(result.optimizedWidth, 600);

      expect(result.optimizedHeight, 600);

      expect(result.isMasterSize, isTrue);

      expect(result.jpegQuality, 80);

      expect(result.isWithinOneMegabyte, isTrue);
    });

    test('optimizes portrait picture to square master', () {
      final source = createPicture(width: 600, height: 1200);

      final result = service.optimizeMaster(
        sourceBytes: source,
        sku: 'PORTRAIT-001',
      );

      expect(result.originalWidth, 600);

      expect(result.originalHeight, 1200);

      expect(result.optimizedDimensionsLabel, '600 × 600');
    });

    test('optimizes square picture to master size', () {
      final source = createPicture(width: 900, height: 900);

      final result = service.optimizeMaster(
        sourceBytes: source,
        sku: 'SQUARE-001',
      );

      expect(result.isSquare, isTrue);

      expect(result.isMasterSize, isTrue);
    });

    test('creates 240 by 240 thumbnail', () {
      final source = createPicture(width: 1000, height: 700);

      final result = service.optimizeThumbnail(
        sourceBytes: source,
        sku: 'THUMB-001',
      );

      expect(result.fileName, 'THUMB-001_thumb.jpg');

      expect(result.optimizedWidth, 240);

      expect(result.optimizedHeight, 240);

      expect(result.isThumbnailSize, isTrue);

      expect(result.jpegQuality, 76);
    });

    test('normalizes SKU used for filename', () {
      final source = createPicture(width: 100, height: 100);

      final result = service.optimizeMaster(
        sourceBytes: source,
        sku: '  test/001  ',
      );

      expect(result.fileName, 'TEST_001.jpg');
    });

    test('rejects blank SKU', () {
      final source = createPicture(width: 100, height: 100);

      expect(() {
        service.optimizeMaster(sourceBytes: source, sku: '   ');
      }, throwsA(isA<ProductPictureOptimizationException>()));
    });

    test('rejects empty picture bytes', () {
      expect(() {
        service.optimizeMaster(sourceBytes: Uint8List(0), sku: 'TEST-001');
      }, throwsA(isA<ProductPictureOptimizationException>()));
    });

    test('rejects corrupt picture bytes', () {
      expect(() {
        service.optimizeMaster(
          sourceBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          sku: 'TEST-001',
        );
      }, throwsA(isA<ProductPictureOptimizationException>()));
    });

    test('rejects picture above input limit', () {
      final oversized = Uint8List(
        ProductPictureOptimizationService.maximumInputBytes + 1,
      );

      expect(() {
        service.optimizeMaster(sourceBytes: oversized, sku: 'TEST-001');
      }, throwsA(isA<ProductPictureOptimizationException>()));
    });

    test('rejects invalid target size', () {
      final source = createPicture(width: 100, height: 100);

      expect(() {
        service.optimize(
          sourceBytes: source,
          sku: 'TEST-001',
          targetSize: 0,
          jpegQuality: 80,
        );
      }, throwsA(isA<ProductPictureOptimizationException>()));
    });

    test('rejects invalid JPEG quality', () {
      final source = createPicture(width: 100, height: 100);

      expect(() {
        service.optimize(
          sourceBytes: source,
          sku: 'TEST-001',
          targetSize: 600,
          jpegQuality: 101,
        );
      }, throwsA(isA<ProductPictureOptimizationException>()));
    });

    test('returns readable optimization metadata', () {
      final source = createPicture(width: 1200, height: 800);

      final result = service.optimizeMaster(
        sourceBytes: source,
        sku: 'META-001',
      );

      expect(result.summary, contains('Original:'));

      expect(result.summary, contains('Optimized:'));

      expect(result.summary, contains('600 × 600'));
    });
  });
}
