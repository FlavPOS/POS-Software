import 'dart:typed_data';

import 'product.dart';

enum ProductPictureMatchStatus { matched, unmatched, duplicate, invalid }

enum ProductPictureSaveStatus { pending, updated, skipped, failed }

class ProductPictureUpdateItem {
  ProductPictureUpdateItem({
    required this.fileName,
    required this.archivePath,
    required this.normalizedSku,
    required this.bytes,
    required this.matchStatus,
    this.product,
    this.message,
    this.saveStatus = ProductPictureSaveStatus.pending,
    this.saveError,
  });

  final String fileName;
  final String archivePath;
  final String normalizedSku;
  final Uint8List bytes;

  final ProductPictureMatchStatus matchStatus;
  final Product? product;
  final String? message;

  ProductPictureSaveStatus saveStatus;
  String? saveError;

  bool get canUpdate {
    return matchStatus == ProductPictureMatchStatus.matched &&
        product != null &&
        bytes.isNotEmpty;
  }

  bool get isMatched {
    return matchStatus == ProductPictureMatchStatus.matched;
  }

  bool get isUnmatched {
    return matchStatus == ProductPictureMatchStatus.unmatched;
  }

  bool get isDuplicate {
    return matchStatus == ProductPictureMatchStatus.duplicate;
  }

  bool get isInvalid {
    return matchStatus == ProductPictureMatchStatus.invalid;
  }

  bool get wasUpdated {
    return saveStatus == ProductPictureSaveStatus.updated;
  }

  bool get wasSkipped {
    return saveStatus == ProductPictureSaveStatus.skipped;
  }

  bool get hasFailed {
    return saveStatus == ProductPictureSaveStatus.failed;
  }

  void markUpdated() {
    saveStatus = ProductPictureSaveStatus.updated;

    saveError = null;
  }

  void markSkipped({String? reason}) {
    saveStatus = ProductPictureSaveStatus.skipped;

    saveError = reason;
  }

  void markFailed(Object error) {
    saveStatus = ProductPictureSaveStatus.failed;

    saveError = error.toString();
  }
}

class ProductPictureUpdatePackage {
  const ProductPictureUpdatePackage({
    required this.fileName,
    required this.items,
    required this.warnings,
  });

  final String fileName;
  final List<ProductPictureUpdateItem> items;
  final List<String> warnings;

  int get picturesFound {
    return items.length;
  }

  int get matched {
    return items.where((item) {
      return item.matchStatus == ProductPictureMatchStatus.matched;
    }).length;
  }

  int get unmatched {
    return items.where((item) {
      return item.matchStatus == ProductPictureMatchStatus.unmatched;
    }).length;
  }

  int get duplicates {
    return items.where((item) {
      return item.matchStatus == ProductPictureMatchStatus.duplicate;
    }).length;
  }

  int get invalid {
    return items.where((item) {
      return item.matchStatus == ProductPictureMatchStatus.invalid;
    }).length;
  }

  bool get hasMatchedPictures {
    return matched > 0;
  }

  bool get hasWarnings {
    return warnings.isNotEmpty;
  }

  List<ProductPictureUpdateItem> get matchedItems {
    return items.where((item) => item.canUpdate).toList(growable: false);
  }
}

class ProductPictureUpdateResult {
  const ProductPictureUpdateResult({required this.items});

  final List<ProductPictureUpdateItem> items;

  int get picturesFound {
    return items.length;
  }

  int get updated {
    return items.where((item) {
      return item.saveStatus == ProductPictureSaveStatus.updated;
    }).length;
  }

  int get skipped {
    return items.where((item) {
      return item.saveStatus == ProductPictureSaveStatus.skipped;
    }).length;
  }

  int get failed {
    return items.where((item) {
      return item.saveStatus == ProductPictureSaveStatus.failed;
    }).length;
  }

  bool get hasUpdatedPictures {
    return updated > 0;
  }

  bool get hasFailures {
    return failed > 0;
  }

  List<ProductPictureUpdateItem> get failedItems {
    return items.where((item) => item.hasFailed).toList(growable: false);
  }
}
