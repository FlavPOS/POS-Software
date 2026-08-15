import 'dart:typed_data';

class ProductUpdateTemplatePackage {
  const ProductUpdateTemplatePackage({
    required this.fileName,
    required this.bytes,
    required this.activeProducts,
    required this.productsWithPictures,
    required this.productsMissingPictures,
  });

  final String fileName;
  final Uint8List bytes;

  final int activeProducts;
  final int productsWithPictures;
  final int productsMissingPictures;

  int get fileSizeBytes {
    return bytes.lengthInBytes;
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    }

    final kilobytes = fileSizeBytes / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;

    return '${megabytes.toStringAsFixed(1)} MB';
  }
}
