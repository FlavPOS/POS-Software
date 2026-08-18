import 'inventory_core.dart';

class InventoryAdjustmentValidationException implements Exception {
  const InventoryAdjustmentValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InventoryAdjustmentItem {
  const InventoryAdjustmentItem({
    required this.id,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.currentOnHand,
    required this.costPrice,
    required this.adjustmentQuantity,
    required this.direction,
    this.remarks,
  });

  final String id;
  final String productId;
  final String sku;
  final String productName;

  final int currentOnHand;
  final double costPrice;
  final int adjustmentQuantity;

  final AdjustmentDirection direction;
  final String? remarks;

  int get quantityIn {
    return direction == AdjustmentDirection.increase ? adjustmentQuantity : 0;
  }

  int get quantityOut {
    return direction == AdjustmentDirection.decrease ? adjustmentQuantity : 0;
  }

  double get adjustmentAmount {
    return InventoryCostRules.adjustmentValue(
      adjustmentQuantity: adjustmentQuantity,
      costPrice: costPrice,
    );
  }

  int get newOnHand {
    return InventoryCostRules.newOnHandForAdjustment(
      currentOnHand: currentOnHand,
      adjustmentQuantity: adjustmentQuantity,
      direction: direction,
    );
  }

  String get normalizedSku {
    return sku.trim().toUpperCase();
  }

  void validate({bool allowNegativeInventory = false}) {
    if (id.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment Item ID is required.',
      );
    }

    if (productId.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Product ID is required.',
      );
    }

    if (normalizedSku.isEmpty) {
      throw const InventoryAdjustmentValidationException('SKU is required.');
    }

