import 'package:excel/excel.dart';

import '../models/product_import_package.dart';
import '../models/product_import_parse_result.dart';
import '../models/product_import_row.dart';
import 'product_import_schema.dart';

class ProductImportExcelException implements Exception {
  const ProductImportExcelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductImportExcelService {
  ProductImportExcelService._();

  static final ProductImportExcelService instance =
      ProductImportExcelService._();

  ProductImportParseResult parse(ProductImportPackage importPackage) {
    final Excel workbook;

    try {
      workbook = Excel.decodeBytes(importPackage.workbookBytes);
    } catch (error) {
      throw ProductImportExcelException(
        'Unable to read the Excel workbook: $error',
      );
    }

    final sheet = workbook.tables[ProductImportSchema.productsSheet];

    if (sheet == null) {
      throw const ProductImportExcelException(
        'The workbook must contain a Products sheet.',
      );
    }

    if (sheet.rows.isEmpty) {
      throw const ProductImportExcelException('The Products sheet is empty.');
    }

    final headerMap = _createHeaderMap(sheet.rows.first);

    _validateRequiredHeaders(headerMap);

    final rows = <ProductImportRow>[];
    final workbookWarnings = <String>[];

    final seenSkus = <String>{};
    final seenBarcodes = <String>{};

    for (var index = 1; index < sheet.rows.length; index++) {
      final excelRow = sheet.rows[index];

      if (_isBlankRow(excelRow)) {
        continue;
      }

      final row = _parseRow(
        excelRow: excelRow,
        excelRowNumber: index + 1,
        headerMap: headerMap,
        importPackage: importPackage,
      );

      final normalizedSku = row.normalizedSku;

      if (normalizedSku.isNotEmpty && !seenSkus.add(normalizedSku)) {
        row.addError('Duplicate SKU inside the workbook.');
      }

      final normalizedBarcode = row.normalizedBarcode;

      if (normalizedBarcode != null && !seenBarcodes.add(normalizedBarcode)) {
        row.addError('Duplicate barcode inside the workbook.');
      }

      rows.add(row);
    }

    if (rows.isEmpty) {
      throw const ProductImportExcelException(
        'No product rows were found in the Products sheet.',
      );
    }

    final unusedPictures = importPackage.pictures.keys.where((pictureName) {
      return !rows.any((row) => row.normalizedPictureFileName == pictureName);
    }).toList();

    if (unusedPictures.isNotEmpty) {
      workbookWarnings.add(
        '${unusedPictures.length} picture file(s) '
        'do not match any Excel product row.',
      );
    }

    return ProductImportParseResult(
      rows: List<ProductImportRow>.unmodifiable(rows),
      workbookWarnings: List<String>.unmodifiable(workbookWarnings),
    );
  }

  Map<String, int> _createHeaderMap(List<Data?> headerRow) {
    final map = <String, int>{};

    for (var column = 0; column < headerRow.length; column++) {
      final header = _cellText(headerRow[column]);

      if (header.isEmpty) {
        continue;
      }

      final normalized = ProductImportSchema.normalizeHeader(header);

      map.putIfAbsent(normalized, () => column);
    }

    return map;
  }

  void _validateRequiredHeaders(Map<String, int> headerMap) {
    final missing = <String>[];

    for (final required in ProductImportSchema.requiredHeaders) {
      final normalized = ProductImportSchema.normalizeHeader(required);

      if (!headerMap.containsKey(normalized)) {
        missing.add(required);
      }
    }

    if (missing.isNotEmpty) {
      throw ProductImportExcelException(
        'Missing required Excel header(s): '
        '${missing.join(', ')}',
      );
    }
  }

  bool _isBlankRow(List<Data?> row) {
    return row.every((cell) => _cellText(cell).isEmpty);
  }

  ProductImportRow _parseRow({
    required List<Data?> excelRow,
    required int excelRowNumber,
    required Map<String, int> headerMap,
    required ProductImportPackage importPackage,
  }) {
    final sku = _value(excelRow, headerMap, ProductImportSchema.sku);

    final productName = _value(
      excelRow,
      headerMap,
      ProductImportSchema.productName,
    );

    final category = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.category,
    );

    final subcategory = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.subcategory,
    );

