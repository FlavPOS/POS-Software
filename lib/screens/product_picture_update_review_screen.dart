import 'package:flutter/material.dart';

import '../models/product_picture_update.dart';
import '../services/product_picture_update_save_service.dart';

enum _PictureReviewFilter { all, matched, unmatched, duplicates, invalid }

class ProductPictureUpdateReviewScreen extends StatefulWidget {
  const ProductPictureUpdateReviewScreen({super.key, required this.package});

  final ProductPictureUpdatePackage package;

  @override
  State<ProductPictureUpdateReviewScreen> createState() {
    return _ProductPictureUpdateReviewScreenState();
  }
}

class _ProductPictureUpdateReviewScreenState
    extends State<ProductPictureUpdateReviewScreen> {
  final ProductPictureUpdateSaveService _saveService =
      ProductPictureUpdateSaveService.instance;

  _PictureReviewFilter _filter = _PictureReviewFilter.all;

  bool _updating = false;

  List<ProductPictureUpdateItem> get _filteredItems {
    switch (_filter) {
      case _PictureReviewFilter.matched:
        return widget.package.items.where((item) => item.isMatched).toList();

      case _PictureReviewFilter.unmatched:
        return widget.package.items.where((item) => item.isUnmatched).toList();

      case _PictureReviewFilter.duplicates:
        return widget.package.items.where((item) => item.isDuplicate).toList();

      case _PictureReviewFilter.invalid:
        return widget.package.items.where((item) => item.isInvalid).toList();

      case _PictureReviewFilter.all:
        return widget.package.items;
    }
  }

  int _countFor(_PictureReviewFilter filter) {
    switch (filter) {
      case _PictureReviewFilter.all:
        return widget.package.picturesFound;

      case _PictureReviewFilter.matched:
        return widget.package.matched;

      case _PictureReviewFilter.unmatched:
        return widget.package.unmatched;

      case _PictureReviewFilter.duplicates:
        return widget.package.duplicates;

      case _PictureReviewFilter.invalid:
        return widget.package.invalid;
    }
  }

  String _labelFor(_PictureReviewFilter filter) {
    switch (filter) {
      case _PictureReviewFilter.all:
        return 'All';

      case _PictureReviewFilter.matched:
        return 'Matched';

      case _PictureReviewFilter.unmatched:
        return 'Unmatched';

      case _PictureReviewFilter.duplicates:
        return 'Duplicates';

      case _PictureReviewFilter.invalid:
        return 'Invalid';
    }
  }

  Future<void> _updatePictures() async {
    if (_updating || !widget.package.hasMatchedPictures) {
      return;
    }

    final count = widget.package.matched;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(
                'Update $count Product '
                'Picture${count == 1 ? '' : 's'}?',
              ),
              content: const Text(
                'Only saved product pictures '
                'will be replaced.\n\n'
                'Product names, SKUs, barcodes, '
                'pricing, stocks, classifications, '
                'and active status will remain '
                'unchanged.',
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
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Update Pictures'),
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
      final result = await _saveService.updateMatchedPictures(widget.package);

      if (!mounted) {
        return;
      }

      final returnToProducts = await _showResults(result);

      if (returnToProducts && mounted) {
        Navigator.pop(context, result.hasUpdatedPictures);
      } else if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update the product '
            'pictures: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  Future<bool> _showResults(ProductPictureUpdateResult result) async {
    final returnToProducts =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Product Picture Update Results'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResultLine(
                      label: 'Pictures Found',
                      value: result.picturesFound,
                    ),
                    _ResultLine(
                      label: 'Pictures Updated',
                      value: result.updated,
                    ),
                    _ResultLine(
                      label: 'Pictures Skipped',
                      value: result.skipped,
                    ),
                    _ResultLine(label: 'Pictures Failed', value: result.failed),
                    if (result.failedItems.isNotEmpty) ...[
                      const Divider(height: 26),
                      const Text(
                        'Failed Pictures',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...result.failedItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• ${item.fileName}\n'
                            '  ${item.saveError ?? 'Unable to save the picture.'}',
                            style: const TextStyle(fontSize: 12),
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

    return returnToProducts;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Picture Update Preview',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: _buildBottomAction(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tablet = constraints.maxWidth >= 600;

            return Column(
              children: [
                _buildSummary(tablet: tablet),
                _buildFilters(),
                if (widget.package.warnings.isNotEmpty) _buildWarnings(),
                Expanded(
                  child: items.isEmpty
                      ? _buildEmptyState()
                      : tablet
                      ? _buildTabletGrid(items)
                      : _buildPhoneList(items),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary({required bool tablet}) {
    final metrics = <Widget>[
      _SummaryMetric(
        label: 'Found',
        value: widget.package.picturesFound,
        color: const Color(0xFF5B5CEB),
      ),
      _SummaryMetric(
        label: 'Matched',
        value: widget.package.matched,
        color: const Color(0xFF047857),
      ),
      _SummaryMetric(
        label: 'Unmatched',
        value: widget.package.unmatched,
        color: const Color(0xFFC2410C),
      ),
      _SummaryMetric(
        label: 'Duplicates',
        value: widget.package.duplicates,
        color: const Color(0xFFB45309),
      ),
      _SummaryMetric(
        label: 'Invalid',
        value: widget.package.invalid,
        color: const Color(0xFFB91C1C),
      ),
    ];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(tablet ? 24 : 16, 16, tablet ? 24 : 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: tablet
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: metrics,
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 10,
              children: metrics,
            ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _PictureReviewFilter.values.map((filter) {
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
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFC2410C),
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Package Warnings',
                style: TextStyle(
                  color: Color(0xFFC2410C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...widget.package.warnings.map((warning) {
            return Text(
              '• $warning',
              style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPhoneList(List<ProductPictureUpdateItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      itemCount: items.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        return _PictureUpdateCard(item: items[index]);
      },
    );
  }

  Widget _buildTabletGrid(List<ProductPictureUpdateItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 180,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _PictureUpdateCard(item: items[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 44,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 10),
          Text('No pictures match this filter.'),
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
          onPressed: !widget.package.hasMatchedPictures || _updating
              ? null
              : _updatePictures,
          icon: _updating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.photo_library_outlined),
          label: Text(
            _updating
                ? 'Updating Pictures...'
                : 'Update '
                      '${widget.package.matched} '
                      'Matched Picture'
                      '${widget.package.matched == 1 ? '' : 's'}',
          ),
        ),
      ),
    );
  }
}

class _PictureUpdateCard extends StatelessWidget {
  const _PictureUpdateCard({required this.item});

  final ProductPictureUpdateItem item;

  Color get _statusColor {
    switch (item.matchStatus) {
      case ProductPictureMatchStatus.matched:
        return const Color(0xFF047857);

      case ProductPictureMatchStatus.unmatched:
        return const Color(0xFFC2410C);

      case ProductPictureMatchStatus.duplicate:
        return const Color(0xFFB45309);

      case ProductPictureMatchStatus.invalid:
        return const Color(0xFFB91C1C);
    }
  }

  String get _statusLabel {
    switch (item.matchStatus) {
      case ProductPictureMatchStatus.matched:
        return 'MATCHED';

      case ProductPictureMatchStatus.unmatched:
        return 'UNMATCHED';

      case ProductPictureMatchStatus.duplicate:
        return 'DUPLICATE';

      case ProductPictureMatchStatus.invalid:
        return 'INVALID';
    }
  }

  String get _actionLabel {
    switch (item.matchStatus) {
      case ProductPictureMatchStatus.matched:
        return 'Replace saved picture';

      case ProductPictureMatchStatus.unmatched:
        return 'Skip unmatched picture';

      case ProductPictureMatchStatus.duplicate:
        return 'Resolve duplicate first';

      case ProductPictureMatchStatus.invalid:
        return 'Skip invalid picture';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showDetails(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPicture(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.product?.name ?? 'Product Not Found',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusBadge(label: _statusLabel, color: color),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: '
                      '${item.normalizedSku.isEmpty ? '(missing)' : item.normalizedSku}',
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          item.canUpdate
                              ? Icons.sync_outlined
                              : Icons.block_outlined,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _actionLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPicture() {
    return Container(
      width: 82,
      height: 94,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.bytes.isEmpty
          ? const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF))
          : Image.memory(
              item.bytes,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFFB91C1C),
                );
              },
            ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.product?.name ?? 'Product Not Found',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusBadge(label: _statusLabel, color: _statusColor),
                  ],
                ),
                const SizedBox(height: 16),
                if (item.bytes.isNotEmpty)
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 270,
                        maxWidth: 270,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(item.bytes, fit: BoxFit.contain),
                    ),
                  ),
                const SizedBox(height: 18),
                _DetailRow(label: 'Filename', value: item.fileName),
                _DetailRow(
                  label: 'Matched SKU',
                  value: item.normalizedSku.isEmpty
                      ? '(missing)'
                      : item.normalizedSku,
                ),
                _DetailRow(
                  label: 'Product',
                  value: item.product?.name ?? 'Not found',
                ),
                _DetailRow(label: 'Action', value: _actionLabel),
                if (item.message != null &&
                    item.message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      item.message!,
                      style: TextStyle(color: _statusColor, fontSize: 12),
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
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
        const SizedBox(height: 2),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 106,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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
