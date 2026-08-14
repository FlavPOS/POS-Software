import 'dart:typed_data';

class ProductImportPackage {
  const ProductImportPackage({
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

  int get pictureCount {
    return pictures.length;
  }

  bool get hasPictures {
    return pictures.isNotEmpty;
  }

  bool get hasWarnings {
    return warnings.isNotEmpty;
  }

  int get workbookSize {
    return workbookBytes.lengthInBytes;
  }
}
