import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_import_file.dart';
import '../models/product_picture_update.dart';
import '../repositories/product_repository.dart';
import 'product_service.dart';

class ProductPictureUpdateParseException implements Exception {
  const ProductPictureUpdateParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductPictureUpdateParseService {
  ProductPictureUpdateParseService._();

  static final ProductPictureUpdateParseService instance =
      ProductPictureUpdateParseService._();

  static const int maximumArchiveEntries = 5000;

  static const int maximumPictureBytes = 10 * 1024 * 1024;

  static const int maximumExpandedBytes = 250 * 1024 * 1024;

  static const Set<String> supportedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  final ProductService _productService = ProductService();

  final ProductRepository _repository = ProductRepository.instance;

  Future<ProductPictureUpdatePackage> parse(
    ProductImportFile selectedFile,
  ) async {
    if (!selectedFile.isZip) {
      throw const ProductPictureUpdateParseException(
        'Product picture updates require '
        'a ZIP file.',
      );
    }

    final Archive archive;

    try {
      archive = ZipDecoder().decodeBytes(selectedFile.bytes, verify: true);
    } catch (error) {
      throw ProductPictureUpdateParseException(
        'The selected ZIP file is invalid '
        'or corrupted: $error',
      );
    }

    if (archive.isEmpty) {
      throw const ProductPictureUpdateParseException(
        'The selected ZIP file is empty.',
      );
    }

    if (archive.length > maximumArchiveEntries) {
      throw const ProductPictureUpdateParseException(
        'The ZIP contains too many files.',
      );
    }

    final products = await _loadProducts();

    final productsBySku = <String, Product>{
      for (final product in products)
        if (product.active && !product.isDeleted)
          product.sku.trim().toUpperCase(): product,
    };

    final validCandidates = <_PictureCandidate>[];

    final invalidItems = <ProductPictureUpdateItem>[];

    final warnings = <String>[];

    var expandedBytes = 0;

    for (final entry in archive) {
      if (!entry.isFile) {
        continue;
      }

      final safePath = _safeArchiveName(entry.name);

      expandedBytes += entry.size;

      if (expandedBytes > maximumExpandedBytes) {
        throw const ProductPictureUpdateParseException(
          'The expanded ZIP package is too large.',
        );
      }

      final extension = _extension(safePath);

      if (extension == 'zip') {
        throw ProductPictureUpdateParseException(
          'Nested ZIP files are not allowed: '
          '$safePath',
        );
      }

      if (!supportedExtensions.contains(extension)) {
        continue;
      }

      final fileName = _baseName(safePath);
      final sku = _skuFromFileName(fileName);

      if (entry.size <= 0) {
        invalidItems.add(
          ProductPictureUpdateItem(
            fileName: fileName,
            archivePath: safePath,
            normalizedSku: sku,
            bytes: Uint8List(0),
            matchStatus: ProductPictureMatchStatus.invalid,
            product: productsBySku[sku],
            message: 'The picture file is empty.',
          ),
        );

        continue;
      }

      if (entry.size > maximumPictureBytes) {
        invalidItems.add(
          ProductPictureUpdateItem(
            fileName: fileName,
            archivePath: safePath,
            normalizedSku: sku,
            bytes: Uint8List(0),
            matchStatus: ProductPictureMatchStatus.invalid,
            product: productsBySku[sku],
            message:
                'The picture exceeds the '
                '10 MB file limit.',
          ),
        );

        continue;
      }

      final bytes = _entryBytes(entry);

      if (bytes.isEmpty || !_isValidImage(bytes)) {
        invalidItems.add(
          ProductPictureUpdateItem(
            fileName: fileName,
            archivePath: safePath,
            normalizedSku: sku,
            bytes: bytes,
            matchStatus: ProductPictureMatchStatus.invalid,
            product: productsBySku[sku],
            message:
                'The file extension is supported, '
                'but the picture content is invalid.',
          ),
        );

        continue;
      }

      if (sku.isEmpty) {
        invalidItems.add(
          ProductPictureUpdateItem(
            fileName: fileName,
            archivePath: safePath,
            normalizedSku: '',
            bytes: bytes,
            matchStatus: ProductPictureMatchStatus.invalid,
            message:
                'The filename does not contain '
                'a usable SKU.',
          ),
        );

        continue;
      }

      validCandidates.add(
        _PictureCandidate(
          fileName: fileName,
          archivePath: safePath,
          normalizedSku: sku,
          bytes: bytes,
        ),
      );
    }

    if (validCandidates.isEmpty && invalidItems.isEmpty) {
      throw const ProductPictureUpdateParseException(
        'No JPG, JPEG, PNG, or WEBP pictures '
        'were found in the ZIP file.',
      );
    }

    final matchedItems = _matchCandidates(
      candidates: validCandidates,
      productsBySku: productsBySku,
    );

    final items = <ProductPictureUpdateItem>[...matchedItems, ...invalidItems];

    items.sort((first, second) {
      final skuCompare = first.normalizedSku.compareTo(second.normalizedSku);

      if (skuCompare != 0) {
        return skuCompare;
      }

      return first.fileName.toLowerCase().compareTo(
        second.fileName.toLowerCase(),
      );
    });

    if (productsBySku.isEmpty) {
      warnings.add(
        'No active products were available '
        'for SKU matching.',
      );
    }

    return ProductPictureUpdatePackage(
      fileName: selectedFile.fileName,
      items: List<ProductPictureUpdateItem>.unmodifiable(items),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<List<Product>> _loadProducts() async {
    return kIsWeb ? _productService.getProducts() : _repository.getProducts();
  }

  List<ProductPictureUpdateItem> _matchCandidates({
    required List<_PictureCandidate> candidates,
    required Map<String, Product> productsBySku,
  }) {
    final candidatesBySku = <String, List<_PictureCandidate>>{};

    for (final candidate in candidates) {
      candidatesBySku
          .putIfAbsent(candidate.normalizedSku, () => <_PictureCandidate>[])
          .add(candidate);
    }

    final items = <ProductPictureUpdateItem>[];

    for (final entry in candidatesBySku.entries) {
      final sku = entry.key;
      final skuCandidates = entry.value;
      final product = productsBySku[sku];

      if (skuCandidates.length > 1) {
        for (final candidate in skuCandidates) {
          items.add(
            ProductPictureUpdateItem(
              fileName: candidate.fileName,
              archivePath: candidate.archivePath,
              normalizedSku: sku,
              bytes: candidate.bytes,
              matchStatus: ProductPictureMatchStatus.duplicate,
              product: product,
              message:
                  'More than one picture was '
                  'supplied for SKU $sku.',
            ),
          );
        }

        continue;
      }

      final candidate = skuCandidates.single;

      if (product == null) {
        items.add(
          ProductPictureUpdateItem(
            fileName: candidate.fileName,
            archivePath: candidate.archivePath,
            normalizedSku: sku,
            bytes: candidate.bytes,
            matchStatus: ProductPictureMatchStatus.unmatched,
            message:
                'No active product was found '
                'for SKU $sku.',
          ),
        );

        continue;
      }

      items.add(
        ProductPictureUpdateItem(
          fileName: candidate.fileName,
          archivePath: candidate.archivePath,
          normalizedSku: sku,
          bytes: candidate.bytes,
          matchStatus: ProductPictureMatchStatus.matched,
          product: product,
          message:
              'The saved product picture '
              'will be replaced.',
        ),
      );
    }

    return items;
  }

  String _safeArchiveName(String originalName) {
    final normalized = originalName.replaceAll('\\', '/');

    if (normalized.trim().isEmpty) {
      throw const ProductPictureUpdateParseException(
        'The ZIP contains an empty filename.',
      );
    }

    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(normalized)) {
      throw ProductPictureUpdateParseException(
        'Absolute ZIP paths are not allowed: '
        '$originalName',
      );
    }

    if (normalized.split('/').contains('..')) {
      throw ProductPictureUpdateParseException(
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

  String _skuFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');

    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;

    return stem.trim().toUpperCase();
  }

  String _extension(String fileName) {
    final normalized = _baseName(fileName).toLowerCase();

    final dot = normalized.lastIndexOf('.');

    if (dot < 0 || dot == normalized.length - 1) {
      return '';
    }

    return normalized.substring(dot + 1);
  }

  String _baseName(String fileName) {
    return fileName.replaceAll('\\', '/').split('/').last;
  }
}

class _PictureCandidate {
  const _PictureCandidate({
    required this.fileName,
    required this.archivePath,
    required this.normalizedSku,
    required this.bytes,
  });

  final String fileName;
  final String archivePath;
  final String normalizedSku;
  final Uint8List bytes;
}
