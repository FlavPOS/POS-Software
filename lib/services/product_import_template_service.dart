import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';

import 'product_import_schema.dart';

class ProductImportTemplatePackage {
  const ProductImportTemplatePackage({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class ProductImportTemplateService {
  ProductImportTemplateService._();

  static final ProductImportTemplateService instance =
      ProductImportTemplateService._();

  static const String packageFileName = 'POS_Product_Import_Template.zip';

  static const String workbookFileName = 'Product_Import_Template.xlsx';

  static const String picturesFolder = 'Product_Pictures/';

  static const String readmeFileName = 'README.txt';

  ProductImportTemplatePackage createPackage() {
    final workbookBytes = _createWorkbook();

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
      throw StateError('Unable to generate the product import package.');
    }

    return ProductImportTemplatePackage(
      fileName: packageFileName,
      bytes: Uint8List.fromList(zippedBytes),
    );
  }

  Uint8List _createWorkbook() {
    final excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();

    if (defaultSheet != null &&
        defaultSheet != ProductImportSchema.productsSheet) {
      excel.rename(defaultSheet, ProductImportSchema.productsSheet);
    }

    final products = excel[ProductImportSchema.productsSheet];

    _buildProductsSheet(products);

    final instructions = excel[ProductImportSchema.instructionsSheet];

    _buildInstructionsSheet(instructions);

    final values = excel[ProductImportSchema.validValuesSheet];

    _buildValidValuesSheet(values);

    excel.setDefaultSheet(ProductImportSchema.productsSheet);

    final encoded = excel.encode();

    if (encoded == null) {
      throw StateError('Unable to generate the Excel template.');
    }

    return Uint8List.fromList(encoded);
  }

  void _buildProductsSheet(Sheet sheet) {
    sheet.appendRow(
      ProductImportSchema.headers
          .map<TextCellValue>(TextCellValue.new)
          .toList(),
    );

    sheet.appendRow(<CellValue>[
      TextCellValue('123456'),
      TextCellValue('Sample Product'),
      TextCellValue('Beverages'),
      TextCellValue('Soft Drinks'),
      TextCellValue('Carbonated Drinks'),
      TextCellValue('4801234567890'),
      DoubleCellValue(30),
      DoubleCellValue(50),
      IntCellValue(30),
      IntCellValue(10),
      IntCellValue(100),
      BoolCellValue(true),
      TextCellValue('123456.jpg'),
      TextCellValue('Replace this example row.'),
    ]);

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#6D28D9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    final inputStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#0000FF'),
      verticalAlign: VerticalAlign.Center,
    );

    for (
      var column = 0;
      column < ProductImportSchema.headers.length;
      column++
    ) {
      final headerCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      );

      headerCell.cellStyle = headerStyle;

      final exampleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 1),
      );

