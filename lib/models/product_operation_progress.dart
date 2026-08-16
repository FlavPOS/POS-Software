import 'package:flutter/foundation.dart';

enum ProductOperationProgressStatus { preparing, running, completed, failed }

@immutable
class ProductOperationProgress {
  const ProductOperationProgress({
    required this.title,
    required this.completed,
    required this.total,
    this.unitLabel = 'products',
    this.currentItem,
    this.detail,
    this.status = ProductOperationProgressStatus.running,
    this.errorMessage,
  });

  const ProductOperationProgress.preparing({
    required this.title,
    this.unitLabel = 'products',
    this.detail,
  }) : completed = 0,
       total = 0,
       currentItem = null,
       status = ProductOperationProgressStatus.preparing,
       errorMessage = null;

  final String title;
  final int completed;
  final int total;
  final String unitLabel;
  final String? currentItem;
  final String? detail;
  final ProductOperationProgressStatus status;
  final String? errorMessage;

  bool get hasKnownTotal {
    return total > 0;
  }

  bool get isIndeterminate {
    return status == ProductOperationProgressStatus.preparing || !hasKnownTotal;
  }

  bool get isComplete {
    return status == ProductOperationProgressStatus.completed;
  }

  bool get hasFailed {
    return status == ProductOperationProgressStatus.failed;
  }

  int get safeCompleted {
    if (completed < 0) {
      return 0;
    }

    if (hasKnownTotal && completed > total) {
      return total;
    }

    return completed;
  }

  double? get progressValue {
    if (isIndeterminate) {
      return null;
    }

    return safeCompleted / total;
  }

  int? get percentage {
    final value = progressValue;

    if (value == null) {
      return null;
    }

    return (value * 100).round();
  }

  String get countLabel {
    if (!hasKnownTotal) {
      return 'Preparing $unitLabel...';
    }

    return '$safeCompleted of $total '
        '$unitLabel completed';
  }

  String get percentageLabel {
    final value = percentage;

    if (value == null) {
      return 'Preparing...';
    }

    return '$value%';
  }

  ProductOperationProgress copyWith({
    String? title,
    int? completed,
    int? total,
    String? unitLabel,
    String? currentItem,
    bool clearCurrentItem = false,
    String? detail,
    bool clearDetail = false,
    ProductOperationProgressStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ProductOperationProgress(
      title: title ?? this.title,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      unitLabel: unitLabel ?? this.unitLabel,
      currentItem: clearCurrentItem ? null : currentItem ?? this.currentItem,
      detail: clearDetail ? null : detail ?? this.detail,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class ProductOperationProgressController
    extends ValueNotifier<ProductOperationProgress> {
  ProductOperationProgressController({
    required String title,
    String unitLabel = 'products',
    String? detail,
  }) : super(
         ProductOperationProgress.preparing(
           title: title,
           unitLabel: unitLabel,
           detail: detail,
         ),
       );

  void start({required int total, String? currentItem, String? detail}) {
    value = value.copyWith(
      completed: 0,
      total: total < 0 ? 0 : total,
      currentItem: currentItem,
      clearCurrentItem: currentItem == null,
      detail: detail,
      clearDetail: detail == null,
      status: ProductOperationProgressStatus.running,
      clearErrorMessage: true,
    );
  }

  void update({required int completed, String? currentItem, String? detail}) {
    value = value.copyWith(
      completed: completed,
      currentItem: currentItem,
      clearCurrentItem: currentItem == null,
      detail: detail,
      clearDetail: detail == null,
      status: ProductOperationProgressStatus.running,
      clearErrorMessage: true,
    );
  }

  void complete({String? detail}) {
    value = value.copyWith(
      completed: value.total,
      detail: detail,
      clearDetail: detail == null,
      status: ProductOperationProgressStatus.completed,
      clearCurrentItem: true,
      clearErrorMessage: true,
    );
  }

  void fail({required Object error, String? detail}) {
    value = value.copyWith(
      detail: detail,
      clearDetail: detail == null,
      status: ProductOperationProgressStatus.failed,
      errorMessage: error.toString(),
      clearCurrentItem: true,
    );
  }
}
