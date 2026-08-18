import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/screens/received_delivery/received_delivery_module_screen.dart';

void main() {
  testWidgets('Received Delivery is a separate cost-only module', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);

    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);

    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ReceivedDeliveryModuleScreen()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Received Delivery'), findsOneWidget);

    expect(find.text('Received Deliveries'), findsOneWidget);

    expect(find.text('NEW RECEIVED DELIVERY'), findsOneWidget);

    expect(find.text('Draft'), findsOneWidget);

    expect(find.text('Submitted'), findsOneWidget);

    expect(find.text('Approved'), findsOneWidget);

    expect(find.text('Rejected'), findsOneWidget);

    expect(find.textContaining('Cost Price'), findsAtLeastNWidgets(1));

    expect(find.textContaining('No Retail Price'), findsOneWidget);
  });
}
