import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/screens/adjustment/adjustment_module_screen.dart';

void main() {
  testWidgets('Adjustment Module is separate from Inventory', (tester) async {
    tester.view.physicalSize = const Size(390, 844);

    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);

    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AdjustmentModuleScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Adjustment Module'), findsOneWidget);

    expect(find.text('Adjustments'), findsAtLeastNWidgets(1));

    expect(find.text('Adjustment Types'), findsOneWidget);

    expect(find.text('NEW ADJUSTMENT'), findsOneWidget);

    expect(find.text('No Adjustments Yet'), findsOneWidget);

    expect(find.textContaining('Cost Price'), findsAtLeastNWidgets(1));

    expect(find.textContaining('Retail'), findsNothing);
  });
}
