import 'package:file_selector/file_selector.dart';

import '../models/product_import_file.dart';

class ProductUpdatePickerException implements Exception {
  const ProductUpdatePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductUpdatePickerService {
  ProductUpdatePickerService._();

  static final ProductUpdatePickerService instance =
      ProductUpdatePickerService._();

  static const XTypeGroup _fileTypes = XTypeGroup(
    label: 'FLAV POS Product Update',
    extensions: <String>['xlsx', 'zip'],
    mimeTypes: <String>[
      'application/zip',
      'application/x-zip-compressed',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ],
    webWildCards: <String>['.xlsx', '.zip'],
  );

  static const int maximumFileBytes = 250 * 1024 * 1024;

  Future<ProductImportFile?> pickFile() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_fileTypes],
    );

    if (selected == null) {
      return null;
    }

    final fileName = selected.name.trim();

    if (fileName.isEmpty) {
      throw const ProductUpdatePickerException(
        'The selected update file has '
        'no filename.',
      );
    }

    final extension = _extensionFromFileName(fileName);

    if (extension != 'xlsx' && extension != 'zip') {
      throw const ProductUpdatePickerException(
        'Please select Product_Update.xlsx '
        'or a Product Update ZIP package.',
      );
    }

    final bytes = await selected.readAsBytes();

    if (bytes.isEmpty) {
      throw const ProductUpdatePickerException(
        'The selected update file is empty.',
      );
    }

    if (bytes.lengthInBytes > maximumFileBytes) {
      throw const ProductUpdatePickerException(
        'The selected update file is larger '
        'than the allowed limit.',
      );
    }

    return ProductImportFile(
      fileName: fileName,
      extension: extension,
      bytes: bytes,
    );
  }

  String _extensionFromFileName(String fileName) {
    final normalized = fileName.trim();
    final dot = normalized.lastIndexOf('.');

    if (dot < 0 || dot == normalized.length - 1) {
      return '';
    }

    return normalized.substring(dot + 1).toLowerCase();
  }
}
