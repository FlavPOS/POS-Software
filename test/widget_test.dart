import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/main.dart';

void main() {
  testWidgets('Simple POS dashboard displays core modules', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SimplePosApp());
    await tester.pumpAndSettle();

    expect(find.text('Simple POS'), findsOneWidget);
    expect(find.text('Cashiering'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Sales History'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Firebase Connected'), findsOneWidget);
    expect(find.text('Project: pos-software-ef89c'), findsOneWidget);
  });
}
