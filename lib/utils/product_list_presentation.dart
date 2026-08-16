import 'package:flutter/material.dart';

import '../models/product.dart';

enum ProductQuickFilter { all, active, lowStock }

enum ProductStockStatus { inStock, lowStock, outOfStock, inactive }

extension ProductListPresentation on Product {
  ProductStockStatus get stockStatus {
    // Inactive always takes priority over
    // inventory quantity.
    if (!active) {
      return ProductStockStatus.inactive;
    }

    if (currentStock <= 0) {
      return ProductStockStatus.outOfStock;
    }

    if (currentStock <= minimumStock) {
      return ProductStockStatus.lowStock;
    }

    return ProductStockStatus.inStock;
  }

  String get stockStatusLabel {
    switch (stockStatus) {
      case ProductStockStatus.inStock:
        return 'In Stock';

      case ProductStockStatus.lowStock:
        return 'Low Stock';

      case ProductStockStatus.outOfStock:
        return 'Out of Stock';

      case ProductStockStatus.inactive:
        return 'Inactive';
    }
  }

  Color get stockStatusTextColor {
    switch (stockStatus) {
      case ProductStockStatus.inStock:
        return const Color(0xFF15803D);

      case ProductStockStatus.lowStock:
        return const Color(0xFFB45309);

      case ProductStockStatus.outOfStock:
        return const Color(0xFFB91C1C);

      case ProductStockStatus.inactive:
        return const Color(0xFF4B5563);
    }
  }

  Color get stockStatusBackgroundColor {
    switch (stockStatus) {
      case ProductStockStatus.inStock:
        return const Color(0xFFDCFCE7);

      case ProductStockStatus.lowStock:
        return const Color(0xFFFEF3C7);

      case ProductStockStatus.outOfStock:
        return const Color(0xFFFEE2E2);

      case ProductStockStatus.inactive:
        return const Color(0xFFE5E7EB);
    }
  }

  bool get isLowStock {
    return stockStatus == ProductStockStatus.lowStock;
  }

  bool get isOutOfStock {
    return stockStatus == ProductStockStatus.outOfStock;
  }

  bool matchesQuickFilter(ProductQuickFilter filter) {
    switch (filter) {
      case ProductQuickFilter.all:
        return true;

      case ProductQuickFilter.active:
        return active;

      case ProductQuickFilter.lowStock:
        return isLowStock;
    }
  }

  String get classificationPath {
    final values = <String>[
      if (_hasText(category)) category!.trim(),
      if (_hasText(subcategory)) subcategory!.trim(),
      if (_hasText(productClass)) productClass!.trim(),
    ];

    return values.join('  ›  ');
  }

  String get classLabel {
    final value = productClass?.trim();

    if (value == null || value.isEmpty) {
      return '';
    }

    return 'Class: $value';
  }

  String get formattedSellingPrice {
    return '₱${sellingPrice.toStringAsFixed(2)}';
  }

  String get compactSkuLabel {
    final normalized = sku.trim();

    if (normalized.isEmpty) {
      return 'SKU: (missing)';
    }

    return 'SKU: $normalized';
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

extension ProductQuickFilterPresentation on ProductQuickFilter {
  String get label {
    switch (this) {
      case ProductQuickFilter.all:
        return 'All';

      case ProductQuickFilter.active:
        return 'Active';

      case ProductQuickFilter.lowStock:
        return 'Low Stock';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductQuickFilter.all:
        return Icons.inventory_2_outlined;

      case ProductQuickFilter.active:
        return Icons.check_circle_outline;

      case ProductQuickFilter.lowStock:
        return Icons.warning_amber_rounded;
    }
  }
}
