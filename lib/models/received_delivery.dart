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
