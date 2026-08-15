import 'package:file_selector/file_selector.dart';

import '../models/product_import_file.dart';

class ProductPictureUpdatePickerException implements Exception {
  const ProductPictureUpdatePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductPictureUpdatePickerService {
  ProductPictureUpdatePickerService._();

  static final ProductPictureUpdatePickerService instance =
      ProductPictureUpdatePickerService._();

  static const XTypeGroup _zipFileType = XTypeGroup(
    label: 'Product Picture Update ZIP',
    extensions: <String>['zip'],
    mimeTypes: <String>['application/zip', 'application/x-zip-compressed'],
    webWildCards: <String>['.zip'],
  );

  static const int maximumZipBytes = 250 * 1024 * 1024;

  Future<ProductImportFile?> pickZip() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_zipFileType],
    );

    if (selected == null) {
      return null;
    }

    final fileName = selected.name.trim();

    if (fileName.isEmpty) {
      throw const ProductPictureUpdatePickerException(
        'The selected ZIP file has no filename.',
      );
    }

    final extension = _extensionFromFileName(fileName);

    if (extension != 'zip') {
      throw const ProductPictureUpdatePickerException(
        'Please select a ZIP file containing '
        'SKU-named product pictures.',
      );
    }

    final bytes = await selected.readAsBytes();

    if (bytes.isEmpty) {
      throw const ProductPictureUpdatePickerException(
        'The selected ZIP file is empty.',
      );
    }

    if (bytes.lengthInBytes > maximumZipBytes) {
      throw const ProductPictureUpdatePickerException(
        'The selected ZIP file is larger than '
        'the allowed limit.',
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
