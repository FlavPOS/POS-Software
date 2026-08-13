class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.beginningStock,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });
  final String id, name, sku;
  final String? barcode;
  final double costPrice, sellingPrice;
  final int beginningStock;
  final bool active;
  final int? createdAt, updatedAt;

  factory Product.fromMap(String id, Map<Object?, Object?> map) => Product(
    id: id,
    name: (map['name'] ?? '').toString(),
    sku: (map['sku'] ?? '').toString(),
    barcode: (map['barcode']?.toString().trim().isEmpty ?? true)
        ? null
        : map['barcode'].toString(),
    costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0,
    sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0,
    beginningStock: (map['beginningStock'] as num?)?.toInt() ?? 0,
    active: map['active'] as bool? ?? true,
    createdAt: (map['createdAt'] as num?)?.toInt(),
    updatedAt: (map['updatedAt'] as num?)?.toInt(),
  );
}
