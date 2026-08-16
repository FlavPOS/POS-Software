import 'dart:typed_data';

class ProductUpdatePackage {
  const ProductUpdatePackage({
    required this.sourceFileName,
    required this.workbookFileName,
    required this.workbookBytes,
    required this.pictures,
    required this.warnings,
  });

  final String sourceFileName;
  final String workbookFileName;
  final Uint8List workbookBytes;

  final Map<String, Uint8List> pictures;
  final List<String> warnings;

  bool get hasPictures {
    return pictures.isNotEmpty;
  }

  bool get hasWarnings {
    return warnings.isNotEmpty;
  }

  int get pictureCount {
    return pictures.length;
  }

  Uint8List? pictureByFileName(String fileName) {
    final normalized = normalizeFileName(fileName);

    return pictures[normalized];
  }

  bool containsPicture(String fileName) {
    final normalized = normalizeFileName(fileName);

    return pictures.containsKey(normalized);
  }

  static String normalizeFileName(String fileName) {
    return fileName.replaceAll('\\', '/').split('/').last.trim().toLowerCase();
  }
}
