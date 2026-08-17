import 'package:flutter/foundation.dart';

@immutable
class ProductPictureOptimizationResult {
  ProductPictureOptimizationResult({
    required Uint8List bytes,
    required this.fileName,
    required this.mimeType,
    required this.originalWidth,
    required this.originalHeight,
    required this.optimizedWidth,
    required this.optimizedHeight,
    required this.originalBytes,
    required this.optimizedBytes,
    required this.jpegQuality,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;

  final String fileName;
  final String mimeType;

  final int originalWidth;
  final int originalHeight;

  final int optimizedWidth;
  final int optimizedHeight;

  final int originalBytes;
  final int optimizedBytes;

  final int jpegQuality;

  bool get isEmpty {
    return bytes.isEmpty;
  }

  bool get isNotEmpty {
    return bytes.isNotEmpty;
  }

  bool get wasResized {
    return originalWidth != optimizedWidth || originalHeight != optimizedHeight;
  }

  bool get wasReduced {
    return optimizedBytes < originalBytes;
  }

  int get bytesSaved {
    final saved = originalBytes - optimizedBytes;

    return saved < 0 ? 0 : saved;
  }

  double get sizeRatio {
    if (originalBytes <= 0) {
      return 0;
    }

    return optimizedBytes / originalBytes;
  }

  double get reductionPercentage {
    if (originalBytes <= 0) {
      return 0;
    }

    final percentage = (1 - sizeRatio) * 100;

    if (percentage < 0) {
      return 0;
    }

    if (percentage > 100) {
      return 100;
    }

    return percentage;
  }

  String get reductionPercentageLabel {
    return '${reductionPercentage.toStringAsFixed(1)}%';
  }

  int get longestOriginalSide {
    return originalWidth >= originalHeight ? originalWidth : originalHeight;
  }

  int get longestOptimizedSide {
    return optimizedWidth >= optimizedHeight ? optimizedWidth : optimizedHeight;
  }

  bool get isSquare {
    return optimizedWidth == optimizedHeight;
  }

  bool get isMasterSize {
    return optimizedWidth == 600 && optimizedHeight == 600;
  }

  bool get isThumbnailSize {
    return optimizedWidth == 240 && optimizedHeight == 240;
  }

  bool get isWithinOneMegabyte {
    return optimizedBytes <= 1024 * 1024;
  }

  double get originalMegabytes {
    return originalBytes / (1024 * 1024);
  }

  double get optimizedMegabytes {
    return optimizedBytes / (1024 * 1024);
  }

  String get originalSizeLabel {
    return _formatBytes(originalBytes);
  }

  String get optimizedSizeLabel {
    return _formatBytes(optimizedBytes);
  }

  String get bytesSavedLabel {
    return _formatBytes(bytesSaved);
  }

  String get originalDimensionsLabel {
    return '$originalWidth × '
        '$originalHeight';
  }

  String get optimizedDimensionsLabel {
    return '$optimizedWidth × '
        '$optimizedHeight';
  }

  String get summary {
    return 'Original: '
        '$originalDimensionsLabel, '
        '$originalSizeLabel | '
        'Optimized: '
        '$optimizedDimensionsLabel, '
        '$optimizedSizeLabel | '
        'Reduced: '
        '$reductionPercentageLabel';
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'fileName': fileName,
      'mimeType': mimeType,
      'originalWidth': originalWidth,
      'originalHeight': originalHeight,
      'optimizedWidth': optimizedWidth,
      'optimizedHeight': optimizedHeight,
      'originalBytes': originalBytes,
      'optimizedBytes': optimizedBytes,
      'bytesSaved': bytesSaved,
      'jpegQuality': jpegQuality,
      'reductionPercentage': reductionPercentage,
    };
  }

  String _formatBytes(int value) {
    if (value <= 0) {
      return '0 B';
    }

    if (value < 1024) {
      return '$value B';
    }

    final kilobytes = value / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;

    return '${megabytes.toStringAsFixed(2)} MB';
  }

  @override
  String toString() {
    return 'ProductPictureOptimizationResult('
        'fileName: $fileName, '
        'mimeType: $mimeType, '
        'original: '
        '$originalDimensionsLabel, '
        'optimized: '
        '$optimizedDimensionsLabel, '
        'originalSize: '
        '$originalSizeLabel, '
        'optimizedSize: '
        '$optimizedSizeLabel, '
        'reduction: '
        '$reductionPercentageLabel, '
        'quality: $jpegQuality'
        ')';
  }
}
