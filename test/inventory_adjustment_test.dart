import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/inventory_adjustment.dart';
import 'package:simple_pos/models/inventory_core.dart';

InventoryAdjustmentItem buildItem({
  String id = 'item-001',
  String productId = 'product-001',
  String sku = 'SKU-001',
  int currentOnHand = 20,
  double costPrice = 100,
  int quantity = 2,
  AdjustmentDirection direction = AdjustmentDirection.decrease,
}) {
  return InventoryAdjustmentItem(
    id: id,
    productId: productId,
    sku: sku,
    productName: 'Test Product',
    currentOnHand: currentOnHand,
    costPrice: costPrice,
    adjustmentQuantity: quantity,
    direction: direction,
  );
}

InventoryAdjustment buildDraft({
  AdjustmentDirection direction = AdjustmentDirection.decrease,
  List<InventoryAdjustmentItem>? items,
}) {
  return InventoryAdjustment(
    id: 'adjustment-001',
    adjustmentNumber: 'ADJ-000001',
    adjustmentDate: 100,
    adjustmentTypeId: 'damage-decrease',
    adjustmentTypeName: 'Damage',
    direction: direction,
    status: InventoryDocumentStatus.draft,
    items: items ?? <InventoryAdjustmentItem>[buildItem(direction: direction)],
    createdBy: 'inventory-user',
    createdAt: 100,
    updatedBy: 'inventory-user',
    updatedAt: 100,
  );
}

