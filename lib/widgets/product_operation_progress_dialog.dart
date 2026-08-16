import 'package:flutter/material.dart';

import '../models/product_operation_progress.dart';

Future<void> showProductOperationProgressDialog({
  required BuildContext context,
  required ProductOperationProgressController controller,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: ProductOperationProgressDialog(controller: controller),
      );
    },
  );
}

class ProductOperationProgressDialog extends StatelessWidget {
  const ProductOperationProgressDialog({super.key, required this.controller});

  final ProductOperationProgressController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProductOperationProgress>(
      valueListenable: controller,
      builder: (context, progress, child) {
        final color = _statusColor(progress);

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          title: Row(
            children: [
              _StatusIcon(progress: progress, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!progress.isIndeterminate)
                Text(
                  progress.percentageLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.progressValue,
                    minHeight: 14,
                    color: color,
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  progress.countLabel,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (progress.currentItem != null) ...[
                  const SizedBox(height: 8),
                  _InformationLine(
                    icon: Icons.inventory_2_outlined,
                    label: 'Current',
                    value: progress.currentItem!,
                  ),
                ],
                if (progress.detail != null) ...[
                  const SizedBox(height: 7),
                  _InformationLine(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: progress.detail!,
                  ),
                ],
                if (progress.hasFailed && progress.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      progress.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(ProductOperationProgress progress) {
    switch (progress.status) {
      case ProductOperationProgressStatus.preparing:
      case ProductOperationProgressStatus.running:
        return const Color(0xFF0EA5E9);

      case ProductOperationProgressStatus.completed:
        return const Color(0xFF16A34A);

      case ProductOperationProgressStatus.failed:
        return const Color(0xFFDC2626);
    }
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.progress, required this.color});

  final ProductOperationProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (progress.isComplete) {
      return Icon(Icons.check_circle, color: color, size: 28);
    }

    if (progress.hasFailed) {
      return Icon(Icons.error, color: color, size: 28);
    }

    return SizedBox(
      width: 25,
      height: 25,
      child: CircularProgressIndicator(strokeWidth: 3, color: color),
    );
  }
}

class _InformationLine extends StatelessWidget {
  const _InformationLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF64748B)),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
