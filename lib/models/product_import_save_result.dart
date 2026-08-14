import 'product_import_row.dart';
import 'product_import_summary.dart';

enum ProductImportSaveStatus { imported, skipped, failed }

class ProductImportRowSaveResult {
  const ProductImportRowSaveResult({
    required this.row,
    required this.status,
    required this.message,
    this.productId,
    this.pictureSaved = false,
    this.pictureMissing = false,
    this.pictureFailed = false,
  });

  final ProductImportRow row;
  final ProductImportSaveStatus status;
  final String message;
  final String? productId;

  final bool pictureSaved;
  final bool pictureMissing;
  final bool pictureFailed;

  bool get imported {
    return status == ProductImportSaveStatus.imported;
  }

  bool get skipped {
    return status == ProductImportSaveStatus.skipped;
  }

  bool get failed {
    return status == ProductImportSaveStatus.failed;
  }
}

class ProductImportSaveResult {
  const ProductImportSaveResult({required this.rows, required this.summary});

  final List<ProductImportRowSaveResult> rows;
  final ProductImportSummary summary;

  bool get hasImportedProducts {
    return summary.imported > 0;
  }

  bool get hasFailures {
    return summary.failed > 0;
  }
}
