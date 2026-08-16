import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/product_import_file.dart';
import '../models/product_update_package.dart';

class ProductUpdatePackageException implements Exception {
  const ProductUpdatePackageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductUpdatePackageService {
  ProductUpdatePackageService._();

  static final ProductUpdatePackageService instance =
      ProductUpdatePackageService._();

  static const int maximumArchiveEntries = 5000;

  static const int maximumWorkbookBytes = 25 * 1024 * 1024;

  static const int maximumPictureBytes = 10 * 1024 * 1024;

  static const int maximumExpandedBytes = 250 * 1024 * 1024;

  static const Set<String> supportedPictureExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  ProductUpdatePackage validate(ProductImportFile selectedFile) {
    if (selectedFile.isExcel) {
      return _validateWorkbook(selectedFile);
    }

    if (selectedFile.isZip) {
      return _validateZip(selectedFile);
    }

    throw const ProductUpdatePackageException(
      'Only XLSX and ZIP Product Update '
      'files are supported.',
    );
  }

  ProductUpdatePackage _validateWorkbook(ProductImportFile selectedFile) {
    if (selectedFile.bytes.isEmpty) {
      throw const ProductUpdatePackageException(
        'The selected Product Update '
        'workbook is empty.',
      );
    }

    if (selectedFile.bytes.lengthInBytes > maximumWorkbookBytes) {
      throw const ProductUpdatePackageException(
        'The selected Product Update '
        'workbook is too large.',
      );
    }

    return ProductUpdatePackage(
      sourceFileName: selectedFile.fileName,
      workbookFileName: selectedFile.fileName,
      workbookBytes: selectedFile.bytes,
      pictures: const <String, Uint8List>{},
      warnings: const <String>[
        'No Product_Pictures package was '
            'supplied. Existing product '
            'pictures will remain unchanged.',
      ],
    );
  }

  ProductUpdatePackage _validateZip(ProductImportFile selectedFile) {
    final Archive archive;

    try {
      archive = ZipDecoder().decodeBytes(selectedFile.bytes, verify: true);
    } catch (error) {
      throw ProductUpdatePackageException(
        'The selected Product Update ZIP '
        'is invalid or corrupted: $error',
      );
    }

    if (archive.isEmpty) {
      throw const ProductUpdatePackageException(
        'The selected Product Update ZIP '
        'is empty.',
      );
    }

    if (archive.length > maximumArchiveEntries) {
      throw const ProductUpdatePackageException(
        'The Product Update ZIP contains '
        'too many files.',
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

      final safePath = _safeArchiveName(entry.name);

      expandedBytes += entry.size;

      if (expandedBytes > maximumExpandedBytes) {
        throw const ProductUpdatePackageException(
          'The expanded Product Update ZIP '
          'is too large.',
        );
      }

      final extension = _extension(safePath);

      if (extension == 'zip') {
        throw ProductUpdatePackageException(
          'Nested ZIP files are not allowed: '
          '$safePath',
        );
      }

      if (extension == 'xlsx') {
        workbooks.add(entry);
        continue;
      }

      if (supportedPictureExtensions.contains(extension)) {
        _indexPicture(
          entry: entry,
          safePath: safePath,
          pictures: pictures,
          warnings: warnings,
        );
      }
    }

    if (workbooks.isEmpty) {
      throw const ProductUpdatePackageException(
        'No XLSX workbook was found inside '
        'the Product Update ZIP.',
      );
    }

    if (workbooks.length > 1) {
      throw const ProductUpdatePackageException(
        'The Product Update ZIP must contain '
        'exactly one XLSX workbook.',
      );
    }

    final workbook = workbooks.single;

    if (workbook.size <= 0) {
      throw const ProductUpdatePackageException(
        'The Product Update workbook inside '
        'the ZIP is empty.',
      );
    }

    if (workbook.size > maximumWorkbookBytes) {
      throw const ProductUpdatePackageException(
        'The Product Update workbook inside '
        'the ZIP is too large.',
      );
    }

    final workbookBytes = _entryBytes(workbook);

    if (workbookBytes.isEmpty) {
      throw const ProductUpdatePackageException(
        'Unable to read the Product Update '
        'workbook inside the ZIP.',
      );
    }

    return ProductUpdatePackage(
      sourceFileName: selectedFile.fileName,
      workbookFileName: _baseName(workbook.name),
      workbookBytes: workbookBytes,
      pictures: Map<String, Uint8List>.unmodifiable(pictures),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  void _indexPicture({
    required ArchiveFile entry,
    required String safePath,
    required Map<String, Uint8List> pictures,
    required List<String> warnings,
  }) {
    final fileName = ProductUpdatePackage.normalizeFileName(safePath);

    if (entry.size <= 0) {
      warnings.add('Ignored empty picture: $safePath');

      return;
    }

    if (entry.size > maximumPictureBytes) {
      warnings.add(
        'Ignored picture larger than '
        '10 MB: $safePath',
      );

      return;
    }

    if (pictures.containsKey(fileName)) {
      warnings.add(
        'Duplicate picture filename '
        'ignored: $fileName',
      );

      return;
    }

    final bytes = _entryBytes(entry);

    if (bytes.isEmpty || !_isValidImage(bytes)) {
      warnings.add('Ignored invalid picture: $safePath');

      return;
    }

    pictures[fileName] = bytes;
  }

  String _safeArchiveName(String originalName) {
    final normalized = originalName.replaceAll('\\', '/');

    if (normalized.trim().isEmpty) {
      throw const ProductUpdatePackageException(
        'The ZIP contains an empty filename.',
      );
    }

    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(normalized)) {
      throw ProductUpdatePackageException(
        'Absolute ZIP paths are not allowed: '
        '$originalName',
      );
    }

    if (normalized.split('/').contains('..')) {
      throw ProductUpdatePackageException(
        'Unsafe ZIP path detected: '
        '$originalName',
      );
    }

    return normalized;
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

  bool _isValidImage(Uint8List bytes) {
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;

    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;

    final webp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    return jpeg || png || webp;
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
