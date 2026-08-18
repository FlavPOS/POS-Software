enum InventoryMovementType { sale, delivery, adjustmentIn, adjustmentOut }

enum InventoryDocumentStatus { draft, submitted, approved, rejected }

enum AdjustmentDirection { increase, decrease }

enum AdjustmentTypeStatus { active, inactive }

extension InventoryMovementTypeValue on InventoryMovementType {
  String get databaseValue {
    switch (this) {
      case InventoryMovementType.sale:
        return 'SALE';
      case InventoryMovementType.delivery:
        return 'DELIVERY';
      case InventoryMovementType.adjustmentIn:
        return 'ADJUSTMENT_IN';
      case InventoryMovementType.adjustmentOut:
        return 'ADJUSTMENT_OUT';
    }
  }

  static InventoryMovementType fromDatabase(Object? value) {
    switch (value?.toString().trim().toUpperCase()) {
      case 'SALE':
        return InventoryMovementType.sale;
      case 'DELIVERY':
        return InventoryMovementType.delivery;
      case 'ADJUSTMENT_IN':
        return InventoryMovementType.adjustmentIn;
      case 'ADJUSTMENT_OUT':
        return InventoryMovementType.adjustmentOut;
      default:
        throw ArgumentError('Unsupported inventory movement type: $value');
    }
  }
}

extension InventoryDocumentStatusValue on InventoryDocumentStatus {
  String get databaseValue => name;

  bool get canEdit {
    return this == InventoryDocumentStatus.draft;
  }

  bool get changesInventory {
    return this == InventoryDocumentStatus.approved;
  }

  bool get isLocked {
    return this != InventoryDocumentStatus.draft;
  }

  static InventoryDocumentStatus fromDatabase(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();

    return InventoryDocumentStatus.values.firstWhere(
      (status) => status.databaseValue == normalized,
      orElse: () => InventoryDocumentStatus.draft,
    );
  }
}

extension AdjustmentDirectionValue on AdjustmentDirection {
  String get databaseValue => name;

  String get displayLabel {
    switch (this) {
      case AdjustmentDirection.increase:
        return 'Increase (+)';
      case AdjustmentDirection.decrease:
        return 'Decrease (-)';
    }
  }

  int get multiplier {
    switch (this) {
      case AdjustmentDirection.increase:
        return 1;
      case AdjustmentDirection.decrease:
        return -1;
    }
  }

  InventoryMovementType get movementType {
    switch (this) {
      case AdjustmentDirection.increase:
        return InventoryMovementType.adjustmentIn;
      case AdjustmentDirection.decrease:
        return InventoryMovementType.adjustmentOut;
    }
  }

  static AdjustmentDirection fromDatabase(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'increase':
        return AdjustmentDirection.increase;
      case 'decrease':
        return AdjustmentDirection.decrease;
      default:
        throw ArgumentError('Unsupported adjustment direction: $value');
    }
  }
}

