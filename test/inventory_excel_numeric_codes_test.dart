import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/product.dart';
import 'package:simple_pos/services/inventory_excel_export_service.dart';

Product buildNumericProduct({
  String sku = '12345617',
  String? barcode = '4801234567883',
}) {
  return Product(
    id: 'product-001',
    name: 'Numeric Code Product',
    sku: sku,
    barcode: barcode,
    costPrice: 70,
    sellingPrice: 100.50,
    beginningStock: 30,
    currentStock: 30,
    minimumStock: 10,
    maximumStock: 50,
    category: 'Health',
    subcategory: 'OTC',
    productClass: 'Pain Relief',
    active: true,
    createdAt: 100,
    updatedAt: 100,
  );
}

void main() {
  group('Inventory numeric SKU and Barcode export', () {
    test('exports SKU and Barcode as integer cells', () {
      final bytes = InventoryExcelExportService.instance.buildWorkbook(
        products: <Product>[buildNumericProduct()],
        extractedAt: DateTime(2026, 8, 18, 9, 15),
      );

      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables['INVENTORY']!;

      final skuCell = sheet.rows[1][1];

      final barcodeCell = sheet.rows[1][2];

      expect(skuCell?.value, isA<IntCellValue>());

      expect(barcodeCell?.value, isA<IntCellValue>());

      expect(skuCell?.value.toString(), '12345617');

      expect(barcodeCell?.value.toString(), '4801234567883');
    });

    test('allows empty Barcode as an empty cell', () {
      final bytes = InventoryExcelExportService.instance.buildWorkbook(
        products: <Product>[buildNumericProduct(barcode: null)],
        extractedAt: DateTime(2026, 8, 18, 9, 15),
      );

      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables['INVENTORY']!;

      expect(sheet.rows[1][2]?.value, isNull);
    });

    test('rejects non-numeric SKU', () {
      expect(() {
        InventoryExcelExportService.instance.buildWorkbook(
          products: <Product>[buildNumericProduct(sku: 'SKU-001')],
          extractedAt: DateTime(2026, 8, 18, 9, 15),
        );
      }, throwsA(isA<FormatException>()));
    });

    test('rejects non-numeric Barcode', () {
      expect(() {
        InventoryExcelExportService.instance.buildWorkbook(
          products: <Product>[buildNumericProduct(barcode: 'BARCODE-001')],
          extractedAt: DateTime(2026, 8, 18, 9, 15),
        );
      }, throwsA(isA<FormatException>()));
    });

    test('rejects codes above Excel 15-digit precision', () {
      expect(() {
        InventoryExcelExportService.instance.buildWorkbook(
          products: <Product>[buildNumericProduct(barcode: '1234567890123456')],
          extractedAt: DateTime(2026, 8, 18, 9, 15),
        );
      }, throwsA(isA<FormatException>()));
    });
  });
}
