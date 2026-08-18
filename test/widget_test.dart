import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/main.dart';

void main() {
  testWidgets('Simple POS dashboard displays core modules', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SimplePosApp());
    await tester.pumpAndSettle();

    expect(find.text('Simple POS'), findsOneWidget);
    expect(find.text('Cashiering'), findsAtLeastNWidgets(1));
    expect(find.text('Products'), findsAtLeastNWidgets(1));
    expect(find.text('Inventory'), findsAtLeastNWidgets(1));
    expect(find.text('Sales History'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Firebase Connected'), findsAtLeastNWidgets(1));
    expect(find.textContaining('pos-software-ef89c'), findsOneWidget);
  });
}
