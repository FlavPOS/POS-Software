import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/inventory_core.dart';

void main() {
  group('Inventory Cost Rules', () {
    test('inventory value uses OH multiplied by Cost Price', () {
      expect(
        InventoryCostRules.inventoryValue(onHandQuantity: 20, costPrice: 100),
        2000,
      );
    });

    test('adjustment value uses quantity multiplied by Cost Price', () {
      expect(
        InventoryCostRules.adjustmentValue(
          adjustmentQuantity: 2,
          costPrice: 100,
        ),
        200,
      );
    });

    test('delivery value uses received quantity and Cost Price', () {
      expect(
        InventoryCostRules.deliveryValue(receivedQuantity: 10, costPrice: 100),
        1000,
      );
    });

    test('decrease adjustment reduces OH', () {
      expect(
        InventoryCostRules.newOnHandForAdjustment(
          currentOnHand: 20,
          adjustmentQuantity: 2,
          direction: AdjustmentDirection.decrease,
        ),
        18,
      );
    });

    test('increase adjustment increases OH', () {
      expect(
        InventoryCostRules.newOnHandForAdjustment(
          currentOnHand: 20,
          adjustmentQuantity: 2,
          direction: AdjustmentDirection.increase,
        ),
        22,
      );
    });

    test('negative inventory is blocked by default', () {
      expect(() {
        InventoryCostRules.newOnHandForAdjustment(
          currentOnHand: 2,
          adjustmentQuantity: 5,
          direction: AdjustmentDirection.decrease,
        );
      }, throwsA(isA<InventoryValidationException>()));
    });

    test('delivery increases OH', () {
      expect(
        InventoryCostRules.newOnHandForDelivery(
          currentOnHand: 20,
          receivedQuantity: 10,
        ),
        30,
      );
    });
  });

  group('Inventory Workflow', () {
    test('only approved status changes inventory', () {
      expect(InventoryDocumentStatus.draft.changesInventory, isFalse);

      expect(InventoryDocumentStatus.submitted.changesInventory, isFalse);

      expect(InventoryDocumentStatus.rejected.changesInventory, isFalse);

      expect(InventoryDocumentStatus.approved.changesInventory, isTrue);
    });

    test('only draft status can be edited', () {
      expect(InventoryDocumentStatus.draft.canEdit, isTrue);

      expect(InventoryDocumentStatus.submitted.canEdit, isFalse);

      expect(InventoryDocumentStatus.approved.canEdit, isFalse);

      expect(InventoryDocumentStatus.rejected.canEdit, isFalse);
    });
  });

  group('Adjustment Direction', () {
    test('direction values are standardized', () {
      expect(AdjustmentDirection.increase.databaseValue, 'increase');

      expect(AdjustmentDirection.decrease.databaseValue, 'decrease');
    });

    test('direction selects correct movement type', () {
      expect(
        AdjustmentDirection.increase.movementType,
        InventoryMovementType.adjustmentIn,
      );

      expect(
        AdjustmentDirection.decrease.movementType,
        InventoryMovementType.adjustmentOut,
      );
    });
  });

  group('Inventory Movement', () {
    test('delivery movement calculates value at Cost Price', () {
      final movement = InventoryMovement(
        id: 'movement-001',
        processingKey: 'DELIVERY:DR-001:SKU-001',
        sku: 'SKU-001',
        productName: 'Test Product',
        movementType: InventoryMovementType.delivery,
        referenceNumber: 'DR-001',
        quantityIn: 10,
        quantityOut: 0,
        costPrice: 100,
        previousOnHand: 20,
        newOnHand: 30,
        userId: 'system',
        userName: 'System User',
        createdAt: 1,
      );

      movement.validate();

      expect(movement.movementValue, 1000);

      expect(movement.netQuantity, 10);
    });

    test('decrease movement calculates value at Cost Price', () {
      final movement = InventoryMovement(
        id: 'movement-002',
        processingKey: 'ADJUSTMENT:ADJ-001:SKU-001',
        sku: 'SKU-001',
        productName: 'Test Product',
        movementType: InventoryMovementType.adjustmentOut,
        referenceNumber: 'ADJ-001',
        quantityIn: 0,
        quantityOut: 2,
        costPrice: 100,
        previousOnHand: 20,
        newOnHand: 18,
        userId: 'system',
        userName: 'System User',
        createdAt: 1,
      );

      movement.validate();

      expect(movement.movementValue, 200);

      expect(movement.netQuantity, -2);
    });

    test('movement rejects mismatched new OH', () {
      final movement = InventoryMovement(
        id: 'movement-003',
        processingKey: 'DELIVERY:DR-001:SKU-001',
        sku: 'SKU-001',
        productName: 'Test Product',
        movementType: InventoryMovementType.delivery,
        referenceNumber: 'DR-001',
        quantityIn: 10,
        quantityOut: 0,
        costPrice: 100,
        previousOnHand: 20,
        newOnHand: 25,
        userId: 'system',
        userName: 'System User',
        createdAt: 1,
      );

      expect(movement.validate, throwsA(isA<InventoryValidationException>()));
    });

    test('movement rejects quantity in and out together', () {
      final movement = InventoryMovement(
        id: 'movement-004',
        processingKey: 'ADJUSTMENT:ADJ-001:SKU-001',
        sku: 'SKU-001',
        productName: 'Test Product',
        movementType: InventoryMovementType.adjustmentIn,
        referenceNumber: 'ADJ-001',
        quantityIn: 2,
        quantityOut: 1,
        costPrice: 100,
        previousOnHand: 20,
        newOnHand: 21,
        userId: 'system',
        userName: 'System User',
        createdAt: 1,
      );

      expect(movement.validate, throwsA(isA<InventoryValidationException>()));
    });

    test('movement map contains no Retail Price', () {
      final movement = InventoryMovement(
        id: 'movement-005',
        processingKey: 'DELIVERY:DR-001:SKU-001',
        sku: 'SKU-001',
        productName: 'Test Product',
        movementType: InventoryMovementType.delivery,
        referenceNumber: 'DR-001',
        quantityIn: 1,
        quantityOut: 0,
        costPrice: 100,
        previousOnHand: 20,
        newOnHand: 21,
        userId: 'system',
        userName: 'System User',
        createdAt: 1,
      );

      final map = movement.toMap();

      expect(map.containsKey('sellingPrice'), isFalse);

      expect(map.containsKey('retailPrice'), isFalse);

      expect(map['costPrice'], 100);
    });
  });
}
