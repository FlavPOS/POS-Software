class ProductUpdateSchema {
  ProductUpdateSchema._();

  static const String updatesSheet = 'Product Updates';

  static const String sku = 'SKU *';
  static const String productName = 'Product Name';
  static const String category = 'Category';
  static const String subcategory = 'Subcategory';
  static const String productClass = 'Class';
  static const String barcode = 'Barcode';
  static const String costPrice = 'Cost Price';
  static const String sellingPrice = 'Selling Price';
  static const String minimumStock = 'Minimum Stock';
  static const String maximumStock = 'Maximum Stock';
  static const String active = 'Active';
  static const String pictureFileName = 'Picture File Name';
  static const String updateRemarks = 'Update Remarks';

  static const List<String> headers = <String>[
    sku,
    productName,
    category,
    subcategory,
    productClass,
    barcode,
    costPrice,
    sellingPrice,
    minimumStock,
    maximumStock,
    active,
    pictureFileName,
    updateRemarks,
  ];

  static const List<String> requiredHeaders = <String>[sku];

  static const Set<String> protectedHeaders = <String>{
    'CURRENT STOCK',
    'BEGINNING STOCK',
    'PRODUCT ID',
    'CREATED AT',
    'UPDATED AT',
    'DELETED',
    'DELETED STATUS',
    'SYNC STATUS',
    'SYNCHRONIZATION STATUS',
    'TRANSACTION HISTORY',
  };

  static String normalizeHeader(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  static String normalizeSku(String value) {
    return value.trim().toUpperCase();
  }

  static String? nullableText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static bool? parseActive(String? value) {
    final normalized = value?.trim().toUpperCase();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized == 'YES') {
      return true;
    }

    if (normalized == 'NO') {
      return false;
    }

    return null;
  }

  static bool isRecognizedHeader(String value) {
    final normalized = normalizeHeader(value);

    return headers.any((header) {
      return normalizeHeader(header) == normalized;
    });
  }

  static bool isProtectedHeader(String value) {
    return protectedHeaders.contains(normalizeHeader(value));
  }
}