void main() {
  group('InventoryAdjustmentItem', () {
    test('decrease calculates quantity out and new OH', () {
      final item = buildItem();

      expect(item.quantityIn, 0);
      expect(item.quantityOut, 2);
      expect(item.newOnHand, 18);
      expect(item.adjustmentAmount, 200);
    });

    test('increase calculates quantity in and new OH', () {
      final item = buildItem(direction: AdjustmentDirection.increase);

      expect(item.quantityIn, 2);
      expect(item.quantityOut, 0);
      expect(item.newOnHand, 22);
      expect(item.adjustmentAmount, 200);
    });

    test('blocks negative inventory', () {
      final item = buildItem(currentOnHand: 2, quantity: 5);

      expect(
        item.validate,
        throwsA(isA<InventoryAdjustmentValidationException>()),
      );
    });

    test('requires positive quantity', () {
      final item = buildItem(quantity: 0);

      expect(
        item.validate,
        throwsA(isA<InventoryAdjustmentValidationException>()),
      );
    });

    test('item map contains cost values only', () {
      final map = buildItem().toMap();

      expect(map['costPrice'], 100);
      expect(map['adjustmentAmount'], 200);
      expect(map.containsKey('retailPrice'), isFalse);
      expect(map.containsKey('sellingPrice'), isFalse);
    });
  });

  group('InventoryAdjustment Summary', () {
    test('calculates decrease totals', () {
      final adjustment = buildDraft(
        items: <InventoryAdjustmentItem>[
          buildItem(
            id: 'item-001',
            productId: 'product-001',
            sku: 'SKU-001',
            quantity: 2,
            costPrice: 100,
          ),
          buildItem(
            id: 'item-002',
            productId: 'product-002',
            sku: 'SKU-002',
            quantity: 3,
            costPrice: 50,
          ),
        ],
      );

      adjustment.validate();

      expect(adjustment.totalSkus, 2);
      expect(adjustment.totalQuantity, 5);
      expect(adjustment.totalQuantityIn, 0);
      expect(adjustment.totalQuantityOut, 5);
      expect(adjustment.totalAdjustmentValueAtCost, 350);
    });

    test('calculates increase totals', () {
      final adjustment = buildDraft(
        direction: AdjustmentDirection.increase,
        items: <InventoryAdjustmentItem>[
          buildItem(direction: AdjustmentDirection.increase, quantity: 2),
        ],
      );

      adjustment.validate();

      expect(adjustment.totalQuantityIn, 2);
      expect(adjustment.totalQuantityOut, 0);
    });

    test('rejects duplicate SKU', () {
      final adjustment = buildDraft(
        items: <InventoryAdjustmentItem>[
          buildItem(),
          buildItem(id: 'item-002', productId: 'product-002'),
        ],
      );

      expect(
        adjustment.validate,
        throwsA(isA<InventoryAdjustmentValidationException>()),
      );
    });

    test('rejects item direction mismatch', () {
      final adjustment = buildDraft(
        direction: AdjustmentDirection.decrease,
        items: <InventoryAdjustmentItem>[
          buildItem(direction: AdjustmentDirection.increase),
        ],
      );

      expect(
        adjustment.validate,
        throwsA(isA<InventoryAdjustmentValidationException>()),
      );
    });
  });

  group('InventoryAdjustment Workflow', () {
    test('draft can be edited and submitted', () {
      final draft = buildDraft();

      expect(draft.canEdit, isTrue);
      expect(draft.canSubmit, isTrue);
      expect(draft.canApprove, isFalse);
    });

    test('submits draft without processing inventory', () {
      final submitted = buildDraft().submit(
        userId: 'inventory-user',
        timestamp: 200,
      );

      expect(submitted.status, InventoryDocumentStatus.submitted);
      expect(submitted.inventoryProcessed, isFalse);
      expect(submitted.submittedBy, 'inventory-user');
    });

    test('approves submitted adjustment', () {
      final submitted = buildDraft().submit(
        userId: 'inventory-user',
        timestamp: 200,
      );

      final approved = submitted.approve(userId: 'manager-001', timestamp: 300);

      expect(approved.status, InventoryDocumentStatus.approved);
      expect(approved.approvedBy, 'manager-001');
      expect(approved.isEligibleForInventoryProcessing, isTrue);
    });

    test('rejects submitted adjustment', () {
      final submitted = buildDraft().submit(
        userId: 'inventory-user',
        timestamp: 200,
      );

      final rejected = submitted.reject(
        userId: 'manager-001',
        timestamp: 300,
        reason: 'Invalid count.',
      );

      expect(rejected.status, InventoryDocumentStatus.rejected);
      expect(rejected.rejectionRemarks, 'Invalid count.');
      expect(rejected.inventoryProcessed, isFalse);
    });

    test('reject requires remarks', () {
      final submitted = buildDraft().submit(
        userId: 'inventory-user',
        timestamp: 200,
      );

      expect(() {
        submitted.reject(userId: 'manager-001', timestamp: 300, reason: ' ');
      }, throwsA(isA<InventoryAdjustmentValidationException>()));
    });

    test('marks approved adjustment processed once', () {
      final approved = buildDraft()
          .submit(userId: 'inventory-user', timestamp: 200)
          .approve(userId: 'manager-001', timestamp: 300);

      final processed = approved.markInventoryProcessed(
        processingId: 'ADJUSTMENT:ADJ-000001',
        timestamp: 400,
        userId: 'manager-001',
      );

      expect(processed.inventoryProcessed, isTrue);
      expect(processed.isInventoryProcessingComplete, isTrue);
      expect(processed.inventoryProcessingId, 'ADJUSTMENT:ADJ-000001');

      expect(() {
        processed.markInventoryProcessed(
          processingId: 'ADJUSTMENT:ADJ-000001',
          timestamp: 500,
          userId: 'manager-001',
        );
      }, throwsA(isA<InventoryAdjustmentValidationException>()));
    });

    test('draft cannot be marked processed', () {
      expect(() {
        buildDraft().markInventoryProcessed(
          processingId: 'ADJUSTMENT:ADJ-000001',
          timestamp: 400,
          userId: 'manager-001',
        );
      }, throwsA(isA<InventoryAdjustmentValidationException>()));
    });
  });

  group('InventoryAdjustment Serialization', () {
    test('stores type and direction snapshots', () {
      final map = buildDraft().toMap();

      expect(map['adjustmentTypeId'], 'damage-decrease');
      expect(map['adjustmentTypeName'], 'Damage');
      expect(map['direction'], 'decrease');
    });

    test('contains no retail or selling fields', () {
      final map = buildDraft().toMap();
      final text = map.toString().toLowerCase();

      expect(text.contains('retail'), isFalse);
      expect(text.contains('selling'), isFalse);
      expect(map['totalAdjustmentValueAtCost'], 200);
    });

    test('restores draft adjustment from map', () {
      final original = buildDraft();
      final restored = InventoryAdjustment.fromMap(
        Map<Object?, Object?>.from(original.toMap()),
      );

      expect(restored.adjustmentNumber, 'ADJ-000001');
      expect(restored.totalSkus, 1);
      expect(restored.items.first.newOnHand, 18);
    });
  });
}
