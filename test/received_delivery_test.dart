import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/received_delivery.dart';

ReceivedDeliveryItem buildItem({
  String id = 'delivery-item-001',
  String productId = 'product-001',
  String sku = 'SKU-001',
  String productName = 'Test Product',
  int currentOnHand = 20,
  int orderedQuantity = 10,
  int receivedQuantity = 10,
  double costPrice = 100,
  String? lotBatchNumber = 'LOT-001',
  int? expiryDate = 200,
}) {
  return ReceivedDeliveryItem(
    id: id,
    productId: productId,
    sku: sku,
    productName: productName,
    currentOnHand: currentOnHand,
    orderedQuantity: orderedQuantity,
    receivedQuantity: receivedQuantity,
    costPrice: costPrice,
    lotBatchNumber: lotBatchNumber,
    expiryDate: expiryDate,
  );
}

void main() {
  group('ReceivedDeliveryItem', () {
    test('calculates Total Cost using '
        'Received Qty multiplied by Cost Price', () {
      final item = buildItem();

      expect(item.totalCost, 1000);
    });

    test('increases SOH using Received Qty', () {
      final item = buildItem();

      expect(item.currentOnHand, 20);

      expect(item.receivedQuantity, 10);

      expect(item.newOnHand, 30);

      expect(item.quantityIn, 10);

      expect(item.quantityOut, 0);
    });

    test('supports partial receipt', () {
      final item = buildItem(orderedQuantity: 10, receivedQuantity: 6);

      expect(item.isPartiallyReceived, isTrue);

      expect(item.isFullyReceived, isFalse);

      expect(item.totalCost, 600);

      expect(item.newOnHand, 26);
    });

    test('supports zero Received Qty', () {
      final item = buildItem(receivedQuantity: 0);

      item.validate();

      expect(item.isNotReceived, isTrue);

      expect(item.totalCost, 0);

      expect(item.newOnHand, 20);
    });

    test('blocks Received Qty above Ordered Qty', () {
      final item = buildItem(orderedQuantity: 10, receivedQuantity: 11);

      expect(
        item.validate,
        throwsA(isA<ReceivedDeliveryValidationException>()),
      );
    });

    test('allows explicit over-receipt validation', () {
      final item = buildItem(orderedQuantity: 10, receivedQuantity: 11);

      expect(() {
        item.validate(allowOverReceipt: true);
      }, returnsNormally);
    });

    test('rejects negative Ordered Qty', () {
      final item = buildItem(orderedQuantity: -1);

      expect(
        item.validate,
        throwsA(isA<ReceivedDeliveryValidationException>()),
      );
    });

    test('rejects negative Received Qty', () {
      final item = buildItem(receivedQuantity: -1);

      expect(
        item.validate,
        throwsA(isA<ReceivedDeliveryValidationException>()),
      );
    });

    test('rejects negative Cost Price', () {
      final item = buildItem(costPrice: -1);

      expect(
        item.validate,
        throwsA(isA<ReceivedDeliveryValidationException>()),
      );
    });

    test('normalizes SKU and Batch Number', () {
      final item = buildItem(sku: ' sku-001 ', lotBatchNumber: ' LOT-001 ');

      expect(item.normalizedSku, 'SKU-001');

      expect(item.normalizedLotBatchNumber, 'LOT-001');
    });

    test('serializes Cost Price only', () {
      final map = buildItem().toMap();

      expect(map['costPrice'], 100);

      expect(map['totalCost'], 1000);

      expect(map.containsKey('retailPrice'), isFalse);

      expect(map.containsKey('sellingPrice'), isFalse);

      expect(map.containsKey('margin'), isFalse);
    });

    test('serializes Batch and Expiry Date', () {
      final map = buildItem().toMap();

      expect(map['lotBatchNumber'], 'LOT-001');

      expect(map['expiryDate'], 200);
    });

    test('restores item from Firebase map', () {
      final original = buildItem();

      final restored = ReceivedDeliveryItem.fromMap(
        Map<Object?, Object?>.from(original.toMap()),
      );

      expect(restored.sku, 'SKU-001');

      expect(restored.receivedQuantity, 10);

      expect(restored.totalCost, 1000);

      expect(restored.newOnHand, 30);
    });

    test('restores Firebase item using fallback ID', () {
      final map = Map<Object?, Object?>.from(buildItem().toMap());

      map.remove('id');

      final restored = ReceivedDeliveryItem.fromMap(
        map,
        fallbackId: 'delivery-item-001',
      );

      expect(restored.id, 'delivery-item-001');
    });
  });
}
