import 'package:file_selector/file_selector.dart';

import '../models/product_import_file.dart';

class ProductImportPickerException implements Exception {
  const ProductImportPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductImportPickerService {
  ProductImportPickerService._();

  static final ProductImportPickerService instance =
      ProductImportPickerService._();

  static const XTypeGroup _importFileTypes = XTypeGroup(
    label: 'POS Product Import',
    extensions: <String>['zip', 'xlsx'],
    mimeTypes: <String>[
      'application/zip',
      'application/x-zip-compressed',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ],
    webWildCards: <String>['.zip', '.xlsx'],
  );

  Future<ProductImportFile?> pickFile() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_importFileTypes],
    );

    if (selected == null) {
      return null;
    }

    final fileName = selected.name.trim();

    if (fileName.isEmpty) {
      throw const ProductImportPickerException(
        'The selected file has no filename.',
      );
    }

    final extension = _extensionFromFileName(fileName).toLowerCase();

    if (extension != 'zip' && extension != 'xlsx') {
      throw const ProductImportPickerException(
        'Please select a ZIP or XLSX file.',
      );
    }

    final bytes = await selected.readAsBytes();

    if (bytes.isEmpty) {
      throw const ProductImportPickerException('The selected file is empty.');
    }

    return ProductImportFile(
      fileName: fileName,
      extension: extension,
      bytes: bytes,
    );
  }

  String _extensionFromFileName(String fileName) {
    final normalized = fileName.trim();
    final separatorIndex = normalized.lastIndexOf('.');

    if (separatorIndex < 0 || separatorIndex == normalized.length - 1) {
      return '';
    }

    return normalized.substring(separatorIndex + 1);
  }
}
