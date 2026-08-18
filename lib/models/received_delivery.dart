import 'inventory_core.dart';

class ReceivedDeliveryValidationException implements Exception {
  const ReceivedDeliveryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceivedDeliveryItem {
  const ReceivedDeliveryItem({
    required this.id,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.currentOnHand,
    required this.orderedQuantity,
    required this.receivedQuantity,
    required this.costPrice,
    this.lotBatchNumber,
    this.expiryDate,
    this.remarks,
  });

  final String id;
  final String productId;
  final String sku;
  final String productName;

  final int currentOnHand;
  final int orderedQuantity;
  final int receivedQuantity;

  final double costPrice;

  final String? lotBatchNumber;
  final int? expiryDate;
  final String? remarks;

  String get normalizedSku {
    return sku.trim().toUpperCase();
  }

  String? get normalizedLotBatchNumber {
    return _normalizedText(lotBatchNumber);
  }

  double get totalCost {
    return InventoryCostRules.deliveryValue(
      receivedQuantity: receivedQuantity,
      costPrice: costPrice,
    );
  }

  int get newOnHand {
    return InventoryCostRules.newOnHandForDelivery(
      currentOnHand: currentOnHand,
      receivedQuantity: receivedQuantity,
    );
  }

  int get quantityIn {
    return receivedQuantity;
  }

  int get quantityOut {
    return 0;
  }

  bool get isFullyReceived {
    return receivedQuantity == orderedQuantity;
  }

  bool get isPartiallyReceived {
    return receivedQuantity > 0 && receivedQuantity < orderedQuantity;
  }

  bool get isNotReceived {
    return receivedQuantity == 0;
  }

  void validate({bool allowOverReceipt = false}) {
    if (id.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
        'Received Delivery Item ID is required.',
      );
    }

    if (productId.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
        'Product ID is required.',
      );
    }

    if (normalizedSku.isEmpty) {
      throw const ReceivedDeliveryValidationException('SKU is required.');
    }

