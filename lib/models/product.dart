class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.beginningStock,
    required this.currentStock,
    this.minimumStock = 0,
    this.maximumStock = 0,
    this.category,
    this.subcategory,
    this.productClass,
    required this.active,
    this.localPhotoPath,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = ProductSyncStatus.pending,
    this.syncError,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final double costPrice;
  final double sellingPrice;
  final int beginningStock;
  final int currentStock;
  final int minimumStock;
  final int maximumStock;
  final String? category;
  final String? subcategory;
  final String? productClass;
  final bool active;

  /// Device-only file path. Never upload this field to Firebase.
  final String? localPhotoPath;

  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final String? syncError;
  final bool isDeleted;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    bool clearBarcode = false,
    double? costPrice,
    double? sellingPrice,
    int? beginningStock,
    int? currentStock,
    int? minimumStock,
    int? maximumStock,
    String? category,
    bool clearCategory = false,
    String? subcategory,
    bool clearSubcategory = false,
    String? productClass,
    bool clearProductClass = false,
    bool? active,
    String? localPhotoPath,
    bool clearLocalPhotoPath = false,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    String? syncError,
    bool clearSyncError = false,
    bool? isDeleted,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: clearBarcode ? null : barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      beginningStock: beginningStock ?? this.beginningStock,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      category: clearCategory ? null : category ?? this.category,
      subcategory: clearSubcategory ? null : subcategory ?? this.subcategory,
      productClass: clearProductClass
          ? null
          : productClass ?? this.productClass,
      active: active ?? this.active,
      localPhotoPath: clearLocalPhotoPath
          ? null
          : localPhotoPath ?? this.localPhotoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// SQLite row to Product.
  factory Product.fromSqlite(Map<String, Object?> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      barcode: _nullableText(map['barcode']),
      costPrice: _toDouble(map['cost_price']),
      sellingPrice: _toDouble(map['selling_price']),
      beginningStock: _toInt(map['beginning_stock']),
      currentStock: _toInt(map['current_stock']),
      minimumStock: _toInt(map['minimum_stock']),
      maximumStock: _toInt(map['maximum_stock']),
      category: _nullableText(map['category']),
      subcategory: _nullableText(map['subcategory']),
      productClass: _nullableText(map['product_class']),
      active: _toInt(map['active']) == 1,
      localPhotoPath: _nullableText(map['local_photo_path']),
      createdAt: _toInt(map['created_at']),
      updatedAt: _toInt(map['updated_at']),
      syncStatus: map['sync_status']?.toString() ?? ProductSyncStatus.pending,
      syncError: _nullableText(map['sync_error']),
      isDeleted: _toInt(map['is_deleted']) == 1,
    );
  }

  /// Product to SQLite row. Includes local and synchronization fields.
  Map<String, Object?> toSqlite() {
    return {
      'id': id,
      'name': name.trim(),
      'sku': sku.trim().toUpperCase(),
      'barcode': _normalizedBarcode(barcode),
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'beginning_stock': beginningStock,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'category': _normalizedText(category),
      'subcategory': _normalizedText(subcategory),
      'product_class': _normalizedText(productClass),
      'active': active ? 1 : 0,
      'local_photo_path': localPhotoPath,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
      'sync_error': syncError,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Firebase map to Product.
  ///
  /// Device-only fields such as localPhotoPath are accepted separately
  /// and never read from Firebase.
  factory Product.fromFirebase({
    required String id,
    required Map<Object?, Object?> map,
    String? localPhotoPath,
  }) {
    final beginningStock = _toInt(map['beginningStock']);

    return Product(
      id: id,
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      barcode: _nullableText(map['barcode']),
      costPrice: _toDouble(map['costPrice']),
      sellingPrice: _toDouble(map['sellingPrice']),
      beginningStock: beginningStock,
      currentStock: map.containsKey('currentStock')
          ? _toInt(map['currentStock'])
          : beginningStock,
      minimumStock: _toInt(map['minimumStock']),
      maximumStock: _toInt(map['maximumStock']),
      category: _nullableText(map['category']),
      subcategory: _nullableText(map['subcategory']),
      productClass: _nullableText(map['productClass']),
      active: map['active'] as bool? ?? true,
      localPhotoPath: localPhotoPath,
      createdAt: _toInt(map['createdAt']),
      updatedAt: _toInt(map['updatedAt']),
      syncStatus: ProductSyncStatus.synced,
      syncError: null,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  /// Product to Firebase.
  ///
  /// Deliberately excludes:
  /// localPhotoPath, syncStatus, and syncError.
  Map<String, Object?> toFirebase() {
    return {
      'name': name.trim(),
      'sku': sku.trim().toUpperCase(),
      'barcode': _normalizedBarcode(barcode),
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'beginningStock': beginningStock,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'maximumStock': maximumStock,
      'category': _normalizedText(category),
      'subcategory': _normalizedText(subcategory),
      'productClass': _normalizedText(productClass),
      'active': active,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  static String? _normalizedText(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static String? _normalizedBarcode(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ProductSyncStatus {
  const ProductSyncStatus._();

  static const String pending = 'pending';
  static const String syncing = 'syncing';
  static const String synced = 'synced';
  static const String failed = 'failed';
}
