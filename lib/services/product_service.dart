import 'package:firebase_database/firebase_database.dart';

import '../models/product.dart';

class DuplicateProductException implements Exception {
  const DuplicateProductException(this.field);
  final String field;
  @override
  String toString() => 'Duplicate $field';
}

class ProductService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  DatabaseReference get _products => _db.ref('products');
  DatabaseReference get _skuIndex => _db.ref('productSkuIndex');
  DatabaseReference get _barcodeIndex => _db.ref('productBarcodeIndex');
  DatabaseReference get connectedRef => _db.ref('.info/connected');

  Stream<List<Product>> watchProducts() {
    return _products.onValue.map((event) {
      final raw = event.snapshot.value;

      if (raw is! Map) {
        return <Product>[];
      }

      final products = raw.entries
          .where((entry) => entry.value is Map)
          .map<Product>(
            (entry) => Product.fromFirebase(
              id: entry.key.toString(),
              map: Map<Object?, Object?>.from(entry.value as Map),
            ),
          )
          .toList();

      products.sort((first, second) {
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });

      return products;
    });
  }

  Future<void> save({
    String? id,
    required String name,
    required String sku,
    String? barcode,
    required double costPrice,
    required double sellingPrice,
    required int beginningStock,
    int? currentStock,
    int minimumStock = 0,
    int maximumStock = 0,
    String? category,
    String? subcategory,
    String? productClass,
    required bool active,
    required String? oldSku,
    required String? oldBarcode,
  }) async {
    final productId = id ?? _products.push().key!;
    final normalizedSku = sku.trim().toUpperCase();
    final normalizedBarcode = barcode?.trim() ?? '';
    await _claim(_skuIndex.child(normalizedSku), productId, 'SKU');
    try {
      if (normalizedBarcode.isNotEmpty) {
        await _claim(
          _barcodeIndex.child(normalizedBarcode),
          productId,
          'barcode',
        );
      }
    } catch (_) {
      if (id == null || oldSku != normalizedSku) {
        await _skuIndex.child(normalizedSku).remove();
      }
      rethrow;
    }

    final updates = <String, Object?>{
      'products/$productId/name': name.trim(),
      'products/$productId/sku': normalizedSku,
      'products/$productId/barcode': normalizedBarcode.isEmpty
          ? null
          : normalizedBarcode,
      'products/$productId/costPrice': costPrice,
      'products/$productId/sellingPrice': sellingPrice,
      'products/$productId/beginningStock': beginningStock,
      'products/$productId/currentStock': currentStock ?? beginningStock,
      'products/$productId/minimumStock': minimumStock,
      'products/$productId/maximumStock': maximumStock,
      'products/$productId/category': category,
      'products/$productId/subcategory': subcategory,
      'products/$productId/productClass': productClass,
      'products/$productId/active': active,
      'products/$productId/updatedAt': ServerValue.timestamp,
      'productSkuIndex/$normalizedSku': productId,
    };
    if (id == null) {
      updates['products/$productId/createdAt'] = ServerValue.timestamp;
    }
    if (normalizedBarcode.isNotEmpty) {
      updates['productBarcodeIndex/$normalizedBarcode'] = productId;
    }
    if (oldSku != null && oldSku.isNotEmpty && oldSku != normalizedSku) {
      updates['productSkuIndex/$oldSku'] = null;
    }
    if (oldBarcode != null &&
        oldBarcode.isNotEmpty &&
        oldBarcode != normalizedBarcode) {
      updates['productBarcodeIndex/$oldBarcode'] = null;
    }
    await _db.ref().update(updates);
  }

  Future<void> delete(Product product) async {
    final normalizedSku = product.sku.trim().toUpperCase();

    final normalizedBarcode = product.barcode?.trim() ?? '';

    final updates = <String, Object?>{
      'products/${product.id}': null,
      if (normalizedSku.isNotEmpty) 'productSkuIndex/$normalizedSku': null,
      if (normalizedBarcode.isNotEmpty)
        'productBarcodeIndex/$normalizedBarcode': null,
    };

    await _db.ref().update(updates);
  }

  Future<void> _claim(DatabaseReference ref, String id, String field) async {
    final result = await ref.runTransaction((current) {
      if (current == null || current == id) return Transaction.success(id);
      return Transaction.abort();
    });
    if (!result.committed) throw DuplicateProductException(field);
  }
}
