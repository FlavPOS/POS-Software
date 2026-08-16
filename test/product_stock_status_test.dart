import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/product.dart';
import 'package:simple_pos/utils/product_list_presentation.dart';

Product buildProduct({
  required bool active,
  required int currentStock,
  required int minimumStock,
}) {
  return Product(
    id: 'test-id',
    name: 'Test Product',
    sku: 'TEST-001',
    costPrice: 50,
    sellingPrice: 75,
    beginningStock: currentStock,
    currentStock: currentStock,
    minimumStock: minimumStock,
    maximumStock: 100,
    active: active,
    createdAt: 1,
    updatedAt: 1,
    syncStatus: ProductSyncStatus.synced,
    isDeleted: false,
  );
}

void main() {
  group('Product stock badge rules', () {
    test('inactive takes priority over available stock', () {
      final product = buildProduct(
        active: false,
        currentStock: 30,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.inactive);

      expect(product.stockStatusLabel, 'Inactive');
    });

    test('inactive takes priority over zero stock', () {
      final product = buildProduct(
        active: false,
        currentStock: 0,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.inactive);
    });

    test('zero stock is out of stock', () {
      final product = buildProduct(
        active: true,
        currentStock: 0,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.outOfStock);
    });

    test('negative stock is out of stock', () {
      final product = buildProduct(
        active: true,
        currentStock: -1,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.outOfStock);
    });

    test('stock below minimum is low stock', () {
      final product = buildProduct(
        active: true,
        currentStock: 5,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.lowStock);
    });

    test('stock equal to minimum is low stock', () {
      final product = buildProduct(
        active: true,
        currentStock: 10,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.lowStock);
    });

    test('stock above minimum is in stock', () {
      final product = buildProduct(
        active: true,
        currentStock: 11,
        minimumStock: 10,
      );

      expect(product.stockStatus, ProductStockStatus.inStock);
    });

    test('low-stock filter excludes out-of-stock product', () {
      final product = buildProduct(
        active: true,
        currentStock: 0,
        minimumStock: 10,
      );

      expect(product.matchesQuickFilter(ProductQuickFilter.lowStock), isFalse);
    });

    test('classification omits empty values', () {
      final product = buildProduct(
        active: true,
        currentStock: 20,
        minimumStock: 10,
      ).copyWith(category: 'Beverages', productClass: 'Premium');

      expect(product.classificationPath, 'Beverages  ›  Premium');
    });
  });
}
