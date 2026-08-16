import 'package:flutter/material.dart';

import '../models/product_update.dart';
import '../services/product_update_save_service.dart';

enum _ProductUpdateFilter { all, ready, noChange, unmatched, invalid }

class ProductUpdateReviewScreen extends StatefulWidget {
  const ProductUpdateReviewScreen({super.key, required this.result});

  final ProductUpdateParseResult result;

  @override
  State<ProductUpdateReviewScreen> createState() {
    return _ProductUpdateReviewScreenState();
  }
}

class _ProductUpdateReviewScreenState extends State<ProductUpdateReviewScreen> {
  final ProductUpdateSaveService _saveService =
      ProductUpdateSaveService.instance;

  _ProductUpdateFilter _filter = _ProductUpdateFilter.all;

  bool _updating = false;

  List<ProductUpdateRow> get _filteredRows {
    switch (_filter) {
      case _ProductUpdateFilter.ready:
        return widget.result.rows
            .where((row) => row.status == ProductUpdateRowStatus.ready)
            .toList();

      case _ProductUpdateFilter.noChange:
        return widget.result.rows
            .where((row) => row.status == ProductUpdateRowStatus.noChange)
            .toList();

      case _ProductUpdateFilter.unmatched:
        return widget.result.rows
            .where((row) => row.status == ProductUpdateRowStatus.unmatched)
            .toList();

      case _ProductUpdateFilter.invalid:
        return widget.result.rows
            .where(
              (row) =>
                  row.status == ProductUpdateRowStatus.invalid ||
                  row.status == ProductUpdateRowStatus.duplicateSku ||
                  row.status == ProductUpdateRowStatus.duplicateBarcode,
            )
            .toList();

      case _ProductUpdateFilter.all:
        return widget.result.rows;
    }
  }

  int _countFor(_ProductUpdateFilter filter) {
    switch (filter) {
      case _ProductUpdateFilter.all:
        return widget.result.rowsFound;

      case _ProductUpdateFilter.ready:
        return widget.result.ready;

      case _ProductUpdateFilter.noChange:
        return widget.result.noChange;

      case _ProductUpdateFilter.unmatched:
        return widget.result.unmatched;

      case _ProductUpdateFilter.invalid:
        return widget.result.invalid +
            widget.result.duplicateSku +
            widget.result.duplicateBarcode;
    }
  }

  String _labelFor(_ProductUpdateFilter filter) {
    switch (filter) {
      case _ProductUpdateFilter.all:
        return 'All';

      case _ProductUpdateFilter.ready:
        return 'Ready';

      case _ProductUpdateFilter.noChange:
        return 'No Change';

      case _ProductUpdateFilter.unmatched:
        return 'Unmatched';

      case _ProductUpdateFilter.invalid:
        return 'Invalid';
    }
  }

  Future<void> _applyUpdates() async {
    if (_updating || !widget.result.hasReadyRows) {
      return;
    }

    final count = widget.result.ready;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(
                'Update $count Existing '
                'Product${count == 1 ? '' : 's'}?',
              ),
              content: const Text(
                'Only the changes shown in this '
                'preview will be applied.\n\n'
                'SKU, Product ID, Beginning Stock, '
                'Current Stock, and transaction '
                'history will remain unchanged.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('Update Products'),
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
      _updating = true;
    });

