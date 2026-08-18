import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../services/product_service.dart';

class InventoryModuleScreen extends StatefulWidget {
  const InventoryModuleScreen({super.key, this.productStream});

  final Stream<List<Product>>? productStream;

  @override
  State<InventoryModuleScreen> createState() => _InventoryModuleScreenState();
}

class _InventoryModuleScreenState extends State<InventoryModuleScreen> {
  int _selectedIndex = 0;

  static const List<_InventorySection> _sections = <_InventorySection>[
    _InventorySection(title: 'Inventory', icon: Icons.inventory_2_outlined),
    _InventorySection(title: 'Adjustment', icon: Icons.tune),
    _InventorySection(
      title: 'Received Delivery',
      icon: Icons.local_shipping_outlined,
    ),
    _InventorySection(
      title: 'Adjustment Types',
      icon: Icons.settings_suggest_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Inventory Module'),
        backgroundColor: const Color(0xFF5B5CEB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1024;

            if (desktop) {
              return Row(
                children: [
                  _buildDesktopNavigation(),
                  Expanded(child: _buildSelectedPage()),
                ],
              );
            }

            return Column(
              children: [
                _buildCompactNavigation(),
                Expanded(child: _buildSelectedPage()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactNavigation() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: List<Widget>.generate(_sections.length, (index) {
            final section = _sections[index];

            final selected = index == _selectedIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(
                  section.icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF5B5CEB),
                ),
                label: Text(section.title),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: const Color(0xFF5B5CEB),
                backgroundColor: const Color(0xFFF3F4F6),
                side: BorderSide.none,
                onSelected: (_) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDesktopNavigation() {
    return Container(
      width: 250,
      color: const Color(0xFF29245C),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'INVENTORY',
                style: TextStyle(
                  color: Color(0xFFA5B4FC),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final section = _sections[index];

                final selected = index == _selectedIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              section.icon,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFC7D2FE),
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                section.title,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFFE0E7FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _InventoryOverview(productStream: widget.productStream);
      case 1:
        return const _ModuleDevelopmentPage(
          title: 'Adjustment',
          description:
              'Create, submit, approve, '
              'or reject cost-based '
              'inventory adjustments.',
          icon: Icons.tune,
          completedFeatures: <String>[
            'Cost Price calculation model',
            'Increase and Decrease direction',
            'Draft, Submitted, Approved, '
                'and Rejected workflow',
            'Negative inventory protection',
            'One-time processing protection',
          ],
        );
      case 2:
        return const _ModuleDevelopmentPage(
          title: 'Received Delivery',
          description:
              'Receive supplier deliveries '
              'using quantity and Cost Price.',
          icon: Icons.local_shipping_outlined,
          completedFeatures: <String>[
            'Cost-only inventory rules ready',
            'DELIVERY movement type ready',
            'Approval workflow foundation ready',
            'Firebase repository pending',
            'Received Delivery form pending',
          ],
        );
      case 3:
        return const _ModuleDevelopmentPage(
          title: 'Adjustment Types',
          description:
              'Manage configurable Increase '
              'and Decrease adjustment types.',
          icon: Icons.settings_suggest_outlined,
          completedFeatures: <String>[
            'Configurable type model ready',
            'Increase (+) and Decrease (-)',
            'Active and Inactive status',
            'Delete unused type rule',
            'Deactivate used type rule',
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _InventoryOverview extends StatefulWidget {
  const _InventoryOverview({this.productStream});

  final Stream<List<Product>>? productStream;

  @override
  State<_InventoryOverview> createState() => _InventoryOverviewState();
}

class _InventoryOverviewState extends State<_InventoryOverview> {
  ProductService? _service;
  ProductRepository? _repository;

  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  Stream<List<Product>> get _productStream {
    final injected = widget.productStream;

    if (injected != null) {
      return injected;
    }

    if (kIsWeb) {
      _service ??= ProductService();

      return _service!.watchProducts();
    }

    _repository ??= ProductRepository.instance;

    return _repository!.watchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchText.trim().toLowerCase();

    final filtered = query.isEmpty
        ? List<Product>.from(products)
        : products.where((product) {
            final sku = product.sku.toLowerCase();

            final name = product.name.toLowerCase();

            final barcode = product.barcode?.toLowerCase() ?? '';

            return sku.contains(query) ||
                name.contains(query) ||
                barcode.contains(query);
          }).toList();

    filtered.sort((first, second) {
      final nameComparison = first.name.toLowerCase().compareTo(
        second.name.toLowerCase(),
      );

      if (nameComparison != 0) {
        return nameComparison;
      }

      return first.sku.compareTo(second.sku);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;

        final horizontalPadding = mobile
            ? 12.0
            : constraints.maxWidth < 1024
            ? 20.0
            : 28.0;

        return Column(
          children: [
            _buildSearchArea(
              horizontalPadding: horizontalPadding,
              mobile: mobile,
            ),
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _productStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _InventoryMessage(
                      icon: Icons.error_outline,
                      title: 'Unable to load inventory',
                      message: snapshot.error.toString(),
                      color: const Color(0xFFDC2626),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = _filterProducts(snapshot.data!);

                  if (products.isEmpty) {
                    return _InventoryMessage(
                      icon: Icons.search_off,
                      title: _searchText.trim().isEmpty
                          ? 'No products found'
                          : 'No matching products',
                      message: _searchText.trim().isEmpty
                          ? 'Add products to the '
                                'Product Masterfile.'
                          : 'Try another SKU, '
                                'Product Name, or '
                                'Barcode.',
                      color: const Color(0xFF6D28D9),
                    );
                  }

                  return _InventoryProductList(
                    products: products,
                    mobile: mobile,
                    horizontalPadding: horizontalPadding,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchArea({
    required double horizontalPadding,
    required bool mobile,
  }) {
    return Container(
      color: const Color(0xFFF4F6FB),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        mobile ? 16 : 22,
        horizontalPadding,
        14,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontSize: mobile ? 24 : 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Search the Product Masterfile '
                'and view current SOH.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText:
                      'Search SKU, Product Name, '
                      'or Barcode',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _searchText = '';
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF5B5CEB),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryProductList extends StatelessWidget {
  const _InventoryProductList({
    required this.products,
    required this.mobile,
    required this.horizontalPadding,
  });

  final List<Product> products;
  final bool mobile;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return _buildMobileList();
    }

    return _buildWideTable();
  }

  Widget _buildMobileList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
      itemCount: products.length + 1,
      separatorBuilder: (context, index) {
        return const Divider(height: 1, color: Color(0xFFE5E7EB));
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _MobileInventoryHeader();
        }

        return _MobileInventoryRow(product: products[index - 1]);
      },
    );
  }

  Widget _buildWideTable() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF3F4F6),
                ),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                dataTextStyle: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Product Name')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Subclass')),
                  DataColumn(numeric: true, label: Text('SOH')),
                  DataColumn(numeric: true, label: Text('Retail')),
                  DataColumn(label: Text('Last Updated')),
                ],
                rows: products.map((product) {
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(
                        SizedBox(
                          width: 105,
                          child: Text(
                            product.sku,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            _classification(product.category),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 125,
                          child: Text(
                            _classification(product.productClass),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            _classification(product.subcategory),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: _SohValue(value: product.currentStock),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatCurrency(product.sellingPrice),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      DataCell(Text(_formatUpdatedAt(product.updatedAt))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileInventoryHeader extends StatelessWidget {
  const _MobileInventoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 24, child: _HeaderText('SKU')),
          Expanded(flex: 42, child: _HeaderText('Product Name')),
          Expanded(flex: 14, child: _HeaderText('SOH', align: TextAlign.right)),
          Expanded(
            flex: 20,
            child: _HeaderText('Retail', align: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _MobileInventoryRow extends StatelessWidget {
  const _MobileInventoryRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Text(
              product.sku,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4F46E5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SohValue(value: product.currentStock),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              _formatCurrency(product.sellingPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SohValue extends StatelessWidget {
  const _SohValue({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    Color color;

    if (value <= 0) {
      color = const Color(0xFFDC2626);
    } else {
      color = const Color(0xFF047857);
    }

    return Text(
      value.toString(),
      textAlign: TextAlign.right,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    );
  }
}

class _InventoryMessage extends StatelessWidget {
  const _InventoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

String _classification(String? value) {
  final normalized = value?.trim() ?? '';

  return normalized.isEmpty ? 'Not classified' : normalized;
}

String _formatCurrency(double value) {
  return '₱${value.toStringAsFixed(2)}';
}

String _formatUpdatedAt(int timestamp) {
  if (timestamp <= 0) {
    return '-';
  }

  final milliseconds = timestamp < 1000000000000 ? timestamp * 1000 : timestamp;

  final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);

  final month = dateTime.month.toString().padLeft(2, '0');

  final day = dateTime.day.toString().padLeft(2, '0');

  final year = dateTime.year.toString();

  final hour = dateTime.hour.toString().padLeft(2, '0');

  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$month/$day/$year $hour:$minute';
}

class _ModuleDevelopmentPage extends StatelessWidget {
  const _ModuleDevelopmentPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.completedFeatures,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String> completedFeatures;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF6D28D9)),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                ...completedFeatures.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF059669),
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventorySection {
  const _InventorySection({required this.title, required this.icon});

  final String title;
  final IconData icon;
}
