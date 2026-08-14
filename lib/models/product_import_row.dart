import 'dart:typed_data';

enum ProductImportAction { add, update, skip }

class ProductImportRow {
  ProductImportRow({
    required this.rowNumber,
    required this.sku,
    required this.productName,
    this.category,
    this.subcategory,
    this.productClass,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minimumStock,
    required this.maximumStock,
    required this.active,
    this.pictureFileName,
    this.pictureBytes,
    this.importRemarks,
    this.action = ProductImportAction.add,
    List<String>? warnings,
    List<String>? errors,
  }) : warnings = warnings ?? <String>[],
       errors = errors ?? <String>[];

  final int rowNumber;

  final String sku;
  final String productName;

  final String? category;
  final String? subcategory;
  final String? productClass;
  final String? barcode;

  final double costPrice;
  final double sellingPrice;

  final int currentStock;
  final int minimumStock;
  final int maximumStock;

  final bool active;

  final String? pictureFileName;
  Uint8List? pictureBytes;

  final String? importRemarks;

  ProductImportAction action;

  final List<String> warnings;
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasPicture => pictureBytes != null && pictureBytes!.isNotEmpty;

  bool get shouldImport => isValid && action != ProductImportAction.skip;

  String get normalizedSku {
    return sku.trim().toUpperCase();
  }

  String? get normalizedBarcode {
    final value = barcode?.trim() ?? '';

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  String? get normalizedPictureFileName {
    final value = pictureFileName?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value.toLowerCase();
  }

  double get grossMargin {
    return sellingPrice - costPrice;
  }

  double get grossMarginPercentage {
    if (sellingPrice <= 0) {
      return 0;
    }

    return (grossMargin / sellingPrice) * 100;
  }

  String get stockStatus {
    if (currentStock == 0) {
      return 'Out of Stock';
    }

    if (currentStock <= minimumStock) {
      return 'Low Stock';
    }

    if (currentStock > maximumStock) {
      return 'Over Maximum';
    }

    return 'Normal';
  }

  void addWarning(String warning) {
    final value = warning.trim();

    if (value.isNotEmpty && !warnings.contains(value)) {
      warnings.add(value);
    }
  }

  void addError(String error) {
    final value = error.trim();

    if (value.isNotEmpty && !errors.contains(value)) {
      errors.add(value);
    }
  }
}
