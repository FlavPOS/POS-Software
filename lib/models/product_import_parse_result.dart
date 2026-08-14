import 'product_import_row.dart';

class ProductImportParseResult {
  const ProductImportParseResult({
    required this.rows,
    required this.workbookWarnings,
  });

  final List<ProductImportRow> rows;
  final List<String> workbookWarnings;

  int get totalRows => rows.length;

  int get validRows {
    return rows.where((row) => row.isValid).length;
  }

  int get warningRows {
    return rows.where((row) => row.hasWarnings).length;
  }

  int get errorRows {
    return rows.where((row) => !row.isValid).length;
  }

  int get picturesMatched {
    return rows.where((row) => row.hasPicture).length;
  }

  int get picturesMissing {
    return rows.where((row) {
      return row.normalizedPictureFileName != null && !row.hasPicture;
    }).length;
  }

  bool get hasValidRows => validRows > 0;
}