      exampleCell.cellStyle = inputStyle;
    }

    sheet.setRowHeight(0, 34);
    sheet.setRowHeight(1, 24);

    final widths = <double>[
      16,
      28,
      20,
      22,
      24,
      20,
      15,
      15,
      16,
      16,
      16,
      12,
      24,
      32,
    ];

    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  void _buildInstructionsSheet(Sheet sheet) {
    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#6D28D9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    final sectionStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#EDE9FE'),
      fontColorHex: ExcelColor.fromHexString('#5B21B6'),
      bold: true,
    );

    final rows = <List<CellValue>>[
      <CellValue>[TextCellValue('POS Product Import Instructions')],
      <CellValue>[TextCellValue('Workbook Rules')],
      <CellValue>[
        TextCellValue('1. Do not rename or remove the Excel headers.'),
      ],
      <CellValue>[TextCellValue('2. Use one product per row.')],
      <CellValue>[TextCellValue('3. SKU is required and must be unique.')],
      <CellValue>[
        TextCellValue(
          '4. Barcode is optional but must be unique when supplied.',
        ),
      ],
      <CellValue>[
        TextCellValue('5. Cost Price and Selling Price cannot be negative.'),
      ],
      <CellValue>[
        TextCellValue('6. Minimum Stock cannot exceed Maximum Stock.'),
      ],
      <CellValue>[
        TextCellValue('7. Current Stock cannot exceed Maximum Stock.'),
      ],
      <CellValue>[TextCellValue('8. Active accepts TRUE or FALSE.')],
      <CellValue>[TextCellValue('Picture Rules')],
      <CellValue>[
        TextCellValue(
          '9. Place image files inside the Product_Pictures folder.',
        ),
      ],
      <CellValue>[
        TextCellValue(
          '10. Enter the exact image filename in Picture File Name.',
        ),
      ],
      <CellValue>[
        TextCellValue('11. Supported images: JPG, JPEG, PNG, and WEBP.'),
      ],
      <CellValue>[
        TextCellValue('12. Missing pictures do not block product import.'),
      ],
      <CellValue>[TextCellValue('Upload Rules')],
      <CellValue>[
        TextCellValue(
          '13. Keep the Excel file and Product_Pictures folder inside one ZIP.',
        ),
      ],
      <CellValue>[
        TextCellValue('14. Upload the completed ZIP using Import Products.'),
      ],
    ];

    for (final row in rows) {
      sheet.appendRow(row);
    }

    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
            .cellStyle =
        titleStyle;

    for (final rowIndex in <int>[1, 10, 15]) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .cellStyle =
          sectionStyle;
    }

    sheet.setColumnWidth(0, 95);
    sheet.setRowHeight(0, 30);
  }

  void _buildValidValuesSheet(Sheet sheet) {
    sheet.appendRow(<CellValue>[
      TextCellValue('Category'),
      TextCellValue('Subcategory'),
      TextCellValue('Class Example'),
      TextCellValue('Active'),
    ]);

    final classExamples = <String, List<String>>{
      'Soft Drinks': ['Carbonated Drinks', 'Energy Drinks', 'Sports Drinks'],
      'Water': ['Purified Water', 'Mineral Water', 'Sparkling Water'],
      'Juice': ['Fruit Juice', 'Juice Drink'],
      'Coffee and Tea': ['Coffee', 'Tea', 'Ready to Drink'],
    };

    for (final category in ProductImportSchema.categories) {
      final subcategories =
          ProductImportSchema.subcategories[category] ?? const <String>[];

      for (final subcategory in subcategories) {
        final classes = classExamples[subcategory] ?? const <String>[];

        if (classes.isEmpty) {
          sheet.appendRow(<CellValue>[
            TextCellValue(category),
            TextCellValue(subcategory),
            TextCellValue(''),
            TextCellValue('TRUE / FALSE'),
          ]);

          continue;
        }

        for (final productClass in classes) {
          sheet.appendRow(<CellValue>[
            TextCellValue(category),
            TextCellValue(subcategory),
            TextCellValue(productClass),
            TextCellValue('TRUE / FALSE'),
          ]);
        }
      }
    }

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#6D28D9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    for (var column = 0; column < 4; column++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
              )
              .cellStyle =
          headerStyle;
    }

    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 26);
    sheet.setColumnWidth(2, 28);
    sheet.setColumnWidth(3, 18);
  }

  String get _readmeContent {
    return '''
POS PRODUCT IMPORT PACKAGE

FILES
1. Product_Import_Template.xlsx
2. Product_Pictures folder
3. README.txt

HOW TO USE
1. Open Product_Import_Template.xlsx.
2. Keep all Excel header names unchanged.
3. Replace or remove the example row.
4. Enter one product per row.
5. Place product pictures inside Product_Pictures.
6. Enter the exact picture filename in the Excel Picture File Name column.
7. Keep the Excel workbook and Product_Pictures folder inside the ZIP.
8. Upload the ZIP through Products > Import Products.

SUPPORTED PICTURES
JPG, JPEG, PNG, WEBP

IMPORTANT VALIDATION
- SKU is required and unique.
- Product Name is required.
- Cost Price and Selling Price cannot be negative.
- Current, Minimum, and Maximum Stock must be whole numbers.
- Minimum Stock cannot exceed Maximum Stock.
- Current Stock cannot exceed Maximum Stock.
- Missing pictures do not block product import.
''';
  }
}
