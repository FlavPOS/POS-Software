import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/screens/inventory/inventory_module_screen.dart';

void main() {
  testWidgets('Inventory Module displays all sections', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);

    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: InventoryModuleScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Inventory Module'), findsOneWidget);

    expect(find.text('Inventory'), findsAtLeastNWidgets(1));

    expect(find.text('Adjustment'), findsOneWidget);

    expect(find.text('Received Delivery'), findsOneWidget);

    expect(find.text('Adjustment Types'), findsOneWidget);

    expect(find.text('Current Inventory'), findsOneWidget);

    expect(find.textContaining('OH × Cost Price'), findsAtLeastNWidgets(1));

    expect(find.textContaining('No Retail Price'), findsOneWidget);
  });
}
