import 'dart:typed_data';

import 'product.dart';

enum ProductUpdateRowStatus {
  pending,
  ready,
  noChange,
  unmatched,
  duplicateSku,
  duplicateBarcode,
  invalid,
}

enum ProductUpdateSaveStatus { pending, updated, noChange, skipped, failed }

class ProductUpdateFieldChange {
  const ProductUpdateFieldChange({
    required this.fieldName,
    required this.currentValue,
    required this.proposedValue,
  });

  final String fieldName;
  final Object? currentValue;
  final Object? proposedValue;

  bool get hasChange {
    return currentValue != proposedValue;
  }

  String get currentDisplay {
    return _displayValue(currentValue);
  }

  String get proposedDisplay {
    return _displayValue(proposedValue);
  }

  String _displayValue(Object? value) {
    if (value == null) {
      return '(blank)';
    }

    if (value is bool) {
      return value ? 'YES' : 'NO';
    }

    if (value is double) {
      return value.toStringAsFixed(2);
    }

    final text = value.toString().trim();

    return text.isEmpty ? '(blank)' : text;
  }
}

class ProductUpdateRow {
  ProductUpdateRow({
    required this.excelRowNumber,
    required this.sku,
    this.productName,
    this.category,
    this.subcategory,
    this.productClass,
    this.barcode,
    this.costPrice,
    this.sellingPrice,
    this.minimumStock,
    this.maximumStock,
    this.active,
    this.pictureFileName,
    this.updateRemarks,
    this.pictureBytes,
    this.existingProduct,
    this.status = ProductUpdateRowStatus.pending,
    List<ProductUpdateFieldChange>? changes,
    List<String>? errors,
    List<String>? warnings,
    this.saveStatus = ProductUpdateSaveStatus.pending,
    this.saveError,
  }) : changes = changes ?? <ProductUpdateFieldChange>[],
       errors = errors ?? <String>[],
       warnings = warnings ?? <String>[];

  final int excelRowNumber;

  final String sku;

  final String? productName;
  final String? category;
  final String? subcategory;
  final String? productClass;
  final String? barcode;

  final double? costPrice;
  final double? sellingPrice;

  final int? minimumStock;
  final int? maximumStock;

  final bool? active;

  final String? pictureFileName;
  final String? updateRemarks;
  final Uint8List? pictureBytes;

  Product? existingProduct;

  ProductUpdateRowStatus status;

  final List<ProductUpdateFieldChange> changes;
  final List<String> errors;
  final List<String> warnings;

  ProductUpdateSaveStatus saveStatus;
  String? saveError;

  String get normalizedSku {
    return sku.trim().toUpperCase();
  }

  String? get normalizedBarcode {
    final value = barcode?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  bool get hasPictureUpdate {
    return pictureFileName != null &&
        pictureFileName!.trim().isNotEmpty &&
        pictureBytes != null &&
        pictureBytes!.isNotEmpty;
  }

  bool get hasFieldChanges {
    return changes.any((change) => change.hasChange);
  }

  bool get hasChanges {
    return hasFieldChanges || hasPictureUpdate;
  }

  bool get hasErrors {
    return errors.isNotEmpty;
  }

  bool get hasWarnings {
    return warnings.isNotEmpty;
  }

  bool get canUpdate {
    return status == ProductUpdateRowStatus.ready &&
        existingProduct != null &&
        hasChanges &&
        !hasErrors;
  }

  void addChange({
    required String fieldName,
    required Object? currentValue,
    required Object? proposedValue,
  }) {
    final change = ProductUpdateFieldChange(
      fieldName: fieldName,
      currentValue: currentValue,
      proposedValue: proposedValue,
    );

    if (change.hasChange) {
      changes.add(change);
    }
  }

  void addError(String message) {
    if (!errors.contains(message)) {
      errors.add(message);
    }
  }

  void addWarning(String message) {
    if (!warnings.contains(message)) {
      warnings.add(message);
    }
  }

  void markUpdated() {
    saveStatus = ProductUpdateSaveStatus.updated;
    saveError = null;
  }

  void markNoChange() {
    saveStatus = ProductUpdateSaveStatus.noChange;
    saveError = null;
  }

  void markSkipped({String? reason}) {
    saveStatus = ProductUpdateSaveStatus.skipped;
    saveError = reason;
  }

  void markFailed(Object error) {
    saveStatus = ProductUpdateSaveStatus.failed;
    saveError = error.toString();
  }
}

class ProductUpdateParseResult {
  const ProductUpdateParseResult({
    required this.sourceFileName,
    required this.rows,
    required this.packageWarnings,
  });

  final String sourceFileName;
  final List<ProductUpdateRow> rows;
  final List<String> packageWarnings;

  int get rowsFound => rows.length;

  int get ready {
    return rows
        .where((row) => row.status == ProductUpdateRowStatus.ready)
        .length;
  }

  int get noChange {
    return rows
        .where((row) => row.status == ProductUpdateRowStatus.noChange)
        .length;
  }

  int get unmatched {
    return rows
        .where((row) => row.status == ProductUpdateRowStatus.unmatched)
        .length;
  }

  int get duplicateSku {
    return rows
        .where((row) => row.status == ProductUpdateRowStatus.duplicateSku)
        .length;
  }

  int get duplicateBarcode {
    return rows
        .where((row) => row.status == ProductUpdateRowStatus.duplicateBarcode)
        .length;
  }

  int get invalid {
    return rows
        .where((row) => row.status == ProductUpdateRowStatus.invalid)
        .length;
  }

  int get withPictureUpdates {
    return rows.where((row) => row.hasPictureUpdate).length;
  }

  bool get hasReadyRows => ready > 0;

  bool get hasPackageWarnings {
    return packageWarnings.isNotEmpty;
  }

  List<ProductUpdateRow> get readyRows {
    return rows.where((row) => row.canUpdate).toList(growable: false);
  }
}

class ProductUpdateSaveResult {
  const ProductUpdateSaveResult({required this.rows});

  final List<ProductUpdateRow> rows;

  int get rowsFound => rows.length;

  int get updated {
    return rows
        .where((row) => row.saveStatus == ProductUpdateSaveStatus.updated)
        .length;
  }

  int get noChange {
    return rows
        .where((row) => row.saveStatus == ProductUpdateSaveStatus.noChange)
        .length;
  }

  int get skipped {
    return rows
        .where((row) => row.saveStatus == ProductUpdateSaveStatus.skipped)
        .length;
  }

  int get failed {
    return rows
        .where((row) => row.saveStatus == ProductUpdateSaveStatus.failed)
        .length;
  }

  int get picturesUpdated {
    return rows
        .where(
          (row) =>
              row.saveStatus == ProductUpdateSaveStatus.updated &&
              row.hasPictureUpdate,
        )
        .length;
  }

  bool get hasUpdates => updated > 0;

  bool get hasFailures => failed > 0;

  List<ProductUpdateRow> get failedRows {
    return rows
        .where((row) => row.saveStatus == ProductUpdateSaveStatus.failed)
        .toList(growable: false);
  }
}
