import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_item_master_export.dart';
import '../repositories/product_repository.dart';
import 'product_import_schema.dart';
import 'product_photo_service.dart';
import 'product_service.dart';

class ProductItemMasterExportException implements Exception {
  const ProductItemMasterExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductItemMasterExportService {
  ProductItemMasterExportService._();

  static final ProductItemMasterExportService instance =
      ProductItemMasterExportService._();

  static const String workbookFileName = 'Item_Master.xlsx';

  static const String picturesFolder = 'Product_Pictures/';

  static const String readmeFileName = 'Export_README.txt';

  final ProductService _productService = ProductService();

  final ProductRepository _repository = ProductRepository.instance;

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  Future<ProductItemMasterExport> createExport() async {
    final products = await _loadProducts();

    if (products.isEmpty) {
      throw const ProductItemMasterExportException(
        'No active products are available '
        'for export.',
      );
    }

    final pictureFiles = <String, Uint8List>{};

    final pictureNames = <String, String>{};

    final pictureRemarks = <String, String>{};

    final warnings = <String>[];

    var picturesIncluded = 0;
    var picturesMissing = 0;
    var pictureFailures = 0;

    for (final product in products) {
      try {
        final photoPath = await _photoService.getPhotoPath(product.sku);

        final bytes = await _photoService.readPhotoBytes(photoPath);

        if (bytes == null || bytes.isEmpty) {
          picturesMissing++;

          pictureRemarks[product.id] = 'No saved product picture found.';

          continue;
        }

        final extension = _detectImageExtension(bytes);

        final safeSku = _safeFileName(product.sku);

        final pictureFileName = '$safeSku.$extension';

        pictureFiles[pictureFileName] = bytes;

        pictureNames[product.id] = pictureFileName;

        pictureRemarks[product.id] = 'Picture included in export.';

        picturesIncluded++;
      } catch (error) {
        pictureFailures++;

        pictureRemarks[product.id] = 'Picture could not be exported.';

        warnings.add(
          '${product.sku}: unable to read '
          'the saved picture: $error',
        );
      }
    }

    final workbookBytes = _createWorkbook(
      products: products,
      pictureNames: pictureNames,
      pictureRemarks: pictureRemarks,
    );

    final archive = Archive();

    archive.addFile(
      ArchiveFile(workbookFileName, workbookBytes.length, workbookBytes),
    );

    for (final entry in pictureFiles.entries) {
      archive.addFile(
        ArchiveFile(
          picturesFolder + entry.key,
          entry.value.length,
          entry.value,
        ),
      );
    }

    if (pictureFiles.isEmpty) {
      archive.addFile(ArchiveFile('$picturesFolder.keep', 0, <int>[]));
    }

    final readmeBytes = utf8.encode(
      _createReadme(
        productsExported: products.length,
        picturesIncluded: picturesIncluded,
        picturesMissing: picturesMissing,
        pictureFailures: pictureFailures,
      ),
    );

    archive.addFile(
      ArchiveFile(readmeFileName, readmeBytes.length, readmeBytes),
    );

    final zippedBytes = ZipEncoder().encode(archive);

    if (zippedBytes == null) {
      throw const ProductItemMasterExportException(
        'Unable to generate the Item Master ZIP.',
      );
    }

    return ProductItemMasterExport(
      fileName: _createExportFileName(),
      bytes: Uint8List.fromList(zippedBytes),
      productsExported: products.length,
      picturesIncluded: picturesIncluded,
      picturesMissing: picturesMissing,
      pictureFailures: pictureFailures,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<void> download(ProductItemMasterExport export) async {
    final baseName = export.fileName.toLowerCase().endsWith('.zip')
        ? export.fileName.substring(0, export.fileName.length - 4)
        : export.fileName;

    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: export.bytes,
      fileExtension: 'zip',
      includeExtension: true,
      mimeType: MimeType.custom,
      customMimeType: 'application/zip',
    );
  }

  Future<List<Product>> _loadProducts() async {
    final products = kIsWeb
        ? await _productService.getProducts()
        : await _repository.getProducts();

    return products
        .where((product) => !product.isDeleted && product.active)
        .toList();
  }

  Uint8List _createWorkbook({
    required List<Product> products,
    required Map<String, String> pictureNames,
    required Map<String, String> pictureRemarks,
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    if (defaultSheet != null &&
        defaultSheet != ProductImportSchema.productsSheet) {
      excel.rename(defaultSheet, ProductImportSchema.productsSheet);
    }

    final sheet = excel[ProductImportSchema.productsSheet];

    final headers = <String>[
      ProductImportSchema.sku,
      ProductImportSchema.productName,
      ProductImportSchema.category,
      ProductImportSchema.subcategory,
      ProductImportSchema.productClass,
      ProductImportSchema.barcode,
      ProductImportSchema.costPrice,
      ProductImportSchema.sellingPrice,
      ProductImportSchema.currentStock,
      ProductImportSchema.minimumStock,
      ProductImportSchema.maximumStock,
      ProductImportSchema.active,
      ProductImportSchema.pictureFileName,
      'Export Remarks',
    ];

    sheet.appendRow(headers.map<CellValue>(TextCellValue.new).toList());

    for (final product in products) {
      sheet.appendRow(<CellValue>[
        TextCellValue(product.sku),
        TextCellValue(product.name),
        TextCellValue(product.category ?? ''),
        TextCellValue(product.subcategory ?? ''),
        TextCellValue(product.productClass ?? ''),
        TextCellValue(product.barcode ?? ''),
        DoubleCellValue(product.costPrice),
        DoubleCellValue(product.sellingPrice),
        IntCellValue(product.currentStock),
        IntCellValue(product.minimumStock),
        IntCellValue(product.maximumStock),
        TextCellValue(product.active ? 'YES' : 'NO'),
        TextCellValue(pictureNames[product.id] ?? ''),
        TextCellValue(pictureRemarks[product.id] ?? 'No export remark.'),
      ]);
    }

    _styleWorkbook(sheet: sheet, columnCount: headers.length);

    final encoded = excel.encode();

    if (encoded == null) {
      throw const ProductItemMasterExportException(
        'Unable to encode Item_Master.xlsx.',
      );
    }

    return Uint8List.fromList(encoded);
  }

  void _styleWorkbook({required Sheet sheet, required int columnCount}) {
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#6D28D9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (var column = 0; column < columnCount; column++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
              )
              .cellStyle =
          headerStyle;
    }

    final widths = <double>[
      18,
      32,
      20,
      20,
      20,
      20,
      15,
      15,
      15,
      15,
      15,
      12,
      28,
      36,
    ];

    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  String _detectImageExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    return 'jpg';
  }

  String _safeFileName(String value) {
    final normalized = value.trim().toUpperCase();

    final safeName = normalized.replaceAll(RegExp(r'[^A-Z0-9._-]'), '_');

    if (safeName.isEmpty) {
      return 'PRODUCT';
    }

    return safeName;
  }

  String _createExportFileName() {
    final now = DateTime.now();

    final year = now.year.toString().padLeft(4, '0');

    final month = now.month.toString().padLeft(2, '0');

    final day = now.day.toString().padLeft(2, '0');

    final hour = now.hour.toString().padLeft(2, '0');

    final minute = now.minute.toString().padLeft(2, '0');

    return 'POS_Item_Master_'
        '$year$month$day'
        '_$hour$minute.zip';
  }

  String _createReadme({
    required int productsExported,
    required int picturesIncluded,
    required int picturesMissing,
    required int pictureFailures,
  }) {
    return '''
FLAV POS ITEM MASTER EXPORT

PACKAGE CONTENTS
1. Item_Master.xlsx
2. Product_Pictures folder
3. Export_README.txt

EXPORT SUMMARY
Products Exported: $productsExported
Pictures Included: $picturesIncluded
Pictures Missing: $picturesMissing
Picture Failures: $pictureFailures

WORKBOOK CONTENT
- SKU
- Product Name
- Category
- Subcategory
- Class
- Barcode
- Cost Price
- Selling Price
- Current Stock
- Minimum Stock
- Maximum Stock
- Active Status
- Picture File Name
- Export Remarks

IMPORTANT
- Item_Master.xlsx contains active products only.
- Product pictures use normalized SKU filenames.
- Products without pictures remain included in the workbook.
- Exporting does not change product data, prices, stocks, or pictures.
- Keep Item_Master.xlsx and Product_Pictures together when using this package as a backup.
- Review Export Remarks for products with missing or failed pictures.
''';
  }
}