    try {
      final result = await _saveService.saveReadyRows(widget.result);

      if (!mounted) {
        return;
      }

      final returnToProducts = await _showResults(result);

      if (returnToProducts && mounted) {
        Navigator.pop(context, result.hasUpdates);
      } else if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update products: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  Future<bool> _showResults(ProductUpdateSaveResult result) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Product Update Results'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ResultLine(label: 'Rows Found', value: result.rowsFound),
                    _ResultLine(
                      label: 'Products Updated',
                      value: result.updated,
                    ),
                    _ResultLine(label: 'No Changes', value: result.noChange),
                    _ResultLine(
                      label: 'Products Skipped',
                      value: result.skipped,
                    ),
                    _ResultLine(label: 'Products Failed', value: result.failed),
                    _ResultLine(
                      label: 'Pictures Updated',
                      value: result.picturesUpdated,
                    ),
                    if (result.failedRows.isNotEmpty) ...[
                      const Divider(height: 26),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Failed Products',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...result.failedRows.map((row) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '• ${row.normalizedSku}\n'
                              '  ${row.saveError ?? 'Update failed.'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
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
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Update Preview',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: _buildBottomAction(),
      body: SafeArea(
        child: Column(
          children: [
            _buildSummary(),
            _buildFilters(),
            if (widget.result.hasPackageWarnings) _buildWarnings(),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No rows match this filter.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: rows.length,
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 10);
                      },
                      itemBuilder: (context, index) {
                        return _ProductUpdateCard(row: rows[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 18,
        runSpacing: 10,
        children: [
          _SummaryMetric(
            label: 'Rows',
            value: widget.result.rowsFound,
            color: const Color(0xFF5B5CEB),
          ),
          _SummaryMetric(
            label: 'Ready',
            value: widget.result.ready,
            color: const Color(0xFF047857),
          ),
          _SummaryMetric(
            label: 'No Change',
            value: widget.result.noChange,
            color: const Color(0xFF6B7280),
          ),
          _SummaryMetric(
            label: 'Unmatched',
            value: widget.result.unmatched,
            color: const Color(0xFFC2410C),
          ),
          _SummaryMetric(
            label: 'Invalid',
            value:
                widget.result.invalid +
                widget.result.duplicateSku +
                widget.result.duplicateBarcode,
            color: const Color(0xFFB91C1C),
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
        children: _ProductUpdateFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: _filter == filter,
              label: Text(
                '${_labelFor(filter)} '
                '(${_countFor(filter)})',
              ),
              onSelected: _updating
                  ? null
                  : (_) {
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

  Widget _buildWarnings() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Package Warnings',
            style: TextStyle(
              color: Color(0xFFC2410C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.result.packageWarnings.map((warning) {
            return Text(
              '• $warning',
              style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: !widget.result.hasReadyRows || _updating
              ? null
              : _applyUpdates,
          icon: _updating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.system_update_alt),
          label: Text(
            _updating
                ? 'Updating Products...'
                : 'Update '
                      '${widget.result.ready} '
                      'Product'
                      '${widget.result.ready == 1 ? '' : 's'}',
          ),
        ),
      ),
    );
  }
}

class _ProductUpdateCard extends StatelessWidget {
  const _ProductUpdateCard({required this.row});

  final ProductUpdateRow row;

  Color get _statusColor {
    switch (row.status) {
      case ProductUpdateRowStatus.ready:
        return const Color(0xFF047857);

      case ProductUpdateRowStatus.noChange:
        return const Color(0xFF6B7280);

      case ProductUpdateRowStatus.unmatched:
        return const Color(0xFFC2410C);

      case ProductUpdateRowStatus.duplicateSku:
      case ProductUpdateRowStatus.duplicateBarcode:
      case ProductUpdateRowStatus.invalid:
        return const Color(0xFFB91C1C);

      case ProductUpdateRowStatus.pending:
        return const Color(0xFF5B5CEB);
    }
  }

  String get _statusLabel {
    switch (row.status) {
      case ProductUpdateRowStatus.ready:
        return 'READY';

      case ProductUpdateRowStatus.noChange:
        return 'NO CHANGE';

      case ProductUpdateRowStatus.unmatched:
        return 'UNMATCHED';

      case ProductUpdateRowStatus.duplicateSku:
        return 'DUPLICATE SKU';

      case ProductUpdateRowStatus.duplicateBarcode:
        return 'DUPLICATE BARCODE';

      case ProductUpdateRowStatus.invalid:
        return 'INVALID';

      case ProductUpdateRowStatus.pending:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName =
        row.existingProduct?.name ?? row.productName ?? 'Product Not Found';

    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _statusColor.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _StatusBadge(label: _statusLabel, color: _statusColor),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'SKU: '
              '${row.normalizedSku.isEmpty ? '(missing)' : row.normalizedSku}'
              ' • Excel Row ${row.excelRowNumber}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            if (row.changes.isNotEmpty) ...[
              const Divider(height: 22),
              ...row.changes.map((change) {
                return _ChangeRow(change: change);
              }),
            ],
            if (row.errors.isNotEmpty) ...[
              const Divider(height: 22),
              ...row.errors.map((error) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '• $error',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            ],
            if (row.warnings.isNotEmpty) ...[
              const Divider(height: 22),
              ...row.warnings.map((warning) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '• $warning',
                    style: const TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            ],
            if (row.updateRemarks != null &&
                row.updateRemarks!.trim().isNotEmpty) ...[
              const Divider(height: 22),
              Text(
                'Remarks: ${row.updateRemarks}',
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final ProductUpdateFieldChange change;

  bool get _isPrice {
    return change.fieldName == 'Cost Price' ||
        change.fieldName == 'Selling Price';
  }

  String _display(String value) {
    if (!_isPrice || value == '(blank)') {
      return value;
    }

    return 'PHP $value';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.fieldName,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  _display(change.currentDisplay),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 17,
                  color: Color(0xFF7C3AED),
                ),
              ),
              Expanded(
                child: Text(
                  _display(change.proposedDisplay),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

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
              color: Color(0xFF5B21B6),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
