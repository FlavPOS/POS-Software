import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/product.dart';
import 'package:simple_pos/screens/inventory/inventory_module_screen.dart';

void main() {
  testWidgets('Inventory opens direct employee SOH lookup', (tester) async {
    tester.view.physicalSize = const Size(390, 844);

    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);

    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryModuleScreen(
          productStream: Stream<List<Product>>.value(const <Product>[]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Inventory'), findsOneWidget);

    expect(find.byType(TextField), findsOneWidget);

    expect(find.text('Adjustment'), findsNothing);

    expect(find.text('Received Delivery'), findsNothing);

    expect(find.text('Adjustment Types'), findsNothing);
  });
}
