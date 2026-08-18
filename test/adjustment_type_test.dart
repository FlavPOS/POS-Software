import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/adjustment_type.dart';
import 'package:simple_pos/models/inventory_core.dart';

AdjustmentType buildAdjustmentType({
  String id = 'damage-decrease',
  String name = 'Damage',
  AdjustmentDirection direction = AdjustmentDirection.decrease,
  AdjustmentTypeStatus status = AdjustmentTypeStatus.active,
  int usageCount = 0,
  int createdAt = 100,
  int updatedAt = 100,
}) {
  return AdjustmentType(
    id: id,
    name: name,
    direction: direction,
    status: status,
    usageCount: usageCount,
    createdBy: 'admin-001',
    createdAt: createdAt,
    updatedBy: 'admin-001',
    updatedAt: updatedAt,
  );
}

void main() {
  group('AdjustmentType', () {
    test('stores direction and status labels', () {
      final type = buildAdjustmentType();

      expect(type.directionLabel, 'Decrease (-)');

      expect(type.statusLabel, 'Active');

      expect(type.isAvailableForNewAdjustment, isTrue);
    });

    test('normalizes spaces in name', () {
      final type = buildAdjustmentType(
        name: '  Cycle    Count  ',
        id: 'cycle-count-decrease',
      );

      expect(type.normalizedName, 'Cycle Count');

      expect(type.identityKey, 'cycle-count-decrease');
    });

    test('same name can exist in both directions', () {
      final increase = AdjustmentType.buildIdentityKey(
        name: 'Cycle Count',
        direction: AdjustmentDirection.increase,
      );

      final decrease = AdjustmentType.buildIdentityKey(
        name: 'Cycle Count',
        direction: AdjustmentDirection.decrease,
      );

      expect(increase, 'cycle-count-increase');

      expect(decrease, 'cycle-count-decrease');

      expect(increase, isNot(decrease));
    });

    test('unused type can be deleted', () {
      final type = buildAdjustmentType(usageCount: 0);

      expect(type.canDelete, isTrue);

      expect(type.hasBeenUsed, isFalse);

      expect(type.validatePermanentDelete, returnsNormally);
    });

    test('used type cannot be permanently deleted', () {
      final type = buildAdjustmentType(usageCount: 1);

      expect(type.canDelete, isFalse);

      expect(type.hasBeenUsed, isTrue);

      expect(
        type.validatePermanentDelete,
        throwsA(isA<AdjustmentTypeValidationException>()),
      );
    });

    test('used type can be deactivated', () {
      final type = buildAdjustmentType(usageCount: 5);

      final inactive = type.deactivate(userId: 'manager-001', timestamp: 200);

      expect(inactive.status, AdjustmentTypeStatus.inactive);

      expect(inactive.isAvailableForNewAdjustment, isFalse);

      expect(inactive.usageCount, 5);
    });

    test('inactive type can be activated again', () {
      final type = buildAdjustmentType(status: AdjustmentTypeStatus.inactive);

      final active = type.activate(userId: 'admin-001', timestamp: 200);

      expect(active.status, AdjustmentTypeStatus.active);

      expect(active.isAvailableForNewAdjustment, isTrue);
    });

    test('approved usage increases usage count', () {
      final type = buildAdjustmentType(usageCount: 2);

      final used = type.registerApprovedUsage(
        userId: 'manager-001',
        timestamp: 200,
      );

      expect(used.usageCount, 3);

      expect(used.canDelete, isFalse);

      expect(used.updatedBy, 'manager-001');
    });

    test('rejects empty adjustment name', () {
      final type = buildAdjustmentType(name: '   ');

      expect(type.validate, throwsA(isA<AdjustmentTypeValidationException>()));
    });

    test('rejects negative usage count', () {
      final type = buildAdjustmentType(usageCount: -1);

      expect(type.validate, throwsA(isA<AdjustmentTypeValidationException>()));
    });

    test('rejects updated date before created date', () {
      final type = buildAdjustmentType(createdAt: 200, updatedAt: 100);

      expect(type.validate, throwsA(isA<AdjustmentTypeValidationException>()));
    });

    test('serializes standardized database values', () {
      final type = buildAdjustmentType();

      final map = type.toMap();

      expect(map['direction'], 'decrease');

      expect(map['status'], 'active');

      expect(map['usageCount'], 0);

      expect(map['normalizedName'], 'damage');
    });

    test('restores adjustment type from Firebase map', () {
      final type = AdjustmentType.fromMap(<Object?, Object?>{
        'name': 'Cycle Count',
        'direction': 'increase',
        'status': 'active',
        'usageCount': 4,
        'createdBy': 'admin-001',
        'createdAt': 100,
        'updatedBy': 'manager-001',
        'updatedAt': 200,
      }, fallbackId: 'cycle-count-increase');

      expect(type.id, 'cycle-count-increase');

      expect(type.direction, AdjustmentDirection.increase);

      expect(type.usageCount, 4);
    });

    test('contains no retail or selling values', () {
      final map = buildAdjustmentType().toMap();

      expect(map.containsKey('retailPrice'), isFalse);

      expect(map.containsKey('sellingPrice'), isFalse);

      expect(map.containsKey('retailValue'), isFalse);
    });
  });

  group('AdjustmentTypeDefaults', () {
    test('contains six initial seed definitions', () {
      expect(AdjustmentTypeDefaults.seeds, hasLength(6));
    });

    test('contains four decrease defaults', () {
      final count = AdjustmentTypeDefaults.seeds
          .where((seed) => seed.direction == AdjustmentDirection.decrease)
          .length;

      expect(count, 4);
    });

    test('contains two increase defaults', () {
      final count = AdjustmentTypeDefaults.seeds
          .where((seed) => seed.direction == AdjustmentDirection.increase)
          .length;

      expect(count, 2);
    });

    test('default identities are unique', () {
      final keys = AdjustmentTypeDefaults.seeds
          .map((seed) => seed.identityKey)
          .toSet();

      expect(keys, hasLength(AdjustmentTypeDefaults.seeds.length));
    });

    test('creates active unused seed records', () {
      final records = AdjustmentTypeDefaults.createSeedRecords(
        userId: 'system',
        timestamp: 100,
      );

      expect(records, hasLength(6));

      expect(
        records.every((record) => record.isActive && record.usageCount == 0),
        isTrue,
      );
    });

    test('seed record creation requires user', () {
      expect(() {
        AdjustmentTypeDefaults.createSeedRecords(userId: ' ', timestamp: 100);
      }, throwsA(isA<AdjustmentTypeValidationException>()));
    });
  });
}
