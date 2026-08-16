import 'package:flutter_test/flutter_test.dart';
import 'package:simple_pos/models/product_operation_progress.dart';

void main() {
  group('Product operation progress', () {
    test('10 out of 24 displays 42 percent', () {
      const progress = ProductOperationProgress(
        title: 'Importing Products',
        completed: 10,
        total: 24,
      );

      expect(progress.percentage, 42);

      expect(progress.progressValue, closeTo(10 / 24, 0.0001));

      expect(progress.countLabel, '10 of 24 products completed');
    });

    test('completed count is clamped to total', () {
      const progress = ProductOperationProgress(
        title: 'Updating Products',
        completed: 30,
        total: 24,
      );

      expect(progress.safeCompleted, 24);

      expect(progress.percentage, 100);

      expect(progress.countLabel, '24 of 24 products completed');
    });

    test('negative count is clamped to zero', () {
      const progress = ProductOperationProgress(
        title: 'Deleting Products',
        completed: -2,
        total: 10,
      );

      expect(progress.safeCompleted, 0);

      expect(progress.percentage, 0);
    });

    test('unknown total is indeterminate', () {
      const progress = ProductOperationProgress.preparing(
        title: 'Preparing Export',
      );

      expect(progress.isIndeterminate, isTrue);

      expect(progress.progressValue, isNull);

      expect(progress.percentage, isNull);
    });

    test('picture unit label is supported', () {
      const progress = ProductOperationProgress(
        title: 'Updating Product Pictures',
        completed: 18,
        total: 24,
        unitLabel: 'pictures',
      );

      expect(progress.percentage, 75);

      expect(progress.countLabel, '18 of 24 pictures completed');
    });

    test('controller updates current item', () {
      final controller = ProductOperationProgressController(
        title: 'Importing Products',
      );

      controller.start(total: 24);

      controller.update(completed: 10, currentItem: 'SKU 12345617');

      expect(controller.value.percentage, 42);

      expect(controller.value.currentItem, 'SKU 12345617');

      controller.dispose();
    });

    test('controller reaches completed status', () {
      final controller = ProductOperationProgressController(
        title: 'Updating Products',
      );

      controller.start(total: 10);

      controller.complete(detail: 'All products processed.');

      expect(controller.value.completed, 10);

      expect(controller.value.percentage, 100);

      expect(controller.value.isComplete, isTrue);

      controller.dispose();
    });
  });
}
