import 'dart:typed_data';

class ProductItemMasterExport {
  const ProductItemMasterExport({
    required this.fileName,
    required this.bytes,
    required this.productsExported,
    required this.picturesIncluded,
    required this.picturesMissing,
    required this.pictureFailures,
    required this.warnings,
  });

  final String fileName;
  final Uint8List bytes;

  final int productsExported;
  final int picturesIncluded;
  final int picturesMissing;
  final int pictureFailures;

  final List<String> warnings;

  bool get hasProducts {
    return productsExported > 0;
  }

  bool get hasWarnings {
    return warnings.isNotEmpty;
  }

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
