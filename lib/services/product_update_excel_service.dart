import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_update.dart';
import '../models/product_update_package.dart';
import '../repositories/product_repository.dart';
import 'product_service.dart';
import 'product_update_schema.dart';

class ProductUpdateExcelException implements Exception {
  const ProductUpdateExcelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductUpdateExcelService {
  ProductUpdateExcelService._();

  static final ProductUpdateExcelService instance =
      ProductUpdateExcelService._();

  final ProductService _productService = ProductService();

  final ProductRepository _repository = ProductRepository.instance;

  Future<ProductUpdateParseResult> parse(ProductUpdatePackage package) async {
    final Excel workbook;

    try {
      workbook = Excel.decodeBytes(package.workbookBytes);
    } catch (error) {
      throw ProductUpdateExcelException(
        'Unable to read Product_Update.xlsx: '
        '$error',
      );
    }

    final sheet = workbook.tables[ProductUpdateSchema.updatesSheet];

    if (sheet == null) {
      throw const ProductUpdateExcelException(
        'The workbook must contain a '
        '"Product Updates" sheet.',
      );
    }

    if (sheet.rows.isEmpty) {
      throw const ProductUpdateExcelException(
        'The Product Updates sheet is empty.',
      );
    }

    final headerMap = _buildHeaderMap(sheet.rows.first);

    _validateHeaders(headerMap);

    final products = await _loadProducts();

    final productsBySku = <String, Product>{
      for (final product in products)
        if (!product.isDeleted) product.sku.trim().toUpperCase(): product,
    };

    final rows = <ProductUpdateRow>[];

    for (var index = 1; index < sheet.rows.length; index++) {
      final excelRow = sheet.rows[index];

      if (_isBlankRow(excelRow, headerMap)) {
        continue;
      }

      final row = _parseRow(
        excelRow: excelRow,
        excelRowNumber: index + 1,
        headerMap: headerMap,
        package: package,
      );

      rows.add(row);
    }

    if (rows.isEmpty) {
      throw const ProductUpdateExcelException(
        'No entered Product Update rows '
        'were found. Enter at least one SKU.',
      );
    }

    _markDuplicateSkus(rows);

    for (final row in rows) {
      if (row.status == ProductUpdateRowStatus.duplicateSku) {
        continue;
      }

      final product = productsBySku[row.normalizedSku];

      if (product == null) {
        row.status = ProductUpdateRowStatus.unmatched;

        row.addError(
          'No existing product was found '
          'for SKU ${row.normalizedSku}.',
        );

        continue;
      }

      row.existingProduct = product;

      _validateRow(row: row, allProducts: products);

      _buildChanges(row);

      if (row.hasErrors) {
        if (row.status != ProductUpdateRowStatus.duplicateBarcode) {
          row.status = ProductUpdateRowStatus.invalid;
        }
      } else if (!row.hasChanges) {
        row.status = ProductUpdateRowStatus.noChange;
      } else {
        row.status = ProductUpdateRowStatus.ready;
      }
    }

    return ProductUpdateParseResult(
      sourceFileName: package.sourceFileName,
      rows: List<ProductUpdateRow>.unmodifiable(rows),
      packageWarnings: List<String>.unmodifiable(package.warnings),
    );
  }

  Future<List<Product>> _loadProducts() async {
    return kIsWeb
        ? _productService.getProducts()
        : _repository.getProducts(includeDeleted: false);
  }

  ProductUpdateRow _parseRow({
    required List<Data?> excelRow,
    required int excelRowNumber,
    required Map<String, int> headerMap,
    required ProductUpdatePackage package,
  }) {
    final sku = _value(excelRow, headerMap, ProductUpdateSchema.sku);

    final productName = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.productName,
    );

    final category = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.category,
    );

