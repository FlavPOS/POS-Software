import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'product_import_schema.dart';

import '../models/product_import_file.dart';
import '../models/product_import_package.dart';

class ProductImportPackageException implements Exception {
  const ProductImportPackageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductImportPackageService {
  ProductImportPackageService._();

  static final ProductImportPackageService instance =
      ProductImportPackageService._();

  static const int maximumArchiveEntries = 5000;

  static const int maximumWorkbookBytes = 25 * 1024 * 1024;

  static const int maximumPictureBytes = 10 * 1024 * 1024;

  static const int maximumExpandedBytes = 250 * 1024 * 1024;

  ProductImportPackage validate(ProductImportFile selectedFile) {
    if (selectedFile.isExcel) {
      return _validateDirectWorkbook(selectedFile);
    }

    if (selectedFile.isZip) {
      return _validateZipPackage(selectedFile);
    }

    throw const ProductImportPackageException(
      'Only ZIP and XLSX files are supported.',
    );
  }

  ProductImportPackage _validateDirectWorkbook(ProductImportFile selectedFile) {
    if (selectedFile.bytes.isEmpty) {
      throw const ProductImportPackageException(
        'The selected Excel workbook is empty.',
      );
    }

    if (selectedFile.bytes.lengthInBytes > maximumWorkbookBytes) {
      throw const ProductImportPackageException(
        'The selected Excel workbook is too large.',
      );
    }

    return ProductImportPackage(
      sourceFileName: selectedFile.fileName,
      workbookFileName: selectedFile.fileName,
      workbookBytes: selectedFile.bytes,
      pictures: const <String, Uint8List>{},
      warnings: const <String>[
        'No picture package was supplied. '
            'Products without pictures will use '
            'the default placeholder.',
      ],
    );
  }

  ProductImportPackage _validateZipPackage(ProductImportFile selectedFile) {
    final Archive archive;

    try {
      archive = ZipDecoder().decodeBytes(selectedFile.bytes, verify: true);
    } catch (error) {
      throw ProductImportPackageException(
        'The selected ZIP file is invalid '
        'or corrupted: $error',
      );
    }

    if (archive.isEmpty) {
      throw const ProductImportPackageException(
        'The selected ZIP package is empty.',
      );
    }

    if (archive.length > maximumArchiveEntries) {
      throw const ProductImportPackageException(
        'The ZIP package contains too many files.',
      );
    }

    final workbooks = <ArchiveFile>[];
    final pictures = <String, Uint8List>{};
    final warnings = <String>[];

    var expandedBytes = 0;

    for (final entry in archive) {
      if (!entry.isFile) {
        continue;
      }

      final safeName = _safeArchiveName(entry.name);

      expandedBytes += entry.size;

      if (expandedBytes > maximumExpandedBytes) {
        throw const ProductImportPackageException(
          'The expanded ZIP package is too large.',
        );
      }

      final extension = _extension(safeName);

      if (extension == 'zip') {
        throw ProductImportPackageException(
          'Nested ZIP files are not allowed: '
          '$safeName',
        );
      }

      if (extension == 'xlsx') {
        workbooks.add(entry);
        continue;
      }

      if (ProductImportSchema.supportedImages.contains(extension)) {
        _indexPicture(
          entry: entry,
          safeName: safeName,
          pictures: pictures,
          warnings: warnings,
        );
      }
    }

    if (workbooks.isEmpty) {
      throw const ProductImportPackageException(
        'No XLSX workbook was found '
        'inside the ZIP package.',
      );
    }

    if (workbooks.length > 1) {
      throw const ProductImportPackageException(
        'The ZIP package must contain exactly '
        'one XLSX workbook.',
      );
    }

    final workbook = workbooks.single;

    if (workbook.size <= 0) {
      throw const ProductImportPackageException(
        'The Excel workbook inside the ZIP '
        'is empty.',
      );
    }

    if (workbook.size > maximumWorkbookBytes) {
      throw const ProductImportPackageException(
        'The Excel workbook inside the ZIP '
        'is too large.',
      );
    }

    final workbookBytes = _entryBytes(workbook);

    if (workbookBytes.isEmpty) {
      throw const ProductImportPackageException(
        'Unable to read the Excel workbook '
        'inside the ZIP package.',
      );
    }

    return ProductImportPackage(
      sourceFileName: selectedFile.fileName,
      workbookFileName: _baseName(workbook.name),
      workbookBytes: workbookBytes,
      pictures: Map<String, Uint8List>.unmodifiable(pictures),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  String _safeArchiveName(String originalName) {
    final normalized = originalName.replaceAll('\\', '/');

    if (normalized.trim().isEmpty) {
      throw const ProductImportPackageException(
        'The ZIP contains an empty filename.',
      );
    }

    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(normalized)) {
      throw ProductImportPackageException(
        'Absolute ZIP paths are not allowed: '
        '$originalName',
      );
    }

    if (normalized.split('/').contains('..')) {
      throw ProductImportPackageException(
        'Unsafe ZIP path detected: '
        '$originalName',
      );
    }

    return normalized;
  }

  void _indexPicture({
    required ArchiveFile entry,
    required String safeName,
    required Map<String, Uint8List> pictures,
    required List<String> warnings,
  }) {
    if (entry.size <= 0) {
      warnings.add('Ignored empty picture: $safeName');
      return;
    }

    if (entry.size > maximumPictureBytes) {
      warnings.add(
        'Ignored picture larger than '
        'the allowed limit: $safeName',
      );
      return;
    }

    final fileName = ProductImportSchema.normalizeFileName(safeName);

    if (!ProductImportSchema.isSupportedPicture(fileName)) {
      warnings.add(
        'Ignored unsupported picture: '
        '$safeName',
      );
      return;
    }

    if (pictures.containsKey(fileName)) {
      warnings.add(
        'Duplicate picture filename ignored: '
        '$fileName',
      );
      return;
    }

    final bytes = _entryBytes(entry);

    if (bytes.isEmpty) {
      warnings.add('Unable to read picture: $safeName');
      return;
    }

    pictures[fileName] = bytes;
  }

  Uint8List _entryBytes(ArchiveFile entry) {
    final content = entry.content;

    if (content is Uint8List) {
      return content;
    }

    if (content is List<int>) {
      return Uint8List.fromList(content);
    }

    return Uint8List(0);
  }

  String _extension(String fileName) {
    final name = _baseName(fileName).toLowerCase();

    final dot = name.lastIndexOf('.');

    if (dot < 0 || dot == name.length - 1) {
      return '';
    }

    return name.substring(dot + 1);
  }

  String _baseName(String fileName) {
    return fileName.replaceAll('\\', '/').split('/').last;
  }
}
