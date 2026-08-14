import 'product.dart';

enum ProductDeleteStatus { deleted, failed }

class ProductDeleteItemResult {
  const ProductDeleteItemResult({
    required this.product,
    required this.status,
    required this.message,
    this.pictureDeleted = false,
    this.pictureFailed = false,
  });

  final Product product;
  final ProductDeleteStatus status;
  final String message;

  final bool pictureDeleted;
  final bool pictureFailed;

  bool get deleted {
    return status == ProductDeleteStatus.deleted;
  }

  bool get failed {
    return status == ProductDeleteStatus.failed;
  }
}

class ProductDeleteResult {
  const ProductDeleteResult({required this.items});

  final List<ProductDeleteItemResult> items;

  int get total => items.length;

  int get deleted {
    return items.where((item) => item.deleted).length;
  }

  int get failed {
    return items.where((item) => item.failed).length;
  }

  int get picturesDeleted {
    return items.where((item) => item.pictureDeleted).length;
  }

  int get pictureFailures {
    return items.where((item) => item.pictureFailed).length;
  }

  bool get hasDeletedProducts => deleted > 0;
}
