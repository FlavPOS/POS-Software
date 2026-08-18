import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../models/product_picture_update.dart';
import '../repositories/product_repository.dart';
import 'product_photo_service.dart';
import 'product_picture_optimization_service.dart';

typedef ProductPictureUpdateProgressCallback = void Function({
  required int completed,
  required int total,
  String? currentSku,
  String? detail,
});

class ProductPictureUpdateSaveService {
  ProductPictureUpdateSaveService._();

  static final ProductPictureUpdateSaveService instance =
      ProductPictureUpdateSaveService._();

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  final ProductRepository _repository = ProductRepository.instance;

  final ProductPictureOptimizationService _pictureOptimizer =
      ProductPictureOptimizationService.instance;

  Future<ProductPictureUpdateResult> updateMatchedPictures(
    ProductPictureUpdatePackage package, {
    ProductPictureUpdateProgressCallback? onProgress,
  }) async {
    final total = package.items.length;
    var completed = 0;

    onProgress?.call(
      completed: 0,
      total: total,
      detail: 'Preparing product pictures...',
    );

    for (final item in package.items) {
      final currentSku = item.normalizedSku.isEmpty
          ? '(missing SKU)'
          : 'SKU ${item.normalizedSku}';

      onProgress?.call(
        completed: completed,
        total: total,
        currentSku: currentSku,
        detail: item.isMatched
            ? 'Resizing and saving '
                  'optimized picture...'
            : 'Reviewing picture status...',
      );

      if (!item.canUpdate) {
        item.markSkipped(
          reason:
              item.message ??
              'The picture is not eligible '
                  'for updating.',
        );
      } else {
        await _updateOne(item);
      }

      completed += 1;

      onProgress?.call(
        completed: completed,
        total: total,
        currentSku: currentSku,
        detail: item.saveStatus == ProductPictureSaveStatus.updated
            ? 'Optimized picture updated.'
            : item.saveStatus == ProductPictureSaveStatus.failed
            ? 'Picture processing failed.'
            : 'Picture skipped.',
      );

      await Future<void>.delayed(Duration.zero);
    }

    return ProductPictureUpdateResult(
      items: List<ProductPictureUpdateItem>.unmodifiable(package.items),
    );
  }

  Future<void> _updateOne(ProductPictureUpdateItem item) async {
    final product = item.product;

    if (product == null) {
      item.markSkipped(reason: 'No matching product was found.');

      return;
    }

    try {
      final optimized = _pictureOptimizer.optimizeMaster(
        sourceBytes: item.bytes,
        sku: product.sku,
      );

      final selectedPhoto = XFile.fromData(
        optimized.bytes,
        name: optimized.fileName,
        mimeType: optimized.mimeType,
      );

      final savedPath = await _photoService.savePhoto(
        sku: product.sku,
        selectedPhoto: selectedPhoto,
      );

      if (!kIsWeb) {
        await _repository.updateLocalPhotoPath(
          productId: product.id,
          localPhotoPath: savedPath,
        );
      }

      item.markUpdated();
    } catch (error) {
      item.markFailed(error);
    }
  }
}
