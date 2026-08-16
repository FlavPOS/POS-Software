import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_update_template_package.dart';
import '../repositories/product_repository.dart';
import 'product_photo_service.dart';
import 'product_service.dart';

class ProductUpdateTemplateException implements Exception {
  const ProductUpdateTemplateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductUpdateTemplateService {
  ProductUpdateTemplateService._();

  static final ProductUpdateTemplateService instance =
      ProductUpdateTemplateService._();

  static const String packageFileName = 'POS_Product_Update_Template.zip';

  static const String workbookFileName = 'Product_Update.xlsx';

  static const String picturesFolder = 'Product_Pictures/';

  static const String readmeFileName = 'README.txt';

  static const String updatesSheet = 'Product Updates';

  static const String instructionsSheet = 'Instructions';

  static const String validValuesSheet = 'Valid Values';

  static const List<String> headers = <String>[
    'SKU *',
    'Product Name',
    'Category',
    'Subcategory',
    'Class',
    'Barcode',
    'Cost Price',
    'Selling Price',
    'Minimum Stock',
    'Maximum Stock',
    'Active',
    'Picture File Name',
    'Update Remarks',
  ];

  final ProductService _productService = ProductService();

  final ProductRepository _repository = ProductRepository.instance;

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  Future<ProductUpdateTemplatePackage> createPackage() async {
    final products = await _loadActiveProducts();

    var productsWithPictures = 0;
    var productsMissingPictures = 0;

    final pictureStatuses = <String, String>{};

    for (final product in products) {
      try {
        final photoPath = await _photoService.getPhotoPath(product.sku);

        if (photoPath == null || photoPath.trim().isEmpty) {
          productsMissingPictures++;

          pictureStatuses[product.id] = 'Missing Picture';
        } else {
          productsWithPictures++;

          pictureStatuses[product.id] = 'Picture Available';
        }
      } catch (_) {
        productsMissingPictures++;

        pictureStatuses[product.id] = 'Picture Status Unavailable';
      }
    }

    final workbookBytes = _createWorkbook(
      products: products,
      pictureStatuses: pictureStatuses,
    );

    final readmeBytes = utf8.encode(_readmeContent);

    final archive = Archive();

    archive.addFile(
      ArchiveFile(workbookFileName, workbookBytes.length, workbookBytes),
    );

    archive.addFile(ArchiveFile('$picturesFolder.keep', 0, <int>[]));

    archive.addFile(
      ArchiveFile(readmeFileName, readmeBytes.length, readmeBytes),
    );

    final zippedBytes = ZipEncoder().encode(archive);

    if (zippedBytes == null) {
      throw const ProductUpdateTemplateException(
        'Unable to generate the Product '
        'Update Template ZIP.',
      );
    }

    return ProductUpdateTemplatePackage(
      fileName: packageFileName,
      bytes: Uint8List.fromList(zippedBytes),
      activeProducts: products.length,
      productsWithPictures: productsWithPictures,
      productsMissingPictures: productsMissingPictures,
    );
  }

  Future<List<Product>> _loadActiveProducts() async {
    final products = kIsWeb
        ? await _productService.getProducts()
        : await _repository.getProducts();

    final activeProducts = products
        .where((product) => product.active && !product.isDeleted)
        .toList();

    activeProducts.sort((first, second) {
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return activeProducts;
  }

  Uint8List _createWorkbook({
    required List<Product> products,
    required Map<String, String> pictureStatuses,
  }) {
    final excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();

    if (defaultSheet != null && defaultSheet != updatesSheet) {
      excel.rename(defaultSheet, updatesSheet);
    }

    final updateSheet = excel[updatesSheet];

    _buildUpdateSheet(sheet: updateSheet);

    _buildInstructionsSheet(excel[instructionsSheet]);

    _buildValidValuesSheet(excel[validValuesSheet]);

    final encoded = excel.encode();

    if (encoded == null) {
      throw const ProductUpdateTemplateException(
        'Unable to encode Product_Update.xlsx.',
      );
    }

    return Uint8List.fromList(encoded);
  }

  void _buildUpdateSheet({required Sheet sheet}) {
    sheet.appendRow(headers.map<CellValue>(TextCellValue.new).toList());

    // One blank input row only.
    // Enter only an existing SKU that needs
    // product information or picture updates.
    sheet.appendRow(<CellValue>[
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Enter only products that need updates.'),
    ]);

    _styleHeader(sheet: sheet, columnCount: headers.length);

    _styleUpdateRows(sheet: sheet, rowCount: 1);

    final widths = <double>[18, 32, 20, 20, 20, 20, 15, 15, 16, 16, 12, 28, 38];

    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  void _styleUpdateRows({required Sheet sheet, required int rowCount}) {
    final skuStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FEE2E2'),
      fontColorHex: ExcelColor.fromHexString('#991B1B'),
    );

    final editableStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FEF9C3'),
      fontColorHex: ExcelColor.fromHexString('#713F12'),
    );

    for (var row = 1; row <= rowCount; row++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .cellStyle =
          skuStyle;

      for (var column = 1; column < headers.length; column++) {
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: column,
                    rowIndex: row,
                  ),
                )
                .cellStyle =
            editableStyle;
      }
    }
  }

