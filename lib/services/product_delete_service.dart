import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_delete_result.dart';
import '../repositories/product_repository.dart';
import 'product_photo_service.dart';
import 'product_service.dart';
import 'product_sync_service.dart';

class ProductDeleteService {
  ProductDeleteService._();

  static final ProductDeleteService instance = ProductDeleteService._();

  final ProductService _productService = ProductService();

  final ProductSyncService _syncService = ProductSyncService.instance;

  final ProductRepository _repository = ProductRepository.instance;

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  Future<ProductDeleteResult> deleteProducts(Iterable<Product> products) async {
    final uniqueProducts = <String, Product>{};

    for (final product in products) {
      uniqueProducts[product.id] = product;
    }

    final results = <ProductDeleteItemResult>[];

    for (final product in uniqueProducts.values) {
      results.add(await _deleteProduct(product));
    }

    return ProductDeleteResult(
      items: List<ProductDeleteItemResult>.unmodifiable(results),
    );
  }

  Future<ProductDeleteItemResult> _deleteProduct(Product product) async {
    try {
      if (kIsWeb) {
        await _productService.delete(product);
      } else {
        final deletedProduct = product.copyWith(
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          syncStatus: ProductSyncStatus.pending,
          clearSyncError: true,
          isDeleted: true,
        );

        await _syncService.saveProduct(deletedProduct);
      }
    } catch (error) {
      return ProductDeleteItemResult(
        product: product,
        status: ProductDeleteStatus.failed,
        message: 'Unable to delete the product: $error',
      );
    }

    var pictureDeleted = false;
    var pictureFailed = false;
    var message = 'Product deleted successfully.';

    try {
      await _photoService.deletePhoto(product.sku);

      pictureDeleted = true;

      if (!kIsWeb) {
        await _repository.updateLocalPhotoPath(
          productId: product.id,
          localPhotoPath: null,
        );
      }
    } catch (error) {
      pictureFailed = true;

      message =
          'Product deleted, but its picture '
          'could not be removed: $error';
    }

    return ProductDeleteItemResult(
      product: product,
      status: ProductDeleteStatus.deleted,
      message: message,
      pictureDeleted: pictureDeleted,
      pictureFailed: pictureFailed,
    );
  }
}
