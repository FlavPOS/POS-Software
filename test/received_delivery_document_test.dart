import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/inventory_core.dart';
import 'package:simple_pos/models/received_delivery.dart';

ReceivedDeliveryItem buildDeliveryItem({
  String id = 'item-001',
  String productId = 'product-001',
  String sku = 'SKU-001',
  int orderedQuantity = 10,
  int receivedQuantity = 10,
  double costPrice = 100,
}) {
  return ReceivedDeliveryItem(
    id: id,
    productId: productId,
    sku: sku,
    productName: 'Test Product',
    currentOnHand: 20,
    orderedQuantity: orderedQuantity,
    receivedQuantity: receivedQuantity,
    costPrice: costPrice,
  );
}

ReceivedDelivery buildDraft({
  List<ReceivedDeliveryItem>? items,
  String drNumber = 'DR-000001',
}) {
  return ReceivedDelivery(
    id: 'delivery-001',
    drNumber: drNumber,
    deliveryDate: 100,
    supplier: 'Test Supplier',
    invoiceNumber: 'INV-001',
    status: InventoryDocumentStatus.draft,
    items: items ?? <ReceivedDeliveryItem>[buildDeliveryItem()],
    createdBy: 'inventory-user',
    createdAt: 100,
    updatedBy: 'inventory-user',
    updatedAt: 100,
  );
}

void main() {
  group('ReceivedDelivery totals', () {
    test('calculates document totals at Cost Price', () {
      final delivery = buildDraft(
        items: <ReceivedDeliveryItem>[
          buildDeliveryItem(
            id: 'item-001',
            productId: 'product-001',
            sku: 'SKU-001',
            orderedQuantity: 10,
            receivedQuantity: 8,
            costPrice: 100,
          ),
          buildDeliveryItem(
            id: 'item-002',
            productId: 'product-002',
            sku: 'SKU-002',
            orderedQuantity: 5,
            receivedQuantity: 5,
            costPrice: 50,
          ),
        ],
      );

      delivery.validate();

      expect(delivery.totalSkus, 2);
      expect(delivery.totalOrderedQuantity, 15);
      expect(delivery.totalReceivedQuantity, 13);
      expect(delivery.totalCost, 1050);
    });

    test('normalizes DR and Invoice numbers', () {
      final delivery = buildDraft(drNumber: ' dr-000001 ');

      expect(delivery.normalizedDrNumber, 'DR-000001');

      expect(delivery.normalizedInvoiceNumber, 'INV-001');
    });

    test('blocks duplicate SKU', () {
      final delivery = buildDraft(
        items: <ReceivedDeliveryItem>[
          buildDeliveryItem(),
          buildDeliveryItem(id: 'item-002', productId: 'product-002'),
        ],
      );

      expect(
        delivery.validate,
        throwsA(isA<ReceivedDeliveryValidationException>()),
      );
    });

    test('blocks duplicate product', () {
      final delivery = buildDraft(
        items: <ReceivedDeliveryItem>[
          buildDeliveryItem(),
          buildDeliveryItem(id: 'item-002', sku: 'SKU-002'),
        ],
      );

      expect(
        delivery.validate,
        throwsA(isA<ReceivedDeliveryValidationException>()),
      );
    });
  });

  group('ReceivedDelivery workflow', () {
    test('draft is editable and can submit', () {
      final draft = buildDraft();

      expect(draft.canEdit, isTrue);
      expect(draft.canSubmit, isTrue);
      expect(draft.canApprove, isFalse);
    });

    test('submitted delivery does not process inventory', () {
      final submitted = buildDraft().submit(
        userId: 'inventory-user',
        timestamp: 200,
      );

      expect(submitted.status, InventoryDocumentStatus.submitted);

      expect(submitted.inventoryProcessed, isFalse);

      expect(submitted.submittedBy, 'inventory-user');
    });

    test('submitted delivery can be approved', () {
      final approved = buildDraft()
          .submit(userId: 'inventory-user', timestamp: 200)
          .approve(userId: 'manager-001', timestamp: 300);

      expect(approved.status, InventoryDocumentStatus.approved);

      expect(approved.approvedBy, 'manager-001');

      expect(approved.isEligibleForInventoryProcessing, isTrue);

      expect(approved.inventoryProcessed, isFalse);
    });

    test('submitted delivery can be rejected', () {
      final rejected = buildDraft()
          .submit(userId: 'inventory-user', timestamp: 200)
          .reject(
            userId: 'manager-001',
            timestamp: 300,
            reason: 'Incorrect delivery.',
          );

      expect(rejected.status, InventoryDocumentStatus.rejected);

      expect(rejected.rejectionRemarks, 'Incorrect delivery.');

      expect(rejected.inventoryProcessed, isFalse);
    });

    test('rejection requires remarks', () {
      final submitted = buildDraft().submit(
        userId: 'inventory-user',
        timestamp: 200,
      );

      expect(() {
        submitted.reject(userId: 'manager-001', timestamp: 300, reason: ' ');
      }, throwsA(isA<ReceivedDeliveryValidationException>()));
    });

    test('approved delivery can be processed once', () {
      final approved = buildDraft()
          .submit(userId: 'inventory-user', timestamp: 200)
          .approve(userId: 'manager-001', timestamp: 300);

      final processed = approved.markInventoryProcessed(
        processingId: 'DELIVERY:DR-000001',
        userId: 'manager-001',
        timestamp: 400,
      );

      expect(processed.inventoryProcessed, isTrue);

      expect(processed.isInventoryProcessingComplete, isTrue);

      expect(processed.inventoryProcessingId, 'DELIVERY:DR-000001');

      expect(() {
        processed.markInventoryProcessed(
          processingId: 'DELIVERY:DR-000001',
          userId: 'manager-001',
          timestamp: 500,
        );
      }, throwsA(isA<ReceivedDeliveryValidationException>()));
    });

    test('draft cannot process inventory', () {
      expect(() {
        buildDraft().markInventoryProcessed(
          processingId: 'DELIVERY:DR-000001',
          userId: 'manager-001',
          timestamp: 400,
        );
      }, throwsA(isA<ReceivedDeliveryValidationException>()));
    });
  });

  group('ReceivedDelivery serialization', () {
    test('stores summary and audit values', () {
      final map = buildDraft().toMap();

      expect(map['drNumber'], 'DR-000001');

      expect(map['supplier'], 'Test Supplier');

      expect(map['totalSkus'], 1);

      expect(map['totalReceivedQuantity'], 10);

      expect(map['totalCost'], 1000);
    });

    test('contains no Retail or Selling fields', () {
      final map = buildDraft().toMap();
      final text = map.toString().toLowerCase();

      expect(text.contains('retail'), isFalse);

      expect(text.contains('selling'), isFalse);

      expect(text.contains('margin'), isFalse);
    });

    test('restores draft from Firebase map', () {
      final original = buildDraft();

      final restored = ReceivedDelivery.fromMap(
        Map<Object?, Object?>.from(original.toMap()),
      );

      expect(restored.drNumber, 'DR-000001');

      expect(restored.supplier, 'Test Supplier');

      expect(restored.totalSkus, 1);

      expect(restored.totalCost, 1000);
    });
  });
}