    final subcategory = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.subcategory,
    );

    final productClass = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.productClass,
    );

    final barcode = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.barcode,
    );

    final costText = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.costPrice,
    );

    final sellingText = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.sellingPrice,
    );

    final minimumText = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.minimumStock,
    );

    final maximumText = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.maximumStock,
    );

    final activeText = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.active,
    );

    final pictureFileName = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.pictureFileName,
    );

    final updateRemarks = _optionalValue(
      excelRow,
      headerMap,
      ProductUpdateSchema.updateRemarks,
    );

    final row = ProductUpdateRow(
      excelRowNumber: excelRowNumber,
      sku: sku,
      productName: productName,
      category: category,
      subcategory: subcategory,
      productClass: productClass,
      barcode: barcode,
      costPrice: costText == null ? null : _parseDouble(costText),
      sellingPrice: sellingText == null ? null : _parseDouble(sellingText),
      minimumStock: minimumText == null ? null : _parseInteger(minimumText),
      maximumStock: maximumText == null ? null : _parseInteger(maximumText),
      active: ProductUpdateSchema.parseActive(activeText),
      pictureFileName: pictureFileName,
      updateRemarks: updateRemarks,
      pictureBytes: pictureFileName == null
          ? null
          : package.pictureByFileName(pictureFileName),
    );

    if (row.normalizedSku.isEmpty) {
      row.addError('SKU is required.');
    }

    if (costText != null && !_isValidDouble(costText)) {
      row.addError('Cost Price must be a valid number.');
    }

    if (sellingText != null && !_isValidDouble(sellingText)) {
      row.addError('Selling Price must be a valid number.');
    }

    if (minimumText != null && !_isValidInteger(minimumText)) {
      row.addError('Minimum Stock must be a whole number.');
    }

    if (maximumText != null && !_isValidInteger(maximumText)) {
      row.addError('Maximum Stock must be a whole number.');
    }

    if (activeText != null && row.active == null) {
      row.addError('Active must contain YES or NO.');
    }

    if (pictureFileName != null && row.pictureBytes == null) {
      row.addWarning(
        'Picture file was not found in the '
        'update package: $pictureFileName',
      );
    }

    return row;
  }

  void _validateRow({
    required ProductUpdateRow row,
    required List<Product> allProducts,
  }) {
    final product = row.existingProduct!;

    if (row.costPrice != null && row.costPrice! < 0) {
      row.addError('Cost Price cannot be negative.');
    }

    if (row.sellingPrice != null && row.sellingPrice! < 0) {
      row.addError('Selling Price cannot be negative.');
    }

    if (row.minimumStock != null && row.minimumStock! < 0) {
      row.addError('Minimum Stock cannot be negative.');
    }

    if (row.maximumStock != null && row.maximumStock! < 0) {
      row.addError('Maximum Stock cannot be negative.');
    }

    final resultingMinimum = row.minimumStock ?? product.minimumStock;

    final resultingMaximum = row.maximumStock ?? product.maximumStock;

    if (resultingMinimum > resultingMaximum) {
      row.addError(
        'Minimum Stock cannot exceed '
        'Maximum Stock.',
      );
    }

    final proposedBarcode = row.normalizedBarcode;

    if (proposedBarcode != null && proposedBarcode != product.barcode?.trim()) {
      final duplicate = allProducts.any((other) {
        return other.id != product.id &&
            !other.isDeleted &&
            other.barcode?.trim() == proposedBarcode;
      });

      if (duplicate) {
        row.status = ProductUpdateRowStatus.duplicateBarcode;

        row.addError(
          'Barcode $proposedBarcode already '
          'belongs to another product.',
        );
      }
    }
  }

  void _buildChanges(ProductUpdateRow row) {
    final product = row.existingProduct!;

    if (row.productName != null) {
      row.addChange(
        fieldName: 'Product Name',
        currentValue: product.name,
        proposedValue: row.productName,
      );
    }

    if (row.category != null) {
      row.addChange(
        fieldName: 'Category',
        currentValue: product.category,
        proposedValue: row.category,
      );
    }

    if (row.subcategory != null) {
      row.addChange(
        fieldName: 'Subcategory',
        currentValue: product.subcategory,
        proposedValue: row.subcategory,
      );
    }

    if (row.productClass != null) {
      row.addChange(
        fieldName: 'Class',
        currentValue: product.productClass,
        proposedValue: row.productClass,
      );
    }

    if (row.barcode != null) {
      row.addChange(
        fieldName: 'Barcode',
        currentValue: product.barcode,
        proposedValue: row.barcode,
      );
    }

    if (row.costPrice != null) {
      row.addChange(
        fieldName: 'Cost Price',
        currentValue: product.costPrice,
        proposedValue: row.costPrice,
      );
    }

    if (row.sellingPrice != null) {
      row.addChange(
        fieldName: 'Selling Price',
        currentValue: product.sellingPrice,
        proposedValue: row.sellingPrice,
      );
    }

    if (row.minimumStock != null) {
      row.addChange(
        fieldName: 'Minimum Stock',
        currentValue: product.minimumStock,
        proposedValue: row.minimumStock,
      );
    }

    if (row.maximumStock != null) {
      row.addChange(
        fieldName: 'Maximum Stock',
        currentValue: product.maximumStock,
        proposedValue: row.maximumStock,
      );
    }

    if (row.active != null) {
      row.addChange(
        fieldName: 'Active',
        currentValue: product.active,
        proposedValue: row.active,
      );
    }

    if (row.hasPictureUpdate) {
      row.addChange(
        fieldName: 'Product Picture',
        currentValue: 'Current saved picture',
        proposedValue: row.pictureFileName,
      );
    }
  }

  void _markDuplicateSkus(List<ProductUpdateRow> rows) {
    final bySku = <String, List<ProductUpdateRow>>{};

    for (final row in rows) {
      if (row.normalizedSku.isEmpty) {
        continue;
      }

      bySku.putIfAbsent(row.normalizedSku, () => <ProductUpdateRow>[]).add(row);
    }

    for (final entry in bySku.entries) {
      if (entry.value.length <= 1) {
        continue;
      }

      for (final row in entry.value) {
        row.status = ProductUpdateRowStatus.duplicateSku;

        row.addError(
          'SKU ${entry.key} appears more '
          'than once in the workbook.',
        );
      }
    }
  }

  Map<String, int> _buildHeaderMap(List<Data?> headerRow) {
    final headerMap = <String, int>{};

    for (var column = 0; column < headerRow.length; column++) {
      final header = _cellText(headerRow[column]);

      if (header.isEmpty) {
        continue;
      }

      if (ProductUpdateSchema.isProtectedHeader(header)) {
        throw ProductUpdateExcelException(
          'Protected inventory or system '
          'column is not allowed: $header',
        );
      }

      final normalized = ProductUpdateSchema.normalizeHeader(header);

      if (headerMap.containsKey(normalized)) {
        throw ProductUpdateExcelException('Duplicate Excel header: $header');
      }

      if (ProductUpdateSchema.isRecognizedHeader(header)) {
        headerMap[normalized] = column;
      }
    }

    return headerMap;
  }

  void _validateHeaders(Map<String, int> headerMap) {
    for (final required in ProductUpdateSchema.requiredHeaders) {
      final normalized = ProductUpdateSchema.normalizeHeader(required);

      if (!headerMap.containsKey(normalized)) {
        throw ProductUpdateExcelException(
          'Required Excel header is missing: '
          '$required',
        );
      }
    }
  }

  bool _isBlankRow(List<Data?> row, Map<String, int> headerMap) {
    for (final header in ProductUpdateSchema.headers) {
      if (_value(row, headerMap, header).isNotEmpty) {
        return false;
      }
    }

    return true;
  }

  String _value(List<Data?> row, Map<String, int> headerMap, String header) {
    final normalized = ProductUpdateSchema.normalizeHeader(header);

    final column = headerMap[normalized];

    if (column == null || column >= row.length) {
      return '';
    }

    return _cellText(row[column]);
  }

  String? _optionalValue(
    List<Data?> row,
    Map<String, int> headerMap,
    String header,
  ) {
    final value = _value(row, headerMap, header);

    return value.isEmpty ? null : value;
  }

  String _cellText(Data? cell) {
    final value = cell?.value;

    return switch (value) {
      null => '',
      TextCellValue() => value.toString().trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'TRUE' : 'FALSE',
      FormulaCellValue() => value.formula.trim(),
      _ => value.toString().trim(),
    };
  }

  double _parseDouble(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }

  int _parseInteger(String value) {
    final normalized = value.replaceAll(',', '').trim();

    final integer = int.tryParse(normalized);

    if (integer != null) {
      return integer;
    }

    final decimal = double.tryParse(normalized);

    if (decimal != null && decimal == decimal.roundToDouble()) {
      return decimal.toInt();
    }

    return 0;
  }

  bool _isValidDouble(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) != null;
  }

  bool _isValidInteger(String value) {
    final normalized = value.replaceAll(',', '').trim();

    if (int.tryParse(normalized) != null) {
      return true;
    }

    final decimal = double.tryParse(normalized);

    return decimal != null && decimal == decimal.roundToDouble();
  }
}