    if (productName.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Product Name is required.',
      );
    }

    if (currentOnHand < 0) {
      throw const InventoryAdjustmentValidationException(
        'Current OH cannot be negative.',
      );
    }

    if (!costPrice.isFinite || costPrice < 0) {
      throw const InventoryAdjustmentValidationException(
        'Cost Price must be a valid '
        'non-negative value.',
      );
    }

    if (adjustmentQuantity <= 0) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment Qty must be greater '
        'than zero.',
      );
    }

    try {
      InventoryCostRules.newOnHandForAdjustment(
        currentOnHand: currentOnHand,
        adjustmentQuantity: adjustmentQuantity,
        direction: direction,
        allowNegativeInventory: allowNegativeInventory,
      );
    } on InventoryValidationException catch (error) {
      throw InventoryAdjustmentValidationException(error.message);
    }
  }

  InventoryAdjustmentItem copyWith({
    String? id,
    String? productId,
    String? sku,
    String? productName,
    int? currentOnHand,
    double? costPrice,
    int? adjustmentQuantity,
    AdjustmentDirection? direction,
    String? remarks,
    bool clearRemarks = false,
  }) {
    final updated = InventoryAdjustmentItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      productName: productName ?? this.productName,
      currentOnHand: currentOnHand ?? this.currentOnHand,
      costPrice: costPrice ?? this.costPrice,
      adjustmentQuantity: adjustmentQuantity ?? this.adjustmentQuantity,
      direction: direction ?? this.direction,
      remarks: clearRemarks ? null : remarks ?? this.remarks,
    );

    updated.validate();

    return updated;
  }

  Map<String, Object?> toMap() {
    validate();

    return <String, Object?>{
      'id': id.trim(),
      'productId': productId.trim(),
      'sku': normalizedSku,
      'productName': productName.trim(),
      'currentOnHand': currentOnHand,
      'costPrice': costPrice,
      'adjustmentQuantity': adjustmentQuantity,
      'quantityIn': quantityIn,
      'quantityOut': quantityOut,
      'adjustmentAmount': adjustmentAmount,
      'newOnHand': newOnHand,
      'direction': direction.databaseValue,
      'remarks': _normalizedText(remarks),
    };
  }

  factory InventoryAdjustmentItem.fromMap(
    Map<Object?, Object?> map, {
    String? fallbackId,
  }) {
    final item = InventoryAdjustmentItem(
      id: _text(map['id']).isNotEmpty
          ? _text(map['id'])
          : fallbackId?.trim() ?? '',
      productId: _text(map['productId']),
      sku: _text(map['sku']),
      productName: _text(map['productName']),
      currentOnHand: _integer(map['currentOnHand']),
      costPrice: _decimal(map['costPrice']),
      adjustmentQuantity: _integer(map['adjustmentQuantity']),
      direction: AdjustmentDirectionValue.fromDatabase(map['direction']),
      remarks: _optionalText(map['remarks']),
    );

    item.validate();

    return item;
  }

  static String _text(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _optionalText(Object? value) {
    final result = _text(value);

    return result.isEmpty ? null : result;
  }

  static String? _normalizedText(String? value) {
    final result = value?.trim() ?? '';

    return result.isEmpty ? null : result;
  }

  static int _integer(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _decimal(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class InventoryAdjustment {
  const InventoryAdjustment({
    required this.id,
    required this.adjustmentNumber,
    required this.adjustmentDate,
    required this.adjustmentTypeId,
    required this.adjustmentTypeName,
    required this.direction,
    required this.status,
    required this.items,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
    this.remarks,
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionRemarks,
    this.inventoryProcessed = false,
    this.inventoryProcessingId,
    this.inventoryProcessedAt,
  });

  final String id;
  final String adjustmentNumber;
  final int adjustmentDate;

  final String adjustmentTypeId;
  final String adjustmentTypeName;
  final AdjustmentDirection direction;

  final InventoryDocumentStatus status;
  final List<InventoryAdjustmentItem> items;

  final String? remarks;

  final String createdBy;
  final int createdAt;
  final String updatedBy;
  final int updatedAt;

  final String? submittedBy;
  final int? submittedAt;

  final String? approvedBy;
  final int? approvedAt;

  final String? rejectedBy;
  final int? rejectedAt;
  final String? rejectionRemarks;

  final bool inventoryProcessed;
  final String? inventoryProcessingId;
  final int? inventoryProcessedAt;

  String get normalizedAdjustmentNumber {
    return adjustmentNumber.trim().toUpperCase();
  }

  int get totalSkus {
    return items.length;
  }

  int get totalQuantity {
    return items.fold<int>(0, (total, item) => total + item.adjustmentQuantity);
  }

  int get totalQuantityIn {
    return items.fold<int>(0, (total, item) => total + item.quantityIn);
  }

  int get totalQuantityOut {
    return items.fold<int>(0, (total, item) => total + item.quantityOut);
  }

  double get totalAdjustmentValueAtCost {
    return items.fold<double>(
      0,
      (total, item) => total + item.adjustmentAmount,
    );
  }

  bool get canEdit {
    return status.canEdit;
  }

  bool get canSubmit {
    return status == InventoryDocumentStatus.draft && items.isNotEmpty;
  }

  bool get canApprove {
    return status == InventoryDocumentStatus.submitted && !inventoryProcessed;
  }

  bool get canReject {
    return status == InventoryDocumentStatus.submitted;
  }

  bool get isEligibleForInventoryProcessing {
    return status == InventoryDocumentStatus.approved && !inventoryProcessed;
  }

  bool get isInventoryProcessingComplete {
    return status == InventoryDocumentStatus.approved && inventoryProcessed;
  }

  void validate({
    bool allowEmptyDraft = false,
    bool allowNegativeInventory = false,
  }) {
    if (id.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment ID is required.',
      );
    }

    if (normalizedAdjustmentNumber.isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment Number is required.',
      );
    }

    if (adjustmentDate <= 0) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment Date is required.',
      );
    }

    if (adjustmentTypeId.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment Type is required.',
      );
    }

    if (adjustmentTypeName.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment Type Name is required.',
      );
    }

    if (!allowEmptyDraft || status != InventoryDocumentStatus.draft) {
      if (items.isEmpty) {
        throw const InventoryAdjustmentValidationException(
          'At least one Adjustment item '
          'is required.',
        );
      }
    }

    final itemIds = <String>{};
    final productIds = <String>{};
    final skus = <String>{};

    for (final item in items) {
      item.validate(allowNegativeInventory: allowNegativeInventory);

      if (item.direction != direction) {
        throw const InventoryAdjustmentValidationException(
          'All Adjustment items must use '
          'the document direction.',
        );
      }

      if (!itemIds.add(item.id.trim())) {
        throw InventoryAdjustmentValidationException(
          'Duplicate Adjustment Item ID: '
          '${item.id}.',
        );
      }

      if (!productIds.add(item.productId.trim())) {
        throw InventoryAdjustmentValidationException(
          'The same product cannot be added '
          'more than once.',
        );
      }

      if (!skus.add(item.normalizedSku)) {
        throw InventoryAdjustmentValidationException(
          'Duplicate SKU: '
          '${item.normalizedSku}.',
        );
      }
    }

    if (createdBy.trim().isEmpty || updatedBy.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Created By and Updated By '
        'are required.',
      );
    }

    if (createdAt <= 0 || updatedAt <= 0) {
      throw const InventoryAdjustmentValidationException(
        'Created Date and Updated Date '
        'are required.',
      );
    }

    if (updatedAt < createdAt) {
      throw const InventoryAdjustmentValidationException(
        'Updated Date cannot be earlier '
        'than Created Date.',
      );
    }

    _validateWorkflowAudit();

    if (inventoryProcessed) {
      if (status != InventoryDocumentStatus.approved) {
        throw const InventoryAdjustmentValidationException(
          'Only an Approved Adjustment '
          'can be inventory processed.',
        );
      }

      if ((inventoryProcessingId ?? '').trim().isEmpty) {
        throw const InventoryAdjustmentValidationException(
          'Inventory Processing ID '
          'is required.',
        );
      }

      if ((inventoryProcessedAt ?? 0) <= 0) {
        throw const InventoryAdjustmentValidationException(
          'Inventory Processed Date '
          'is required.',
        );
      }
    } else if (inventoryProcessingId != null || inventoryProcessedAt != null) {
      throw const InventoryAdjustmentValidationException(
        'Unprocessed Adjustment cannot '
        'contain processing audit values.',
      );
    }
  }

  void _validateWorkflowAudit() {
    switch (status) {
      case InventoryDocumentStatus.draft:
        if (submittedBy != null ||
            submittedAt != null ||
            approvedBy != null ||
            approvedAt != null ||
            rejectedBy != null ||
            rejectedAt != null ||
            rejectionRemarks != null) {
          throw const InventoryAdjustmentValidationException(
            'Draft Adjustment cannot contain '
            'approval audit values.',
          );
        }

      case InventoryDocumentStatus.submitted:
        if ((submittedBy ?? '').trim().isEmpty || (submittedAt ?? 0) <= 0) {
          throw const InventoryAdjustmentValidationException(
            'Submitted By and Submitted Date '
            'are required.',
          );
        }

        if (approvedBy != null ||
            approvedAt != null ||
            rejectedBy != null ||
            rejectedAt != null ||
            rejectionRemarks != null) {
          throw const InventoryAdjustmentValidationException(
            'Submitted Adjustment cannot contain '
            'approval or rejection values.',
          );
        }

      case InventoryDocumentStatus.approved:
        if ((submittedBy ?? '').trim().isEmpty ||
            (submittedAt ?? 0) <= 0 ||
            (approvedBy ?? '').trim().isEmpty ||
            (approvedAt ?? 0) <= 0) {
          throw const InventoryAdjustmentValidationException(
            'Submitted and Approved audit '
            'values are required.',
          );
        }

        if (rejectedBy != null ||
            rejectedAt != null ||
            rejectionRemarks != null) {
          throw const InventoryAdjustmentValidationException(
            'Approved Adjustment cannot contain '
            'rejection values.',
          );
        }

      case InventoryDocumentStatus.rejected:
        if ((submittedBy ?? '').trim().isEmpty ||
            (submittedAt ?? 0) <= 0 ||
            (rejectedBy ?? '').trim().isEmpty ||
            (rejectedAt ?? 0) <= 0 ||
            (rejectionRemarks ?? '').trim().isEmpty) {
          throw const InventoryAdjustmentValidationException(
            'Submitted and Rejected audit '
            'values are required.',
          );
        }

        if (approvedBy != null || approvedAt != null) {
          throw const InventoryAdjustmentValidationException(
            'Rejected Adjustment cannot contain '
            'approval values.',
          );
        }
    }
  }

  InventoryAdjustment copyWith({
    String? id,
    String? adjustmentNumber,
    int? adjustmentDate,
    String? adjustmentTypeId,
    String? adjustmentTypeName,
    AdjustmentDirection? direction,
    InventoryDocumentStatus? status,
    List<InventoryAdjustmentItem>? items,
    String? remarks,
    bool clearRemarks = false,
    String? createdBy,
    int? createdAt,
    String? updatedBy,
    int? updatedAt,
    String? submittedBy,
    int? submittedAt,
    bool clearSubmittedAudit = false,
    String? approvedBy,
    int? approvedAt,
    bool clearApprovedAudit = false,
    String? rejectedBy,
    int? rejectedAt,
    String? rejectionRemarks,
    bool clearRejectedAudit = false,
    bool? inventoryProcessed,
    String? inventoryProcessingId,
    int? inventoryProcessedAt,
    bool clearProcessingAudit = false,
  }) {
    return InventoryAdjustment(
      id: id ?? this.id,
      adjustmentNumber: adjustmentNumber ?? this.adjustmentNumber,
      adjustmentDate: adjustmentDate ?? this.adjustmentDate,
      adjustmentTypeId: adjustmentTypeId ?? this.adjustmentTypeId,
      adjustmentTypeName: adjustmentTypeName ?? this.adjustmentTypeName,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      items: List<InventoryAdjustmentItem>.unmodifiable(items ?? this.items),
      remarks: clearRemarks ? null : remarks ?? this.remarks,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedBy: clearSubmittedAudit ? null : submittedBy ?? this.submittedBy,
      submittedAt: clearSubmittedAudit ? null : submittedAt ?? this.submittedAt,
      approvedBy: clearApprovedAudit ? null : approvedBy ?? this.approvedBy,
      approvedAt: clearApprovedAudit ? null : approvedAt ?? this.approvedAt,
      rejectedBy: clearRejectedAudit ? null : rejectedBy ?? this.rejectedBy,
      rejectedAt: clearRejectedAudit ? null : rejectedAt ?? this.rejectedAt,
      rejectionRemarks: clearRejectedAudit
          ? null
          : rejectionRemarks ?? this.rejectionRemarks,
      inventoryProcessed: inventoryProcessed ?? this.inventoryProcessed,
      inventoryProcessingId: clearProcessingAudit
          ? null
          : inventoryProcessingId ?? this.inventoryProcessingId,
      inventoryProcessedAt: clearProcessingAudit
          ? null
          : inventoryProcessedAt ?? this.inventoryProcessedAt,
    );
  }

  InventoryAdjustment submit({required String userId, required int timestamp}) {
    if (!canSubmit) {
      throw const InventoryAdjustmentValidationException(
        'Only a Draft Adjustment with items '
        'can be submitted.',
      );
    }

    final submitted = copyWith(
      status: InventoryDocumentStatus.submitted,
      updatedBy: userId,
      updatedAt: timestamp,
      submittedBy: userId,
      submittedAt: timestamp,
    );

    submitted.validate();

    return submitted;
  }

  InventoryAdjustment approve({
    required String userId,
    required int timestamp,
  }) {
    if (!canApprove) {
      throw const InventoryAdjustmentValidationException(
        'Only an unprocessed Submitted '
        'Adjustment can be approved.',
      );
    }

    final approved = copyWith(
      status: InventoryDocumentStatus.approved,
      updatedBy: userId,
      updatedAt: timestamp,
      approvedBy: userId,
      approvedAt: timestamp,
    );

    approved.validate();

    return approved;
  }

  InventoryAdjustment reject({
    required String userId,
    required int timestamp,
    required String reason,
  }) {
    if (!canReject) {
      throw const InventoryAdjustmentValidationException(
        'Only a Submitted Adjustment '
        'can be rejected.',
      );
    }

    if (reason.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Rejection Remarks are required.',
      );
    }

    final rejected = copyWith(
      status: InventoryDocumentStatus.rejected,
      updatedBy: userId,
      updatedAt: timestamp,
      rejectedBy: userId,
      rejectedAt: timestamp,
      rejectionRemarks: reason.trim(),
    );

    rejected.validate();

    return rejected;
  }

  InventoryAdjustment markInventoryProcessed({
    required String processingId,
    required int timestamp,
    required String userId,
  }) {
    if (!isEligibleForInventoryProcessing) {
      throw const InventoryAdjustmentValidationException(
        'Adjustment is not eligible for '
        'inventory processing.',
      );
    }

    if (processingId.trim().isEmpty) {
      throw const InventoryAdjustmentValidationException(
        'Inventory Processing ID is required.',
      );
    }

    final processed = copyWith(
      inventoryProcessed: true,
      inventoryProcessingId: processingId.trim(),
      inventoryProcessedAt: timestamp,
      updatedBy: userId,
      updatedAt: timestamp,
    );

    processed.validate();

    return processed;
  }

  Map<String, Object?> toMap() {
    validate();

    return <String, Object?>{
      'id': id.trim(),
      'adjustmentNumber': normalizedAdjustmentNumber,
      'adjustmentDate': adjustmentDate,
      'adjustmentTypeId': adjustmentTypeId.trim(),
      'adjustmentTypeName': adjustmentTypeName.trim(),
      'direction': direction.databaseValue,
      'status': status.databaseValue,
      'remarks': _normalizedText(remarks),
      'totalSkus': totalSkus,
      'totalQuantity': totalQuantity,
      'totalQuantityIn': totalQuantityIn,
      'totalQuantityOut': totalQuantityOut,
      'totalAdjustmentValueAtCost': totalAdjustmentValueAtCost,
      'createdBy': createdBy.trim(),
      'createdAt': createdAt,
      'updatedBy': updatedBy.trim(),
      'updatedAt': updatedAt,
      'submittedBy': _normalizedText(submittedBy),
      'submittedAt': submittedAt,
      'approvedBy': _normalizedText(approvedBy),
      'approvedAt': approvedAt,
      'rejectedBy': _normalizedText(rejectedBy),
      'rejectedAt': rejectedAt,
      'rejectionRemarks': _normalizedText(rejectionRemarks),
      'inventoryProcessed': inventoryProcessed,
      'inventoryProcessingId': _normalizedText(inventoryProcessingId),
      'inventoryProcessedAt': inventoryProcessedAt,
      'items': <String, Object?>{
        for (final item in items) item.id: item.toMap(),
      },
    };
  }

  factory InventoryAdjustment.fromMap(
    Map<Object?, Object?> map, {
    String? fallbackId,
  }) {
    final rawItems = map['items'];
    final items = <InventoryAdjustmentItem>[];

    if (rawItems is Map) {
      for (final entry in rawItems.entries) {
        final value = entry.value;

        if (value is Map) {
          items.add(
            InventoryAdjustmentItem.fromMap(
              Map<Object?, Object?>.from(value),
              fallbackId: entry.key.toString(),
            ),
          );
        }
      }
    }

    final adjustment = InventoryAdjustment(
      id: _text(map['id']).isNotEmpty
          ? _text(map['id'])
          : fallbackId?.trim() ?? '',
      adjustmentNumber: _text(map['adjustmentNumber']),
      adjustmentDate: _integer(map['adjustmentDate']),
      adjustmentTypeId: _text(map['adjustmentTypeId']),
      adjustmentTypeName: _text(map['adjustmentTypeName']),
      direction: AdjustmentDirectionValue.fromDatabase(map['direction']),
      status: InventoryDocumentStatusValue.fromDatabase(map['status']),
      items: List<InventoryAdjustmentItem>.unmodifiable(items),
      remarks: _optionalText(map['remarks']),
      createdBy: _text(map['createdBy']),
      createdAt: _integer(map['createdAt']),
      updatedBy: _text(map['updatedBy']),
      updatedAt: _integer(map['updatedAt']),
      submittedBy: _optionalText(map['submittedBy']),
      submittedAt: _nullableInteger(map['submittedAt']),
      approvedBy: _optionalText(map['approvedBy']),
      approvedAt: _nullableInteger(map['approvedAt']),
      rejectedBy: _optionalText(map['rejectedBy']),
      rejectedAt: _nullableInteger(map['rejectedAt']),
      rejectionRemarks: _optionalText(map['rejectionRemarks']),
      inventoryProcessed: _boolean(map['inventoryProcessed']),
      inventoryProcessingId: _optionalText(map['inventoryProcessingId']),
      inventoryProcessedAt: _nullableInteger(map['inventoryProcessedAt']),
    );

    adjustment.validate();

    return adjustment;
  }

  static String _text(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _optionalText(Object? value) {
    final result = _text(value);

    return result.isEmpty ? null : result;
  }

  static String? _normalizedText(String? value) {
    final result = value?.trim() ?? '';

    return result.isEmpty ? null : result;
  }

  static int _integer(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInteger(Object? value) {
    if (value == null) {
      return null;
    }

    return _integer(value);
  }

  static bool _boolean(Object? value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }
}
