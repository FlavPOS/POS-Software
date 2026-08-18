import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/product.dart';
import 'package:simple_pos/services/inventory_excel_export_service.dart';

Product buildProduct({
  String id = 'product-001',
  String sku = 'SKU-001',
  String name = 'Test Product',
  String? barcode = '480000000001',
  int beginningStock = 10,
  int currentStock = 8,
  int minimumStock = 5,
  int maximumStock = 20,
  double sellingPrice = 125,
  double costPrice = 70,
  bool active = true,
  int updatedAt = 100,
}) {
  return Product(
    id: id,
    name: name,
    sku: sku,
    barcode: barcode,
    costPrice: costPrice,
    sellingPrice: sellingPrice,
    beginningStock: beginningStock,
    currentStock: currentStock,
    minimumStock: minimumStock,
    maximumStock: maximumStock,
    category: 'Health',
    subcategory: 'OTC',
    productClass: 'Pain Relief',
    active: active,
    createdAt: 100,
    updatedAt: updatedAt,
  );
}

void main() {
  group('InventoryExcelExportService', () {
    test('Extraction Date is the first column', () {
      expect(InventoryExcelExportService.headers.first, 'Extraction Date');
    });

    test('contains exact Inventory export headers', () {
      expect(InventoryExcelExportService.headers, <String>[
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
      ]);
    });

    test('excludes Picture and Cost Price', () {
      final headerText = InventoryExcelExportService.headers
          .join('|')
          .toLowerCase();

      expect(headerText.contains('picture'), isFalse);

      expect(headerText.contains('photo'), isFalse);

      expect(headerText.contains('cost price'), isFalse);

      expect(headerText.contains('margin'), isFalse);
    });

    test('creates readable Excel workbook', () {
      final bytes = InventoryExcelExportService.instance.buildWorkbook(
        products: <Product>[buildProduct()],
        extractedAt: DateTime(2026, 8, 18, 9, 15),
      );

      expect(bytes, isNotEmpty);

      final excel = Excel.decodeBytes(bytes);

      expect(excel.tables.containsKey('INVENTORY'), isTrue);

      final sheet = excel.tables['INVENTORY']!;

      expect(sheet.rows.first.first?.value.toString(), 'Extraction Date');

      expect(sheet.rows[1][0]?.value.toString(), '08/18/2026 09:15');

      expect(sheet.rows[1][1]?.value.toString(), 'SKU-001');

      expect(sheet.rows[1][8]?.value.toString(), '8');
    });

    test('calculates Inventory stock status', () {
      expect(
        InventoryExcelExportService.stockStatus(buildProduct(currentStock: 0)),
        'Out of Stock',
      );

      expect(
        InventoryExcelExportService.stockStatus(
          buildProduct(currentStock: 5, minimumStock: 5),
        ),
        'Low Stock',
      );

      expect(
        InventoryExcelExportService.stockStatus(
          buildProduct(currentStock: 8, minimumStock: 5),
        ),
        'In Stock',
      );
    });
  });
}