class InventoryValidationException implements Exception {
  const InventoryValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InventoryCostRules {
  const InventoryCostRules._();

  static double inventoryValue({
    required int onHandQuantity,
    required double costPrice,
  }) {
    _validateQuantity(onHandQuantity, fieldName: 'On-hand quantity');

    _validateCostPrice(costPrice);

    return onHandQuantity * costPrice;
  }

  static double adjustmentValue({
    required int adjustmentQuantity,
    required double costPrice,
  }) {
    if (adjustmentQuantity <= 0) {
      throw const InventoryValidationException(
        'Adjustment quantity must be greater than zero.',
      );
    }

    _validateCostPrice(costPrice);

    return adjustmentQuantity * costPrice;
  }

  static double deliveryValue({
    required int receivedQuantity,
    required double costPrice,
  }) {
    if (receivedQuantity < 0) {
      throw const InventoryValidationException(
        'Received quantity cannot be negative.',
      );
    }

    _validateCostPrice(costPrice);

    return receivedQuantity * costPrice;
  }

  static int newOnHandForAdjustment({
    required int currentOnHand,
    required int adjustmentQuantity,
    required AdjustmentDirection direction,
    bool allowNegativeInventory = false,
  }) {
    _validateQuantity(currentOnHand, fieldName: 'Current on-hand quantity');

    if (adjustmentQuantity <= 0) {
      throw const InventoryValidationException(
        'Adjustment quantity must be greater than zero.',
      );
    }

    final newOnHand = currentOnHand + adjustmentQuantity * direction.multiplier;

    if (!allowNegativeInventory && newOnHand < 0) {
      throw InventoryValidationException(
        'Insufficient inventory. Current OH is only '
        '$currentOnHand.',
      );
    }

    return newOnHand;
  }

  static int newOnHandForDelivery({
    required int currentOnHand,
    required int receivedQuantity,
  }) {
    _validateQuantity(currentOnHand, fieldName: 'Current on-hand quantity');

    if (receivedQuantity < 0) {
      throw const InventoryValidationException(
        'Received quantity cannot be negative.',
      );
    }

    return currentOnHand + receivedQuantity;
  }

  static void _validateQuantity(int value, {required String fieldName}) {
    if (value < 0) {
      throw InventoryValidationException('$fieldName cannot be negative.');
    }
  }

  static void _validateCostPrice(double value) {
    if (!value.isFinite || value < 0) {
      throw const InventoryValidationException(
        'Cost Price must be a valid non-negative value.',
      );
    }
  }
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.processingKey,
    required this.sku,
    required this.productName,
    required this.movementType,
    required this.referenceNumber,
    required this.quantityIn,
    required this.quantityOut,
    required this.costPrice,
    required this.previousOnHand,
    required this.newOnHand,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.remarks,
  });

  final String id;
  final String processingKey;

  final String sku;
  final String productName;

  final InventoryMovementType movementType;
  final String referenceNumber;

  final int quantityIn;
  final int quantityOut;

  final double costPrice;

  final int previousOnHand;
  final int newOnHand;

  final String userId;
  final String userName;
  final int createdAt;

  final String? remarks;

  int get netQuantity {
    return quantityIn - quantityOut;
  }

  int get movementQuantity {
    return quantityIn + quantityOut;
  }

  double get movementValue {
    return movementQuantity * costPrice;
  }

  bool get isIncrease {
    return quantityIn > 0 && quantityOut == 0;
  }

  bool get isDecrease {
    return quantityOut > 0 && quantityIn == 0;
  }

  void validate() {
    if (id.trim().isEmpty) {
      throw const InventoryValidationException(
        'Inventory Movement ID is required.',
      );
    }

    if (processingKey.trim().isEmpty) {
      throw const InventoryValidationException(
        'Inventory processing key is required.',
      );
    }

    if (sku.trim().isEmpty) {
      throw const InventoryValidationException('SKU is required.');
    }

    if (referenceNumber.trim().isEmpty) {
      throw const InventoryValidationException('Reference Number is required.');
    }

    if (quantityIn < 0 || quantityOut < 0) {
      throw const InventoryValidationException(
        'Movement quantities cannot be negative.',
      );
    }

    if (quantityIn == 0 && quantityOut == 0) {
      throw const InventoryValidationException(
        'Inventory movement must contain a quantity.',
      );
    }

    if (quantityIn > 0 && quantityOut > 0) {
      throw const InventoryValidationException(
        'A movement cannot contain both Quantity In '
        'and Quantity Out.',
      );
    }

    if (newOnHand != previousOnHand + netQuantity) {
      throw const InventoryValidationException(
        'New OH does not match the inventory movement.',
      );
    }

    if (newOnHand < 0) {
      throw const InventoryValidationException(
        'Inventory cannot become negative.',
      );
    }

    if (!costPrice.isFinite || costPrice < 0) {
      throw const InventoryValidationException(
        'Cost Price must be valid and non-negative.',
      );
    }
  }

  Map<String, Object?> toMap() {
    validate();

    return <String, Object?>{
      'id': id,
      'processingKey': processingKey,
      'sku': sku.trim().toUpperCase(),
      'productName': productName.trim(),
      'movementType': movementType.databaseValue,
      'referenceNumber': referenceNumber.trim(),
      'quantityIn': quantityIn,
      'quantityOut': quantityOut,
      'costPrice': costPrice,
      'movementValue': movementValue,
      'previousOnHand': previousOnHand,
      'newOnHand': newOnHand,
      'userId': userId.trim(),
      'userName': userName.trim(),
      'createdAt': createdAt,
      'remarks': _normalizedText(remarks),
    };
  }

  factory InventoryMovement.fromMap(Map<Object?, Object?> map) {
    final movement = InventoryMovement(
      id: _text(map['id']),
      processingKey: _text(map['processingKey']),
      sku: _text(map['sku']),
      productName: _text(map['productName']),
      movementType: InventoryMovementTypeValue.fromDatabase(
        map['movementType'],
      ),
      referenceNumber: _text(map['referenceNumber']),
      quantityIn: _integer(map['quantityIn']),
      quantityOut: _integer(map['quantityOut']),
      costPrice: _decimal(map['costPrice']),
      previousOnHand: _integer(map['previousOnHand']),
      newOnHand: _integer(map['newOnHand']),
      userId: _text(map['userId']),
      userName: _text(map['userName']),
      createdAt: _integer(map['createdAt']),
      remarks: _optionalText(map['remarks']),
    );

    movement.validate();

    return movement;
  }

  static String _text(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _optionalText(Object? value) {
    final text = _text(value);

    return text.isEmpty ? null : text;
  }

  static String? _normalizedText(String? value) {
    final text = value?.trim() ?? '';

    return text.isEmpty ? null : text;
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
