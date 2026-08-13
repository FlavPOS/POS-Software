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
    expect(find.text('Cashiering'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Sales History'), findsOneWidget);
    expect(find.textContaining('Firebase Connected'), findsOneWidget);
    expect(find.textContaining('pos-software-ef89c'), findsOneWidget);
  });
}