    final productClass = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.productClass,
    );

    final barcode = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.barcode,
    );

    final pictureFileName = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.pictureFileName,
    );

    final importRemarks = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.importRemarks,
    );

    final costText = _value(excelRow, headerMap, ProductImportSchema.costPrice);

    final sellingText = _value(
      excelRow,
      headerMap,
      ProductImportSchema.sellingPrice,
    );

    final currentText = _value(
      excelRow,
      headerMap,
      ProductImportSchema.currentStock,
    );

    final minimumText = _value(
      excelRow,
      headerMap,
      ProductImportSchema.minimumStock,
    );

    final maximumText = _value(
      excelRow,
      headerMap,
      ProductImportSchema.maximumStock,
    );

    final activeText = _optionalValue(
      excelRow,
      headerMap,
      ProductImportSchema.active,
    );

    final row = ProductImportRow(
      rowNumber: excelRowNumber,
      sku: sku,
      productName: productName,
      category: category,
      subcategory: subcategory,
      productClass: productClass,
      barcode: barcode,
      costPrice: _parseDouble(costText),
      sellingPrice: _parseDouble(sellingText),
      currentStock: _parseInteger(currentText),
      minimumStock: _parseInteger(minimumText),
      maximumStock: _parseInteger(maximumText),
      active: ProductImportSchema.parseActive(activeText),
      pictureFileName: pictureFileName,
      importRemarks: importRemarks,
    );

    _validateRequiredValues(
      row: row,
      costText: costText,
      sellingText: sellingText,
      currentText: currentText,
      minimumText: minimumText,
      maximumText: maximumText,
    );

    _validateInventory(row);
    _matchPicture(row, importPackage);

    return row;
  }

  void _validateRequiredValues({
    required ProductImportRow row,
    required String costText,
    required String sellingText,
    required String currentText,
    required String minimumText,
    required String maximumText,
  }) {
    if (row.normalizedSku.isEmpty) {
      row.addError('SKU is required.');
    }

    if (row.productName.trim().isEmpty) {
      row.addError('Product Name is required.');
    }

    if (!_isValidDouble(costText)) {
      row.addError('Cost Price must be a valid number.');
    }

    if (!_isValidDouble(sellingText)) {
      row.addError('Selling Price must be a valid number.');
    }

    if (!_isValidInteger(currentText)) {
      row.addError('Current Stock must be a whole number.');
    }

    if (!_isValidInteger(minimumText)) {
      row.addError('Minimum Stock must be a whole number.');
    }

    if (!_isValidInteger(maximumText)) {
      row.addError('Maximum Stock must be a whole number.');
    }

    if (row.costPrice < 0) {
      row.addError('Cost Price cannot be negative.');
    }

    if (row.sellingPrice < 0) {
      row.addError('Selling Price cannot be negative.');
    }

    if (row.currentStock < 0 || row.minimumStock < 0 || row.maximumStock < 0) {
      row.addError('Stock values cannot be negative.');
    }
  }

  void _validateInventory(ProductImportRow row) {
    if (row.minimumStock > row.maximumStock) {
      row.addError('Minimum Stock cannot exceed Maximum Stock.');
    }

    if (row.currentStock > row.maximumStock) {
      row.addError('Current Stock cannot exceed Maximum Stock.');
    }
  }

  void _matchPicture(ProductImportRow row, ProductImportPackage importPackage) {
    final pictureName = row.normalizedPictureFileName;

    if (pictureName == null) {
      return;
    }

    if (!ProductImportSchema.isSupportedPicture(pictureName)) {
      row.addWarning(
        'Unsupported picture format: '
        '$pictureName',
      );
      return;
    }

    final pictureBytes = importPackage.pictures[pictureName];

    if (pictureBytes == null || pictureBytes.isEmpty) {
      row.addWarning(
        'Picture file was not found: '
        '$pictureName',
      );
      return;
    }

    row.pictureBytes = pictureBytes;
  }

  String _value(List<Data?> row, Map<String, int> headerMap, String header) {
    final normalized = ProductImportSchema.normalizeHeader(header);

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

    final integer = int.tryParse(normalized);

    if (integer != null) {
      return true;
    }

    final decimal = double.tryParse(normalized);

    return decimal != null && decimal == decimal.roundToDouble();
  }
}
