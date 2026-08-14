import 'dart:typed_data';

class ProductImportFile {
  const ProductImportFile({
    required this.fileName,
    required this.extension,
    required this.bytes,
  });

  final String fileName;
  final String extension;
  final Uint8List bytes;

  bool get isZip => extension == 'zip';

  bool get isExcel => extension == 'xlsx';

  String get displayType {
    return isZip ? 'ZIP package' : 'Excel workbook';
  }

  String get formattedSize {
    final byteCount = bytes.lengthInBytes;

    if (byteCount < 1024) {
      return '$byteCount B';
    }

    final kilobytes = byteCount / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }
}
