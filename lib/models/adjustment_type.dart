import 'inventory_core.dart';

class AdjustmentTypeValidationException implements Exception {
  const AdjustmentTypeValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdjustmentTypeSeed {
  const AdjustmentTypeSeed({required this.name, required this.direction});

  final String name;
  final AdjustmentDirection direction;

  String get identityKey {
    return AdjustmentType.buildIdentityKey(name: name, direction: direction);
  }
}

class AdjustmentType {
  const AdjustmentType({
    required this.id,
    required this.name,
    required this.direction,
    required this.status,
    required this.usageCount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String id;
  final String name;

  final AdjustmentDirection direction;
  final AdjustmentTypeStatus status;

  final int usageCount;

  final String createdBy;
  final int createdAt;

  final String updatedBy;
  final int updatedAt;

  String get normalizedName {
    return normalizeName(name);
  }

  String get identityKey {
    return buildIdentityKey(name: name, direction: direction);
  }

  String get directionLabel {
    return direction.displayLabel;
  }

  String get statusLabel {
    switch (status) {
      case AdjustmentTypeStatus.active:
        return 'Active';
      case AdjustmentTypeStatus.inactive:
        return 'Inactive';
    }
  }

  bool get isActive {
    return status == AdjustmentTypeStatus.active;
  }

  bool get isInactive {
    return status == AdjustmentTypeStatus.inactive;
  }

  bool get hasBeenUsed {
    return usageCount > 0;
  }

  bool get canDelete {
    return usageCount == 0;
  }

  bool get canDeactivate {
    return isActive;
  }

  bool get isAvailableForNewAdjustment {
    return isActive;
  }

  void validate() {
    if (id.trim().isEmpty) {
      throw const AdjustmentTypeValidationException(
        'Adjustment Type ID is required.',
      );
    }

    if (normalizedName.isEmpty) {
      throw const AdjustmentTypeValidationException(
        'Adjustment Type is required.',
      );
    }

    if (normalizedName.length > 80) {
      throw const AdjustmentTypeValidationException(
        'Adjustment Type cannot exceed '
        '80 characters.',
      );
    }

    if (usageCount < 0) {
      throw const AdjustmentTypeValidationException(
        'Adjustment Type usage count '
        'cannot be negative.',
      );
    }

    if (createdBy.trim().isEmpty) {
      throw const AdjustmentTypeValidationException('Created By is required.');
    }

    if (createdAt <= 0) {
      throw const AdjustmentTypeValidationException(
        'Created Date is required.',
      );
    }

    if (updatedBy.trim().isEmpty) {
      throw const AdjustmentTypeValidationException('Updated By is required.');
    }

    if (updatedAt <= 0) {
      throw const AdjustmentTypeValidationException(
        'Updated Date is required.',
      );
    }

    if (updatedAt < createdAt) {
      throw const AdjustmentTypeValidationException(
        'Updated Date cannot be earlier '
        'than Created Date.',
      );
    }
  }

  void validatePermanentDelete() {
    validate();

    if (!canDelete) {
      throw AdjustmentTypeValidationException(
        'The Adjustment Type "$normalizedName" '
        'has already been used and cannot be '
        'permanently deleted. Deactivate it instead.',
      );
    }
  }

  AdjustmentType copyWith({
    String? id,
    String? name,
    AdjustmentDirection? direction,
    AdjustmentTypeStatus? status,
    int? usageCount,
    String? createdBy,
    int? createdAt,
    String? updatedBy,
    int? updatedAt,
  }) {
    final updated = AdjustmentType(
      id: id ?? this.id,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      usageCount: usageCount ?? this.usageCount,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );

    updated.validate();

    return updated;
  }

  AdjustmentType activate({required String userId, required int timestamp}) {
    return copyWith(
      status: AdjustmentTypeStatus.active,
      updatedBy: userId,
      updatedAt: timestamp,
    );
  }

  AdjustmentType deactivate({required String userId, required int timestamp}) {
    return copyWith(
      status: AdjustmentTypeStatus.inactive,
      updatedBy: userId,
      updatedAt: timestamp,
    );
  }

  AdjustmentType registerApprovedUsage({
    required String userId,
    required int timestamp,
  }) {
    return copyWith(
      usageCount: usageCount + 1,
      updatedBy: userId,
      updatedAt: timestamp,
    );
  }

  Map<String, Object?> toMap() {
    validate();

    return <String, Object?>{
      'id': id.trim(),
      'name': normalizedName,
      'normalizedName': normalizedName.toLowerCase(),
      'direction': direction.databaseValue,
      'status': status.name,
      'usageCount': usageCount,
      'createdBy': createdBy.trim(),
      'createdAt': createdAt,
      'updatedBy': updatedBy.trim(),
      'updatedAt': updatedAt,
    };
  }

  factory AdjustmentType.fromMap(
    Map<Object?, Object?> map, {
    String? fallbackId,
  }) {
    final adjustmentType = AdjustmentType(
      id: _text(map['id']).isNotEmpty
          ? _text(map['id'])
          : fallbackId?.trim() ?? '',
      name: _text(map['name']),
      direction: AdjustmentDirectionValue.fromDatabase(map['direction']),
      status: _statusFromDatabase(map['status']),
      usageCount: _integer(map['usageCount']),
      createdBy: _text(map['createdBy']),
      createdAt: _integer(map['createdAt']),
      updatedBy: _text(map['updatedBy']),
      updatedAt: _integer(map['updatedAt']),
    );

    adjustmentType.validate();

    return adjustmentType;
  }

  static String buildIdentityKey({
    required String name,
    required AdjustmentDirection direction,
  }) {
    final normalized = normalizeName(name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (normalized.isEmpty) {
      throw const AdjustmentTypeValidationException(
        'Adjustment Type is required.',
      );
    }

    return '$normalized-${direction.databaseValue}';
  }

  static String normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static AdjustmentTypeStatus _statusFromDatabase(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'active':
        return AdjustmentTypeStatus.active;
      case 'inactive':
        return AdjustmentTypeStatus.inactive;
      default:
        return AdjustmentTypeStatus.inactive;
    }
  }

  static String _text(Object? value) {
    return value?.toString().trim() ?? '';
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
}

class AdjustmentTypeDefaults {
  const AdjustmentTypeDefaults._();

  static const List<AdjustmentTypeSeed> seeds = <AdjustmentTypeSeed>[
    AdjustmentTypeSeed(name: 'Damage', direction: AdjustmentDirection.decrease),
    AdjustmentTypeSeed(
      name: 'Cycle Count',
      direction: AdjustmentDirection.decrease,
    ),
    AdjustmentTypeSeed(
      name: 'Change to Employee',
      direction: AdjustmentDirection.decrease,
    ),
    AdjustmentTypeSeed(
      name: 'Other Adjustment',
      direction: AdjustmentDirection.decrease,
    ),
    AdjustmentTypeSeed(
      name: 'Cycle Count',
      direction: AdjustmentDirection.increase,
    ),
    AdjustmentTypeSeed(
      name: 'Other Adjustment',
      direction: AdjustmentDirection.increase,
    ),
  ];

  static List<AdjustmentType> createSeedRecords({
    required String userId,
    required int timestamp,
  }) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw const AdjustmentTypeValidationException('Seed user is required.');
    }

    if (timestamp <= 0) {
      throw const AdjustmentTypeValidationException(
        'Seed timestamp is required.',
      );
    }

    return seeds
        .map((seed) {
          final record = AdjustmentType(
            id: seed.identityKey,
            name: seed.name,
            direction: seed.direction,
            status: AdjustmentTypeStatus.active,
            usageCount: 0,
            createdBy: normalizedUserId,
            createdAt: timestamp,
            updatedBy: normalizedUserId,
            updatedAt: timestamp,
          );

          record.validate();

          return record;
        })
        .toList(growable: false);
  }
}