  void _styleHeader({required Sheet sheet, required int columnCount}) {
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
  }

  void _buildInstructionsSheet(Sheet sheet) {
    final rows = <List<String>>[
      <String>['FLAV POS PRODUCT UPDATE TEMPLATE'],
      <String>[''],
      <String>['PURPOSE', 'Enter only products that need updates.'],
      <String>['MATCHING RULE', 'SKU is required and cannot be changed.'],
      <String>[
        'BLANK CELL RULE',
        'Blank editable cells keep the '
            'existing product value.',
      ],
      <String>[
        'PICTURES',
        'Place replacement pictures inside '
            'Product_Pictures.',
      ],
      <String>[
        'PICTURE NAME',
        'Use the exact SKU as the filename, '
            'for example 12345689.jpg.',
      ],
      <String>['SUPPORTED PICTURES', 'JPG, JPEG, PNG, WEBP'],
      <String>['CURRENT STOCK', 'Cannot be updated using this template.'],
      <String>['BEGINNING STOCK', 'Cannot be updated using this template.'],
      <String>[
        'ACTIVE VALUES',
        'YES = Active, NO = Inactive, '
            'blank = no change.',
      ],
      <String>[
        'PREVIEW',
        'Review all old and new values before '
            'confirming.',
      ],
      <String>[
        'BACKUP',
        'Download the Item Master with Pictures '
            'before major updates.',
      ],
    ];

    for (final row in rows) {
      sheet.appendRow(row.map<CellValue>(TextCellValue.new).toList());
    }

    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 85);

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#6D28D9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
  }

  void _buildValidValuesSheet(Sheet sheet) {
    final rows = <List<String>>[
      <String>['Field', 'Accepted Values', 'Blank Behavior'],
      <String>['Active', 'YES, NO', 'Keep existing status'],
      <String>[
        'Picture File Type',
        'JPG, JPEG, PNG, WEBP',
        'Keep existing picture',
      ],
      <String>[
        'Cost Price',
        'Number greater than or equal to 0',
        'Keep existing cost price',
      ],
      <String>[
        'Selling Price',
        'Number greater than or equal to 0',
        'Keep existing selling price',
      ],
      <String>[
        'Minimum Stock',
        'Whole number, 0 or greater',
        'Keep existing minimum stock',
      ],
      <String>[
        'Maximum Stock',
        'Whole number, 0 or greater',
        'Keep existing maximum stock',
      ],
    ];

    for (final row in rows) {
      sheet.appendRow(row.map<CellValue>(TextCellValue.new).toList());
    }

    _styleHeader(sheet: sheet, columnCount: 3);

    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 42);
    sheet.setColumnWidth(2, 35);
  }

  String get _readmeContent {
    return '''
FLAV POS PRODUCT UPDATE TEMPLATE
================================

PURPOSE
-------
Use this package to update selected existing products.

Only products entered in Product_Update.xlsx will be reviewed.
The template contains one blank input row only.
Add additional rows only for products that need updates.
Products not entered in the workbook remain unchanged.

PACKAGE CONTENTS
----------------
1. Product_Update.xlsx
2. Product_Pictures folder
3. README.txt

HOW TO USE
----------
1. Open Product_Update.xlsx.
2. Go to the Product Updates sheet.
3. Find the exact existing product SKU.
4. Enter values only in fields that need to change.
5. Leave editable cells blank to keep existing values.
6. To update a picture, rename the picture using the exact SKU.
7. Place the picture inside Product_Pictures.
8. Enter the exact filename in Picture File Name.
9. Save Product_Update.xlsx.
10. Keep the workbook and Product_Pictures in one ZIP.
11. In FLAV POS, select Product Actions > Update Existing Products.
12. Review all old and new values before confirming.

EDITABLE FIELDS
---------------
Product Name
Category
Subcategory
Class
Barcode
Cost Price
Selling Price
Minimum Stock
Maximum Stock
Active
Picture File Name
Update Remarks

BLANK CELL RULE
---------------
A blank editable cell means KEEP THE EXISTING VALUE.

SKU RULE
--------
SKU is required and is used only to match the existing product.
SKU cannot be changed through this template.

PROTECTED FIELDS
----------------
SKU
Product ID
Current Stock
Beginning Stock
Created Date
Updated Date
Deleted Status
Synchronization Status
Branch Inventory
Transaction History

CURRENT STOCK PROTECTION
------------------------
Current Stock must be changed only through approved inventory
transactions such as Receive Delivery, Sales, Void, Refund,
Exchange, Transfer, Stock Adjustment, or Physical Count.

ACTIVE VALUES
-------------
YES = Activate product
NO = Deactivate product
Blank = Keep existing status

PICTURE RULES
-------------
Supported formats: JPG, JPEG, PNG, WEBP

Correct example:
SKU: 12345689
Picture File Name: 12345689.jpg
ZIP location: Product_Pictures/12345689.jpg

Use only one replacement picture per SKU.

IMPORTANT
---------
Back up the Item Master before performing major product updates.
Always review the Product Update Preview before confirming.
''';
  }
}
