import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/screens/received_delivery/received_delivery_module_screen.dart';

void main() {
  testWidgets('Received Delivery premium shell is responsive', (tester) async {
    tester.view.physicalSize = const Size(390, 844);

    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);

    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ReceivedDeliveryModuleScreen()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Received Delivery'), findsOneWidget);

    expect(find.text('NEW RECEIVED DELIVERY'), findsOneWidget);

    expect(find.text('Search DR Number or Supplier'), findsOneWidget);

    expect(find.text('All'), findsOneWidget);

    expect(find.text('Draft'), findsOneWidget);

    expect(find.text('Submitted'), findsOneWidget);

    expect(find.text('Approved'), findsOneWidget);

    expect(find.text('No Received Deliveries Yet'), findsOneWidget);

    expect(find.text('Draft → Submitted'), findsOneWidget);

    expect(find.text('Approved Increases SOH'), findsOneWidget);

    expect(find.text('Received Qty × Cost Price'), findsOneWidget);

    expect(find.text('No Retail Price'), findsOneWidget);

    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
  });

  testWidgets('Received Delivery filters change empty state', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);

    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);

    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ReceivedDeliveryModuleScreen()),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Approved'));

    await tester.pumpAndSettle();

    expect(find.text('No Approved Deliveries'), findsOneWidget);

    expect(find.text('Rejected'), findsOneWidget);
  });
}