    if (productName.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
        'Product Name is required.',
      );
    }

    if (currentOnHand < 0) {
      throw const ReceivedDeliveryValidationException(
        'Current OH cannot be negative.',
      );
    }

    if (orderedQuantity < 0) {
      throw const ReceivedDeliveryValidationException(
        'Ordered Qty cannot be negative.',
      );
    }

    if (receivedQuantity < 0) {
      throw const ReceivedDeliveryValidationException(
        'Received Qty cannot be negative.',
      );
    }

    if (!allowOverReceipt && receivedQuantity > orderedQuantity) {
      throw ReceivedDeliveryValidationException(
        'Received Qty cannot exceed '
        'Ordered Qty. Ordered Qty is only '
        '$orderedQuantity.',
      );
    }

    if (!costPrice.isFinite || costPrice < 0) {
      throw const ReceivedDeliveryValidationException(
        'Cost Price must be a valid '
        'non-negative value.',
      );
    }

    if (expiryDate != null && expiryDate! <= 0) {
      throw const ReceivedDeliveryValidationException(
        'Expiry Date is invalid.',
      );
    }

    try {
      InventoryCostRules.deliveryValue(
        receivedQuantity: receivedQuantity,
        costPrice: costPrice,
      );

      InventoryCostRules.newOnHandForDelivery(
        currentOnHand: currentOnHand,
        receivedQuantity: receivedQuantity,
      );
    } on InventoryValidationException catch (error) {
      throw ReceivedDeliveryValidationException(error.message);
    }
  }

  ReceivedDeliveryItem copyWith({
    String? id,
    String? productId,
    String? sku,
    String? productName,
    int? currentOnHand,
    int? orderedQuantity,
    int? receivedQuantity,
    double? costPrice,
    String? lotBatchNumber,
    bool clearLotBatchNumber = false,
    int? expiryDate,
    bool clearExpiryDate = false,
    String? remarks,
    bool clearRemarks = false,
  }) {
    final updated = ReceivedDeliveryItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      productName: productName ?? this.productName,
      currentOnHand: currentOnHand ?? this.currentOnHand,
      orderedQuantity: orderedQuantity ?? this.orderedQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      costPrice: costPrice ?? this.costPrice,
      lotBatchNumber: clearLotBatchNumber
          ? null
          : lotBatchNumber ?? this.lotBatchNumber,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
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
      'orderedQuantity': orderedQuantity,
      'receivedQuantity': receivedQuantity,
      'quantityIn': quantityIn,
      'quantityOut': quantityOut,
      'costPrice': costPrice,
      'totalCost': totalCost,
      'newOnHand': newOnHand,
      'lotBatchNumber': normalizedLotBatchNumber,
      'expiryDate': expiryDate,
      'remarks': _normalizedText(remarks),
    };
  }

  factory ReceivedDeliveryItem.fromMap(
    Map<Object?, Object?> map, {
    String? fallbackId,
  }) {
    final item = ReceivedDeliveryItem(
      id: _text(map['id']).isNotEmpty
          ? _text(map['id'])
          : fallbackId?.trim() ?? '',
      productId: _text(map['productId']),
      sku: _text(map['sku']),
      productName: _text(map['productName']),
      currentOnHand: _integer(map['currentOnHand']),
      orderedQuantity: _integer(map['orderedQuantity']),
      receivedQuantity: _integer(map['receivedQuantity']),
      costPrice: _decimal(map['costPrice']),
      lotBatchNumber: _optionalText(map['lotBatchNumber']),
      expiryDate: _nullableInteger(map['expiryDate']),
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

  static int? _nullableInteger(Object? value) {
    if (value == null) {
      return null;
    }

    return _integer(value);
  }

  static double _decimal(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ReceivedDelivery {
  const ReceivedDelivery({
    required this.id,
    required this.drNumber,
    required this.deliveryDate,
    required this.supplier,
    required this.status,
    required this.items,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
    this.invoiceNumber,
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
  final String drNumber;
  final int deliveryDate;
  final String supplier;

  final String? invoiceNumber;
  final String? remarks;

  final InventoryDocumentStatus status;
  final List<ReceivedDeliveryItem> items;

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

  String get normalizedDrNumber {
    return drNumber.trim().toUpperCase();
  }

  String? get normalizedInvoiceNumber {
    return _normalizedDocumentText(invoiceNumber)?.toUpperCase();
  }

  int get totalSkus {
    return items.length;
  }

  int get totalOrderedQuantity {
    return items.fold<int>(0, (total, item) => total + item.orderedQuantity);
  }

  int get totalReceivedQuantity {
    return items.fold<int>(0, (total, item) => total + item.receivedQuantity);
  }

  double get totalCost {
    return items.fold<double>(0, (total, item) => total + item.totalCost);
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

  void validate({bool allowEmptyDraft = false, bool allowOverReceipt = false}) {
    if (id.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
        'Received Delivery ID is required.',
      );
    }

    if (normalizedDrNumber.isEmpty) {
      throw const ReceivedDeliveryValidationException('DR Number is required.');
    }

    if (deliveryDate <= 0) {
      throw const ReceivedDeliveryValidationException(
        'Delivery Date is required.',
      );
    }

    if (supplier.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException('Supplier is required.');
    }

    if (!allowEmptyDraft || status != InventoryDocumentStatus.draft) {
      if (items.isEmpty) {
        throw const ReceivedDeliveryValidationException(
          'At least one Received Delivery '
          'item is required.',
        );
      }
    }

    final itemIds = <String>{};
    final productIds = <String>{};
    final skus = <String>{};

    for (final item in items) {
      item.validate(allowOverReceipt: allowOverReceipt);

      if (!itemIds.add(item.id.trim())) {
        throw ReceivedDeliveryValidationException(
          'Duplicate Received Delivery '
          'Item ID: ${item.id}.',
        );
      }

      if (!productIds.add(item.productId.trim())) {
        throw const ReceivedDeliveryValidationException(
          'The same product cannot be '
          'added more than once.',
        );
      }

      if (!skus.add(item.normalizedSku)) {
        throw ReceivedDeliveryValidationException(
          'Duplicate SKU: '
          '${item.normalizedSku}.',
        );
      }
    }

    if (createdBy.trim().isEmpty || updatedBy.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
        'Created By and Updated By '
        'are required.',
      );
    }

    if (createdAt <= 0 || updatedAt <= 0) {
      throw const ReceivedDeliveryValidationException(
        'Created Date and Updated Date '
        'are required.',
      );
    }

    if (updatedAt < createdAt) {
      throw const ReceivedDeliveryValidationException(
        'Updated Date cannot be earlier '
        'than Created Date.',
      );
    }

    _validateWorkflowAudit();

    if (inventoryProcessed) {
      if (status != InventoryDocumentStatus.approved) {
        throw const ReceivedDeliveryValidationException(
          'Only an Approved Received '
          'Delivery can be inventory processed.',
        );
      }

      if ((inventoryProcessingId ?? '').trim().isEmpty) {
        throw const ReceivedDeliveryValidationException(
          'Inventory Processing ID '
          'is required.',
        );
      }

      if ((inventoryProcessedAt ?? 0) <= 0) {
        throw const ReceivedDeliveryValidationException(
          'Inventory Processed Date '
          'is required.',
        );
      }
    } else if (inventoryProcessingId != null || inventoryProcessedAt != null) {
      throw const ReceivedDeliveryValidationException(
        'Unprocessed Received Delivery '
        'cannot contain processing audit values.',
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
          throw const ReceivedDeliveryValidationException(
            'Draft Received Delivery cannot '
            'contain workflow audit values.',
          );
        }

      case InventoryDocumentStatus.submitted:
        if ((submittedBy ?? '').trim().isEmpty || (submittedAt ?? 0) <= 0) {
          throw const ReceivedDeliveryValidationException(
            'Submitted By and Submitted Date '
            'are required.',
          );
        }

        if (approvedBy != null ||
            approvedAt != null ||
            rejectedBy != null ||
            rejectedAt != null ||
            rejectionRemarks != null) {
          throw const ReceivedDeliveryValidationException(
            'Submitted Received Delivery cannot '
            'contain approval or rejection values.',
          );
        }

      case InventoryDocumentStatus.approved:
        if ((submittedBy ?? '').trim().isEmpty ||
            (submittedAt ?? 0) <= 0 ||
            (approvedBy ?? '').trim().isEmpty ||
            (approvedAt ?? 0) <= 0) {
          throw const ReceivedDeliveryValidationException(
            'Submitted and Approved audit '
            'values are required.',
          );
        }

        if (rejectedBy != null ||
            rejectedAt != null ||
            rejectionRemarks != null) {
          throw const ReceivedDeliveryValidationException(
            'Approved Received Delivery cannot '
            'contain rejection values.',
          );
        }

      case InventoryDocumentStatus.rejected:
        if ((submittedBy ?? '').trim().isEmpty ||
            (submittedAt ?? 0) <= 0 ||
            (rejectedBy ?? '').trim().isEmpty ||
            (rejectedAt ?? 0) <= 0 ||
            (rejectionRemarks ?? '').trim().isEmpty) {
          throw const ReceivedDeliveryValidationException(
            'Submitted and Rejected audit '
            'values are required.',
          );
        }

        if (approvedBy != null || approvedAt != null) {
          throw const ReceivedDeliveryValidationException(
            'Rejected Received Delivery cannot '
            'contain approval values.',
          );
        }
    }
  }

  ReceivedDelivery copyWith({
    String? id,
    String? drNumber,
    int? deliveryDate,
    String? supplier,
    String? invoiceNumber,
    bool clearInvoiceNumber = false,
    String? remarks,
    bool clearRemarks = false,
    InventoryDocumentStatus? status,
    List<ReceivedDeliveryItem>? items,
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
    return ReceivedDelivery(
      id: id ?? this.id,
      drNumber: drNumber ?? this.drNumber,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      supplier: supplier ?? this.supplier,
      invoiceNumber: clearInvoiceNumber
          ? null
          : invoiceNumber ?? this.invoiceNumber,
      remarks: clearRemarks ? null : remarks ?? this.remarks,
      status: status ?? this.status,
      items: List<ReceivedDeliveryItem>.unmodifiable(items ?? this.items),
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

  ReceivedDelivery submit({required String userId, required int timestamp}) {
    if (!canSubmit) {
      throw const ReceivedDeliveryValidationException(
        'Only a Draft Received Delivery '
        'with items can be submitted.',
      );
    }

    final submitted = copyWith(
      status: InventoryDocumentStatus.submitted,
      submittedBy: userId,
      submittedAt: timestamp,
      updatedBy: userId,
      updatedAt: timestamp,
    );

    submitted.validate();

    return submitted;
  }

  ReceivedDelivery approve({required String userId, required int timestamp}) {
    if (!canApprove) {
      throw const ReceivedDeliveryValidationException(
        'Only an unprocessed Submitted '
        'Received Delivery can be approved.',
      );
    }

    final approved = copyWith(
      status: InventoryDocumentStatus.approved,
      approvedBy: userId,
      approvedAt: timestamp,
      updatedBy: userId,
      updatedAt: timestamp,
    );

    approved.validate();

    return approved;
  }

  ReceivedDelivery reject({
    required String userId,
    required int timestamp,
    required String reason,
  }) {
    if (!canReject) {
      throw const ReceivedDeliveryValidationException(
        'Only a Submitted Received '
        'Delivery can be rejected.',
      );
    }

    if (reason.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
        'Rejection Remarks are required.',
      );
    }

    final rejected = copyWith(
      status: InventoryDocumentStatus.rejected,
      rejectedBy: userId,
      rejectedAt: timestamp,
      rejectionRemarks: reason.trim(),
      updatedBy: userId,
      updatedAt: timestamp,
    );

    rejected.validate();

    return rejected;
  }

  ReceivedDelivery markInventoryProcessed({
    required String processingId,
    required String userId,
    required int timestamp,
  }) {
    if (!isEligibleForInventoryProcessing) {
      throw const ReceivedDeliveryValidationException(
        'Received Delivery is not eligible '
        'for inventory processing.',
      );
    }

    if (processingId.trim().isEmpty) {
      throw const ReceivedDeliveryValidationException(
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
      'drNumber': normalizedDrNumber,
      'deliveryDate': deliveryDate,
      'supplier': supplier.trim(),
      'invoiceNumber': normalizedInvoiceNumber,
      'remarks': _normalizedDocumentText(remarks),
      'status': status.databaseValue,
      'totalSkus': totalSkus,
      'totalOrderedQuantity': totalOrderedQuantity,
      'totalReceivedQuantity': totalReceivedQuantity,
      'totalCost': totalCost,
      'createdBy': createdBy.trim(),
      'createdAt': createdAt,
      'updatedBy': updatedBy.trim(),
      'updatedAt': updatedAt,
      'submittedBy': _normalizedDocumentText(submittedBy),
      'submittedAt': submittedAt,
      'approvedBy': _normalizedDocumentText(approvedBy),
      'approvedAt': approvedAt,
      'rejectedBy': _normalizedDocumentText(rejectedBy),
      'rejectedAt': rejectedAt,
      'rejectionRemarks': _normalizedDocumentText(rejectionRemarks),
      'inventoryProcessed': inventoryProcessed,
      'inventoryProcessingId': _normalizedDocumentText(inventoryProcessingId),
      'inventoryProcessedAt': inventoryProcessedAt,
      'items': <String, Object?>{
        for (final item in items) item.id: item.toMap(),
      },
    };
  }

  factory ReceivedDelivery.fromMap(
    Map<Object?, Object?> map, {
    String? fallbackId,
  }) {
    final rawItems = map['items'];
    final items = <ReceivedDeliveryItem>[];

    if (rawItems is Map) {
      for (final entry in rawItems.entries) {
        final value = entry.value;

        if (value is Map) {
          items.add(
            ReceivedDeliveryItem.fromMap(
              Map<Object?, Object?>.from(value),
              fallbackId: entry.key.toString(),
            ),
          );
        }
      }
    }

    final delivery = ReceivedDelivery(
      id: _documentText(map['id']).isNotEmpty
          ? _documentText(map['id'])
          : fallbackId?.trim() ?? '',
      drNumber: _documentText(map['drNumber']),
      deliveryDate: _documentInteger(map['deliveryDate']),
      supplier: _documentText(map['supplier']),
      invoiceNumber: _optionalDocumentText(map['invoiceNumber']),
      remarks: _optionalDocumentText(map['remarks']),
      status: InventoryDocumentStatusValue.fromDatabase(map['status']),
      items: List<ReceivedDeliveryItem>.unmodifiable(items),
      createdBy: _documentText(map['createdBy']),
      createdAt: _documentInteger(map['createdAt']),
      updatedBy: _documentText(map['updatedBy']),
      updatedAt: _documentInteger(map['updatedAt']),
      submittedBy: _optionalDocumentText(map['submittedBy']),
      submittedAt: _nullableDocumentInteger(map['submittedAt']),
      approvedBy: _optionalDocumentText(map['approvedBy']),
      approvedAt: _nullableDocumentInteger(map['approvedAt']),
      rejectedBy: _optionalDocumentText(map['rejectedBy']),
      rejectedAt: _nullableDocumentInteger(map['rejectedAt']),
      rejectionRemarks: _optionalDocumentText(map['rejectionRemarks']),
      inventoryProcessed: _documentBoolean(map['inventoryProcessed']),
      inventoryProcessingId: _optionalDocumentText(
        map['inventoryProcessingId'],
      ),
      inventoryProcessedAt: _nullableDocumentInteger(
        map['inventoryProcessedAt'],
      ),
    );

    delivery.validate();

    return delivery;
  }

  static String _documentText(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _optionalDocumentText(Object? value) {
    final text = _documentText(value);

    return text.isEmpty ? null : text;
  }

  static String? _normalizedDocumentText(String? value) {
    final text = value?.trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static int _documentInteger(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableDocumentInteger(Object? value) {
    if (value == null) {
      return null;
    }

    return _documentInteger(value);
  }

  static bool _documentBoolean(Object? value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }
}
