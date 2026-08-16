import 'package:flutter/material.dart';

import '../models/product_operation_progress.dart';
import '../widgets/product_operation_progress_dialog.dart';
import '../models/product_import_parse_result.dart';
import '../models/product_import_row.dart';
import '../services/product_import_save_service.dart';

enum _ReviewFilter { all, valid, warnings, errors }

class ProductImportReviewScreen extends StatefulWidget {
  const ProductImportReviewScreen({super.key, required this.result});

  final ProductImportParseResult result;

  @override
  State<ProductImportReviewScreen> createState() =>
      _ProductImportReviewScreenState();
}

class _ProductImportReviewScreenState extends State<ProductImportReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  final ProductImportSaveService _importSaveService =
      ProductImportSaveService.instance;

  bool _saving = false;

  List<ProductImportRow> get _filteredRows {
    switch (_filter) {
      case _ReviewFilter.valid:
        return widget.result.rows.where((row) => row.isValid).toList();

      case _ReviewFilter.warnings:
        return widget.result.rows.where((row) => row.hasWarnings).toList();

      case _ReviewFilter.errors:
        return widget.result.rows.where((row) => !row.isValid).toList();

      case _ReviewFilter.all:
        return widget.result.rows;
    }
  }

  int _countFor(_ReviewFilter filter) {
    switch (filter) {
      case _ReviewFilter.all:
        return widget.result.totalRows;

      case _ReviewFilter.valid:
        return widget.result.validRows;

      case _ReviewFilter.warnings:
        return widget.result.warningRows;

      case _ReviewFilter.errors:
        return widget.result.errorRows;
    }
  }

  String _labelFor(_ReviewFilter filter) {
    switch (filter) {
      case _ReviewFilter.all:
        return 'All';

      case _ReviewFilter.valid:
        return 'Valid';

      case _ReviewFilter.warnings:
        return 'Warnings';

      case _ReviewFilter.errors:
        return 'Errors';
    }
  }

  Future<void> _importValidProducts() async {
    if (_saving || !widget.result.hasValidRows) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Import Valid Products?'),
              content: Text(
                '${widget.result.validRows} valid '
                'product row(s) will be imported.\n\n'
                'Existing SKUs or barcodes will be '
                'skipped and will not be overwritten.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Import'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final progressController = ProductOperationProgressController(
        title: 'Importing Products',
        unitLabel: 'products',
        detail: 'Preparing product import...',
      );

      final progressDialog = showProductOperationProgressDialog(
        context: context,
        controller: progressController,
      );

      await Future<void>.delayed(Duration.zero);

      final result = await _importSaveService.importValidRows(
        widget.result,
        onProgress: ({required completed, required total, currentSku, detail}) {
          if (total > 0 && progressController.value.total == 0) {
            progressController.start(
              total: total,
              currentItem: currentSku,
              detail: detail,
            );
            return;
          }

          progressController.update(
            completed: completed,
            currentItem: currentSku,
            detail: detail,
          );
        },
      );

      progressController.complete(detail: 'Product import completed.');

      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      await progressDialog;
      progressController.dispose();

      if (!mounted) {
        return;
      }

      final closeReview =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              final summary = result.summary;

              return AlertDialog(
                title: const Text('Product Import Results'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ImportResultLine(
                      label: 'Imported',
                      value: summary.imported,
                    ),
                    _ImportResultLine(label: 'Skipped', value: summary.skipped),
                    _ImportResultLine(label: 'Failed', value: summary.failed),
                    const Divider(height: 24),
                    _ImportResultLine(
                      label: 'Pictures Saved',
                      value: summary.picturesSaved,
                    ),
                    _ImportResultLine(
                      label: 'Pictures Missing',
                      value: summary.picturesMissing,
                    ),
                    _ImportResultLine(
                      label: 'Pictures Failed',
                      value: summary.picturesFailed,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false);
                    },
                    child: const Text('Stay on Review'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Back to Products'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (closeReview && mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to complete the import: '
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Import Rows',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: widget.result.hasValidRows && !_saving
                ? _importValidProducts
                : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.inventory_2_outlined),
            label: Text(
              _saving
                  ? 'Importing Products...'
                  : 'Import '
                        '${widget.result.validRows} '
                        'Valid Product'
                        '${widget.result.validRows == 1 ? '' : 's'}',
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSummary(),
          _buildFilters(),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No rows match this filter.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      return _ImportRowCard(row: rows[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _SummaryValue(label: 'Rows', value: widget.result.totalRows),
          _SummaryValue(label: 'Valid', value: widget.result.validRows),
          _SummaryValue(label: 'Warnings', value: widget.result.warningRows),
          _SummaryValue(label: 'Errors', value: widget.result.errorRows),
          _SummaryValue(
            label: 'Pictures',
            value: widget.result.picturesMatched,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _ReviewFilter.values.map((filter) {
          final selected = _filter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(
                '${_labelFor(filter)} '
                '(${_countFor(filter)})',
              ),
              onSelected: (_) {
                setState(() {
                  _filter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ImportRowCard extends StatelessWidget {
  const _ImportRowCard({required this.row});

  final ProductImportRow row;

  Color get _statusColor {
    if (!row.isValid) {
      return const Color(0xFFB91C1C);
    }

    if (row.hasWarnings) {
      return const Color(0xFFC2410C);
    }

    return const Color(0xFF047857);
  }

  String get _statusLabel {
    if (!row.isValid) {
      return 'ERROR';
    }

    if (row.hasWarnings) {
      return 'WARNING';
    }

    return 'VALID';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: _buildPicture(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                row.productName.trim().isEmpty
                    ? 'Unnamed Product'
                    : row.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            'Excel Row ${row.rowNumber}\n'
            'SKU: ${row.normalizedSku.isEmpty ? '(missing)' : row.normalizedSku}',
          ),
        ),
        children: [
          _DetailLine(label: 'Category', value: row.category ?? '-'),
          _DetailLine(label: 'Subcategory', value: row.subcategory ?? '-'),
          _DetailLine(label: 'Class', value: row.productClass ?? '-'),
          _DetailLine(label: 'Barcode', value: row.normalizedBarcode ?? '-'),
          _DetailLine(
            label: 'Cost Price',
            value: 'PHP ${row.costPrice.toStringAsFixed(2)}',
          ),
          _DetailLine(
            label: 'Selling Price',
            value: 'PHP ${row.sellingPrice.toStringAsFixed(2)}',
          ),
          _DetailLine(
            label: 'Current Stock',
            value: row.currentStock.toString(),
          ),
          _DetailLine(
            label: 'Minimum Stock',
            value: row.minimumStock.toString(),
          ),
          _DetailLine(
            label: 'Maximum Stock',
            value: row.maximumStock.toString(),
          ),
          _DetailLine(
            label: 'Picture',
            value: row.hasPicture
                ? 'Matched'
                : row.normalizedPictureFileName == null
                ? 'Not supplied'
                : 'Missing',
          ),
          if (row.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MessageSection(
              title: 'Errors',
              messages: row.errors,
              color: const Color(0xFFB91C1C),
            ),
          ],
          if (row.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _MessageSection(
              title: 'Warnings',
              messages: row.warnings,
              color: const Color(0xFFC2410C),
            ),
          ],
          if (row.importRemarks?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            _MessageSection(
              title: 'Import Remarks',
              messages: <String>[row.importRemarks!.trim()],
              color: const Color(0xFF5B5CEB),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPicture() {
    if (row.hasPicture) {
      return CircleAvatar(
        backgroundColor: const Color(0xFFEDE9FE),
        backgroundImage: MemoryImage(row.pictureBytes!),
      );
    }

    return const CircleAvatar(
      backgroundColor: Color(0xFFEDE9FE),
      child: Icon(Icons.inventory_2_outlined, color: Color(0xFF6D28D9)),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MessageSection extends StatelessWidget {
  const _MessageSection({
    required this.title,
    required this.messages,
    required this.color,
  });

  final String title;
  final List<String> messages;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $message',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportResultLine extends StatelessWidget {
  const _ImportResultLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Color(0xFF5B5CEB),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          value.toString(),
          style: const TextStyle(
            color: Color(0xFF5B5CEB),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
