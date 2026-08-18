import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

import '../models/product.dart';

class InventoryExcelExportResult {
  const InventoryExcelExportResult({
    required this.fileName,
    required this.productCount,
    required this.extractedAt,
  });

  final String fileName;
  final int productCount;
  final DateTime extractedAt;
}

class InventoryExcelExportService {
  InventoryExcelExportService._();

  static final InventoryExcelExportService instance =
      InventoryExcelExportService._();

  static const List<String> headers = <String>[
    'Extraction Date',
    'SKU',
    'Barcode',
    'Product Name',
    'Department',
    'Class',
    'Subclass',
    'Beginning Stock',
    'SOH',
    'Minimum Stock',
    'Maximum Stock',
    'Retail Price',
    'Stock Status',
    'Active Status',
    'Last Updated',
  ];

  Future<InventoryExcelExportResult> export({
    required List<Product> products,
    DateTime? extractedAt,
  }) async {
    if (products.isEmpty) {
      throw const FormatException('There are no Inventory products to export.');
    }

    final extractionDate = extractedAt ?? DateTime.now();

    final bytes = buildWorkbook(
      products: products,
      extractedAt: extractionDate,
    );

    final fileName = _buildFileName(extractionDate);

    await FileSaver.instance.saveFile(
      name: '$fileName.xlsx',
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );

    return InventoryExcelExportResult(
      fileName: '$fileName.xlsx',
      productCount: products.length,
      extractedAt: extractionDate,
    );
  }

  Uint8List buildWorkbook({
    required List<Product> products,
    required DateTime extractedAt,
  }) {
    final excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();

    if (defaultSheet != null && defaultSheet != 'INVENTORY') {
      excel.rename(defaultSheet, 'INVENTORY');
    }

    final sheet = excel['INVENTORY'];

    _writeHeader(sheet);

    final sortedProducts = List<Product>.from(products)
      ..sort((first, second) {
        final nameComparison = first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        );

        if (nameComparison != 0) {
          return nameComparison;
        }

        return first.sku.compareTo(second.sku);
      });

    for (var index = 0; index < sortedProducts.length; index++) {
      final product = sortedProducts[index];

      final rowNumber = index + 1;

      final values = <CellValue?>[
        TextCellValue(_formatDateTime(extractedAt)),
        IntCellValue(_requiredNumericCode(product.sku, fieldName: 'SKU')),
        _optionalNumericCode(product.barcode, fieldName: 'Barcode'),
        TextCellValue(product.name),
        TextCellValue(_classification(product.category)),
        TextCellValue(_classification(product.productClass)),
        TextCellValue(_classification(product.subcategory)),
        IntCellValue(product.beginningStock),
        IntCellValue(product.currentStock),
        IntCellValue(product.minimumStock),
        IntCellValue(product.maximumStock),
        DoubleCellValue(product.sellingPrice),
        TextCellValue(stockStatus(product)),
        TextCellValue(product.active ? 'Active' : 'Inactive'),
        TextCellValue(_formatTimestamp(product.updatedAt)),
      ];

      for (var column = 0; column < values.length; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowNumber),
        );

        cell.value = values[column];

        cell.cellStyle = CellStyle(
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
          bottomBorder: Border(
            borderStyle: BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('#E5E7EB'),
          ),
        );
      }
      for (final codeColumn in <int>[1, 2]) {
        final codeCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: codeColumn,
            rowIndex: rowNumber,
          ),
        );

        codeCell.cellStyle = CellStyle(
          verticalAlign: VerticalAlign.Center,
          numberFormat: NumFormat.custom(formatCode: '0'),
          bottomBorder: Border(
            borderStyle: BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('#E5E7EB'),
          ),
        );
      }

      final retailCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowNumber),
      );

      retailCell.cellStyle = CellStyle(
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.custom(formatCode: '₱#,##0.00'),
        bottomBorder: Border(
          borderStyle: BorderStyle.Thin,
          borderColorHex: ExcelColor.fromHexString('#E5E7EB'),
        ),
      );
    }

    _setColumnWidths(sheet);

    final encoded = excel.encode();

    if (encoded == null) {
      throw const FormatException('Unable to create Inventory Excel file.');
    }

    return Uint8List.fromList(encoded);
  }

  void _writeHeader(Sheet sheet) {
    for (var column = 0; column < headers.length; column++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      );

      cell.value = TextCellValue(headers[column]);

      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#5B5CEB'),
        fontColorHex: ExcelColor.white,
        bold: true,
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        bottomBorder: Border(
          borderStyle: BorderStyle.Medium,
          borderColorHex: ExcelColor.fromHexString('#4338CA'),
        ),
      );
    }
  }

  void _setColumnWidths(Sheet sheet) {
    const widths = <double>[
      21,
      16,
      20,
      32,
      20,
      20,
      20,
      17,
      12,
      17,
      17,
      16,
      16,
      15,
      21,
    ];

    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  static String stockStatus(Product product) {
    if (product.currentStock <= 0) {
      return 'Out of Stock';
    }

    if (product.currentStock <= product.minimumStock) {
      return 'Low Stock';
    }

    return 'In Stock';
  }

  static String _classification(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? 'Not classified' : normalized;
  }

  static int _requiredNumericCode(String value, {required String fieldName}) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw FormatException(
        '$fieldName is required for '
        'Inventory Excel export.',
      );
    }

    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      throw FormatException(
        '$fieldName must contain whole '
        'numbers only. Invalid value: '
        '$normalized',
      );
    }

    if (normalized.length > 15) {
      throw FormatException(
        '$fieldName exceeds Excel numeric '
        'precision. Maximum is 15 digits.',
      );
    }

    return int.parse(normalized);
  }

  static CellValue? _optionalNumericCode(
    String? value, {
    required String fieldName,
  }) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    return IntCellValue(_requiredNumericCode(normalized, fieldName: fieldName));
  }

  static String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) {
      return '-';
    }

    final milliseconds = timestamp < 1000000000000
        ? timestamp * 1000
        : timestamp;

    return _formatDateTime(DateTime.fromMillisecondsSinceEpoch(milliseconds));
  }

  static String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');

    final day = value.day.toString().padLeft(2, '0');

    final hour = value.hour.toString().padLeft(2, '0');

    final minute = value.minute.toString().padLeft(2, '0');

    return '$month/$day/${value.year} '
        '$hour:$minute';
  }

  static String _buildFileName(DateTime value) {
    final year = value.year.toString();

    final month = value.month.toString().padLeft(2, '0');

    final day = value.day.toString().padLeft(2, '0');

    final hour = value.hour.toString().padLeft(2, '0');

    final minute = value.minute.toString().padLeft(2, '0');

    return 'Inventory_SOH_'
        '$year$month$day'
        '_$hour$minute';
  }
}
