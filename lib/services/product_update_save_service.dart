import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_update.dart';
import '../repositories/product_repository.dart';
import 'product_photo_service.dart';
import 'product_picture_optimization_service.dart';
import 'product_service.dart';

class ProductUpdateSaveService {
  ProductUpdateSaveService._();

  static final ProductUpdateSaveService instance = ProductUpdateSaveService._();

  final ProductService _productService = ProductService();

  final ProductRepository _repository = ProductRepository.instance;

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  final ProductPictureOptimizationService _pictureOptimizer =
      ProductPictureOptimizationService.instance;

  Future<ProductUpdateSaveResult> saveReadyRows(
    ProductUpdateParseResult result,
  ) async {
    for (final row in result.rows) {
      if (row.status == ProductUpdateRowStatus.noChange) {
        row.markNoChange();
        continue;
      }

      if (!row.canUpdate) {
        row.markSkipped(
          reason: row.errors.isNotEmpty
              ? row.errors.join(' ')
              : 'The product update row is not '
                    'eligible for saving.',
        );

        continue;
      }

      await _saveOne(row);
    }

    return ProductUpdateSaveResult(
      rows: List<ProductUpdateRow>.unmodifiable(result.rows),
    );
  }

  Future<void> _saveOne(ProductUpdateRow row) async {
    final existing = row.existingProduct;

    if (existing == null) {
      row.markSkipped(reason: 'The existing product was not found.');
      return;
    }

    try {
      final updated = _buildUpdatedProduct(existing: existing, row: row);

      if (kIsWeb) {
        await _saveWebProduct(existing: existing, updated: updated);
      } else {
        await _repository.saveLocal(updated);
      }

      if (row.hasPictureUpdate) {
        await _savePicture(row: row, product: updated);
      }

      row.existingProduct = updated;
      row.markUpdated();
    } catch (error) {
      row.markFailed(error);
    }
  }

  Product _buildUpdatedProduct({
    required Product existing,
    required ProductUpdateRow row,
  }) {
    return existing.copyWith(
      name: row.productName,
      category: row.category,
      subcategory: row.subcategory,
      productClass: row.productClass,
      barcode: row.barcode,
      costPrice: row.costPrice,
      sellingPrice: row.sellingPrice,
      minimumStock: row.minimumStock,
      maximumStock: row.maximumStock,
      active: row.active,

      // Protected values remain unchanged.
      id: existing.id,
      sku: existing.sku,
      beginningStock: existing.beginningStock,
      currentStock: existing.currentStock,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: kIsWeb ? existing.syncStatus : ProductSyncStatus.pending,
      clearSyncError: !kIsWeb,
      isDeleted: existing.isDeleted,
    );
  }

  Future<void> _saveWebProduct({
    required Product existing,
    required Product updated,
  }) async {
    await _productService.save(
      id: existing.id,
      name: updated.name,

      // SKU is immutable in Product Updates.
      sku: existing.sku,

      barcode: updated.barcode,
      costPrice: updated.costPrice,
      sellingPrice: updated.sellingPrice,

      // Inventory quantities are preserved.
      beginningStock: existing.beginningStock,
      currentStock: existing.currentStock,

      minimumStock: updated.minimumStock,
      maximumStock: updated.maximumStock,
      category: updated.category,
      subcategory: updated.subcategory,
      productClass: updated.productClass,
      active: updated.active,
      oldSku: existing.sku,
      oldBarcode: existing.barcode,
    );
  }

  Future<void> _savePicture({
    required ProductUpdateRow row,
    required Product product,
  }) async {
    final pictureBytes = row.pictureBytes;
    final pictureFileName = row.pictureFileName;

    if (pictureBytes == null ||
        pictureBytes.isEmpty ||
        pictureFileName == null ||
        pictureFileName.trim().isEmpty) {
      return;
    }

    final optimized = _pictureOptimizer.optimizeMaster(
      sourceBytes: pictureBytes,
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
  }
}
