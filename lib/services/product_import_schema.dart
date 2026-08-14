class ProductImportSchema {
  ProductImportSchema._();

  static const String productsSheet = 'Products';
  static const String instructionsSheet = 'Instructions';
  static const String validValuesSheet = 'Valid Values';

  static const String sku = 'SKU *';
  static const String productName = 'Product Name *';
  static const String category = 'Category';
  static const String subcategory = 'Subcategory';
  static const String productClass = 'Class';
  static const String barcode = 'Barcode';
  static const String costPrice = 'Cost Price *';
  static const String sellingPrice = 'Selling Price *';
  static const String currentStock = 'Current Stock *';
  static const String minimumStock = 'Minimum Stock *';
  static const String maximumStock = 'Maximum Stock *';
  static const String active = 'Active';
  static const String pictureFileName = 'Picture File Name';
  static const String importRemarks = 'Import Remarks';

  static const List<String> headers = [
    sku,
    productName,
    category,
    subcategory,
    productClass,
    barcode,
    costPrice,
    sellingPrice,
    currentStock,
    minimumStock,
    maximumStock,
    active,
    pictureFileName,
    importRemarks,
  ];

  static const List<String> requiredHeaders = [
    sku,
    productName,
    costPrice,
    sellingPrice,
    currentStock,
    minimumStock,
    maximumStock,
  ];

  static const List<String> supportedImages = ['jpg', 'jpeg', 'png', 'webp'];

  static const List<String> activeValues = ['TRUE', 'FALSE'];

  static const List<String> categories = [
    'Beverages',
    'Food',
    'Health',
    'Beauty',
    'Household',
    'General Merchandise',
  ];

  static const Map<String, List<String>> subcategories = {
    'Beverages': ['Soft Drinks', 'Water', 'Juice', 'Coffee and Tea'],
    'Food': ['Snacks', 'Biscuits', 'Canned Goods'],
    'Health': ['OTC', 'Vitamins', 'First Aid'],
    'Beauty': ['Skin Care', 'Hair Care', 'Personal Care'],
    'Household': ['Cleaning', 'Laundry', 'Kitchen'],
    'General Merchandise': ['Accessories', 'Supplies', 'Others'],
  };

  static String normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('*', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizeFileName(String value) {
    final normalized = value.trim().replaceAll('\\', '/');

    return normalized.split('/').last.toLowerCase();
  }

  static bool isSupportedPicture(String fileName) {
    final normalized = normalizeFileName(fileName);

    if (!normalized.contains('.')) {
      return false;
    }

    final extension = normalized.split('.').last;

    return supportedImages.contains(extension);
  }

  static bool parseActive(Object? value, {bool fallback = true}) {
    if (value == null) {
      return fallback;
    }

    final normalized = value.toString().trim().toUpperCase();

    switch (normalized) {
      case 'TRUE':
      case 'YES':
      case '1':
      case 'ACTIVE':
        return true;

      case 'FALSE':
      case 'NO':
      case '0':
      case 'INACTIVE':
        return false;

      default:
        return fallback;
    }
  }
}
