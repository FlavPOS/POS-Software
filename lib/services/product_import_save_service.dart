import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/product_import_parse_result.dart';
import '../models/product_import_row.dart';
import '../models/product_import_save_result.dart';
import '../models/product_import_summary.dart';
import '../repositories/product_repository.dart';
import 'product_photo_service.dart';
import 'product_picture_optimization_service.dart';
import 'product_service.dart';
import 'product_sync_service.dart';

typedef ProductImportProgressCallback = void Function({
  required int completed,
  required int total,
  String? currentSku,
  String? detail,
});

class ProductImportSaveService {
  ProductImportSaveService._();

  static final ProductImportSaveService instance = ProductImportSaveService._();

  final ProductService _productService = ProductService();

  final ProductSyncService _syncService = ProductSyncService.instance;

  final ProductRepository _repository = ProductRepository.instance;

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  final Uuid _uuid = const Uuid();

  final ProductPictureOptimizationService _pictureOptimizer =
      ProductPictureOptimizationService.instance;

  Future<ProductImportSaveResult> importValidRows(
    ProductImportParseResult result, {
    ProductImportProgressCallback? onProgress,
  }) async {
    final rowResults = <ProductImportRowSaveResult>[];

    final summary = ProductImportSummary(
      totalRows: result.totalRows,
      validRows: result.validRows,
      warningRows: result.warningRows,
      errorRows: result.errorRows,
    );

    final total = result.rows.length;
    var completed = 0;

    onProgress?.call(
      completed: 0,
      total: total,
      detail: 'Starting product import...',
    );

    for (final row in result.rows) {
      onProgress?.call(
        completed: completed,
        total: total,
        currentSku: row.normalizedSku.isEmpty
            ? 'Excel row'
            : 'SKU ${row.normalizedSku}',
        detail: 'Validating product...',
      );
      if (!row.isValid) {
        summary.skipped++;

        rowResults.add(
          ProductImportRowSaveResult(
            row: row,
            status: ProductImportSaveStatus.skipped,
            message:
                'Skipped because the Excel row '
                'contains validation errors.',
            pictureMissing:
                row.normalizedPictureFileName != null && !row.hasPicture,
          ),
        );

        completed += 1;

        onProgress?.call(
          completed: completed,
          total: total,
          currentSku: row.normalizedSku.isEmpty
              ? 'Excel row'
              : 'SKU ${row.normalizedSku}',
          detail: 'Product row skipped.',
        );

        continue;
      }

      final rowResult = await _importRow(row);

      rowResults.add(rowResult);

      switch (rowResult.status) {
        case ProductImportSaveStatus.imported:
          summary.imported++;
          break;

        case ProductImportSaveStatus.skipped:
          summary.skipped++;
          break;

        case ProductImportSaveStatus.failed:
          summary.failed++;
          break;
      }

      if (rowResult.pictureSaved) {
        summary.picturesSaved++;
      }

      if (rowResult.pictureMissing) {
        summary.picturesMissing++;
      }

      if (rowResult.pictureFailed) {
        summary.picturesFailed++;
      }
      completed += 1;

      onProgress?.call(
        completed: completed,
        total: total,
        currentSku: row.normalizedSku.isEmpty
            ? 'Excel row'
            : 'SKU ${row.normalizedSku}',
        detail: 'Product row processed.',
      );
    }

    return ProductImportSaveResult(
      rows: List<ProductImportRowSaveResult>.unmodifiable(rowResults),
      summary: summary,
    );
  }

  Future<ProductImportRowSaveResult> _importRow(ProductImportRow row) async {
    final duplicateMessage = await _findDuplicate(row);

    if (duplicateMessage != null) {
      return ProductImportRowSaveResult(
        row: row,
        status: ProductImportSaveStatus.skipped,
        message: duplicateMessage,
        pictureMissing:
            row.normalizedPictureFileName != null && !row.hasPicture,
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final productId = _uuid.v4();

    final product = Product(
      id: productId,
      name: row.productName.trim(),
      sku: row.normalizedSku,
      barcode: row.normalizedBarcode,
      costPrice: row.costPrice,
      sellingPrice: row.sellingPrice,
      beginningStock: row.currentStock,
      currentStock: row.currentStock,
      minimumStock: row.minimumStock,
      maximumStock: row.maximumStock,
      category: row.category,
      subcategory: row.subcategory,
      productClass: row.productClass,
      active: row.active,
      localPhotoPath: null,
      createdAt: now,
      updatedAt: now,
      syncStatus: ProductSyncStatus.pending,
      syncError: null,
      isDeleted: false,
    );

    try {
      if (kIsWeb) {
        await _saveWebProduct(product);
      } else {
        await _syncService.saveProduct(product);
      }
    } on DuplicateProductException catch (error) {
      return ProductImportRowSaveResult(
        row: row,
        status: ProductImportSaveStatus.skipped,
        message: error.toString(),
      );
    } on DuplicateLocalProductException catch (error) {
      return ProductImportRowSaveResult(
        row: row,
        status: ProductImportSaveStatus.skipped,
        message: error.toString(),
      );
    } catch (error) {
      return ProductImportRowSaveResult(
        row: row,
        status: ProductImportSaveStatus.failed,
        message: 'Unable to save the product: $error',
      );
    }

    final pictureResult = await _savePicture(row: row, product: product);

    return ProductImportRowSaveResult(
      row: row,
      status: ProductImportSaveStatus.imported,
      message: pictureResult.message,
      productId: productId,
      pictureSaved: pictureResult.saved,
      pictureMissing: pictureResult.missing,
      pictureFailed: pictureResult.failed,
    );
  }

  Future<String?> _findDuplicate(ProductImportRow row) async {
    if (kIsWeb) {
      return null;
    }

    final existingSku = await _repository.getProductBySku(row.normalizedSku);

    if (existingSku != null) {
      return 'Skipped because SKU '
          '${row.normalizedSku} already exists.';
    }

    final barcode = row.normalizedBarcode;

    if (barcode != null) {
      final existingBarcode = await _repository.getProductByBarcode(barcode);

      if (existingBarcode != null) {
        return 'Skipped because barcode '
            '$barcode already exists.';
      }
    }

    return null;
  }

  Future<void> _saveWebProduct(Product product) async {
    await _productService.save(
      id: null,
      name: product.name,
      sku: product.sku,
      barcode: product.barcode,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      beginningStock: product.beginningStock,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
      maximumStock: product.maximumStock,
      category: product.category,
      subcategory: product.subcategory,
      productClass: product.productClass,
      active: product.active,
      oldSku: null,
      oldBarcode: null,
    );
  }

  Future<_PictureSaveResult> _savePicture({
    required ProductImportRow row,
    required Product product,
  }) async {
    if (!row.hasPicture) {
      return _PictureSaveResult(
        message: 'Product imported without a picture.',
        missing: row.normalizedPictureFileName != null,
      );
    }

    try {
      final optimized = _pictureOptimizer.optimizeMaster(
        sourceBytes: row.pictureBytes!,
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

      return const _PictureSaveResult(
        message: 'Product and picture imported successfully.',
        saved: true,
      );
    } catch (error) {
      return _PictureSaveResult(
        message:
            'Product imported, but its picture '
            'could not be saved: $error',
        failed: true,
      );
    }
  }
}

class _PictureSaveResult {
  const _PictureSaveResult({
    required this.message,
    this.saved = false,
    this.missing = false,
    this.failed = false,
  });

  final String message;
  final bool saved;
  final bool missing;
  final bool failed;
}
