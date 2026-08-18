import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../models/product.dart';
import '../../repositories/product_repository.dart';
import '../../services/inventory_excel_export_service.dart';
import '../../services/product_service.dart';
import '../../services/product_photo_service.dart';

class InventoryModuleScreen extends StatelessWidget {
  const InventoryModuleScreen({super.key, this.productStream});

  final Stream<List<Product>>? productStream;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: const Color(0xFF5B5CEB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(child: _InventoryOverview(productStream: productStream)),
    );
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

  final InventoryExcelExportService _excelExportService =
      InventoryExcelExportService.instance;

  List<Product> _visibleProducts = <Product>[];

  bool _exportingExcel = false;

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

                  _visibleProducts = products;

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

  Future<void> _exportInventoryExcel() async {
    if (_exportingExcel) {
      return;
    }

    if (_visibleProducts.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'There are no Inventory '
              'products to export.',
            ),
          ),
        );

      return;
    }

    setState(() {
      _exportingExcel = true;
    });

    try {
      final result = await _excelExportService.export(
        products: List<Product>.unmodifiable(_visibleProducts),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '${result.productCount} product(s) '
              'exported to ${result.fileName}.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Unable to export Inventory: '
              '$error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _exportingExcel = false;
        });
      }
    }
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
              const Text(
                'Search the Product Masterfile '
                'and view current SOH.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;

                  final searchField = TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: compact
                          ? 'Search SKU, Name, '
                                'or Barcode'
                          : 'Search SKU, Product '
                                'Name, or Barcode',
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
                  );

                  final exportButton = FilledButton.icon(
                    onPressed: _exportingExcel ? null : _exportInventoryExcel,
                    icon: _exportingExcel
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      _exportingExcel ? 'EXPORTING...' : 'EXPORT EXCEL',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );

                  if (compact) {
                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: exportButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      exportButton,
                    ],
                  );
                },
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
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              const _MobileInventoryHeader(),
              const Divider(height: 1, color: Color(0xFFD1D5DB)),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: products.length,
                  separatorBuilder: (context, index) {
                    return const Divider(height: 1, color: Color(0xFFE5E7EB));
                  },
                  itemBuilder: (context, index) {
                    return _MobileInventoryRow(product: products[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideTable() {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1400,
                  child: Column(
                    children: [
                      const _WideInventoryHeader(),
                      const Divider(height: 1, color: Color(0xFFD1D5DB)),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: products.length,
                          separatorBuilder: (context, index) {
                            return const Divider(
                              height: 1,
                              color: Color(0xFFE5E7EB),
                            );
                          },
                          itemBuilder: (context, index) {
                            return _WideInventoryRow(product: products[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideInventoryHeader extends StatelessWidget {
  const _WideInventoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          _WideInventoryHeaderCell(label: 'SKU', width: 125),
          _WideInventoryHeaderCell(label: 'Product Name', width: 250),
          _WideInventoryHeaderCell(label: 'Department', width: 165),
          _WideInventoryHeaderCell(label: 'Class', width: 155),
          _WideInventoryHeaderCell(label: 'Subclass', width: 165),
          _WideInventoryHeaderCell(
            label: 'SOH',
            width: 95,
            alignment: Alignment.centerRight,
          ),
          _WideInventoryHeaderCell(
            label: 'Retail',
            width: 145,
            alignment: Alignment.centerRight,
          ),
          _WideInventoryHeaderCell(label: 'Last Updated', width: 220),
        ],
      ),
    );
  }
}

class _WideInventoryHeaderCell extends StatelessWidget {
  const _WideInventoryHeaderCell({
    required this.label,
    required this.width,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final double width;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: alignment,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WideInventoryRow extends StatelessWidget {
  const _WideInventoryRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    void openDetails() {
      _showInventoryProductDetails(context, product);
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: openDetails,
        onDoubleTap: openDetails,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _WideInventoryDataCell(
                width: 125,
                child: Text(
                  product.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _WideInventoryDataCell(
                width: 250,
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _WideInventoryDataCell(
                width: 165,
                child: Text(
                  _classification(product.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _WideInventoryDataCell(
                width: 155,
                child: Text(
                  _classification(product.productClass),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _WideInventoryDataCell(
                width: 165,
                child: Text(
                  _classification(product.subcategory),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _WideInventoryDataCell(
                width: 95,
                alignment: Alignment.centerRight,
                child: _SohValue(value: product.currentStock),
              ),
              _WideInventoryDataCell(
                width: 145,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCurrency(product.sellingPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _WideInventoryDataCell(
                width: 220,
                child: Text(
                  _formatUpdatedAt(product.updatedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
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

class _WideInventoryDataCell extends StatelessWidget {
  const _WideInventoryDataCell({
    required this.width,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final double width;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(alignment: alignment, child: child),
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
    void openDetails() {
      _showInventoryProductDetails(context, product);
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: openDetails,
        onDoubleTap: openDetails,
        child: Padding(
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
        ),
      ),
    );
  }
}

Future<void> _showInventoryProductDetails(
  BuildContext context,
  Product product,
) async {
  final width = MediaQuery.sizeOf(context).width;

  if (width < 600) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: _InventoryProductDetails(product: product, mobile: true),
          ),
        );
      },
    );

    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      final dialogWidth = width >= 1200 ? 920.0 : 760.0;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: _InventoryProductDetails(product: product, mobile: false),
          ),
        ),
      );
    },
  );
}

class _InventoryProductDetails extends StatelessWidget {
  const _InventoryProductDetails({required this.product, required this.mobile});

  final Product product;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProductDetailsHeader(productName: product.name, mobile: mobile),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(mobile ? 18 : 24),
            child: mobile ? _buildMobileContent() : _buildWideContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _InventoryProductPhoto(product: product, size: 190)),
        const SizedBox(height: 20),
        _ProductIdentitySection(product: product),
        const SizedBox(height: 18),
        _ProductStockSection(product: product),
        const SizedBox(height: 18),
        _ProductPricingSection(product: product),
        const SizedBox(height: 18),
        _ProductClassificationSection(product: product),
        const SizedBox(height: 18),
        _ProductAuditSection(product: product),
      ],
    );
  }

  Widget _buildWideContent() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InventoryProductPhoto(product: product, size: 250),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  _ProductIdentitySection(product: product),
                  const SizedBox(height: 18),
                  _ProductStockSection(product: product),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ProductPricingSection(product: product)),
            const SizedBox(width: 18),
            Expanded(child: _ProductClassificationSection(product: product)),
          ],
        ),
        const SizedBox(height: 18),
        _ProductAuditSection(product: product),
      ],
    );
  }
}

class _ProductDetailsHeader extends StatelessWidget {
  const _ProductDetailsHeader({
    required this.productName,
    required this.mobile,
  });

  final String productName;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF5B5CEB),
      padding: EdgeInsets.fromLTRB(mobile ? 18 : 24, 14, 8, 14),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _InventoryProductPhoto extends StatefulWidget {
  const _InventoryProductPhoto({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  State<_InventoryProductPhoto> createState() => _InventoryProductPhotoState();
}

class _InventoryProductPhotoState extends State<_InventoryProductPhoto> {
  final ProductPhotoService _photoService = ProductPhotoService.instance;

  late Future<Uint8List?> _photoFuture;

  @override
  void initState() {
    super.initState();

    _photoFuture = _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _InventoryProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.product.sku != widget.product.sku ||
        oldWidget.product.localPhotoPath != widget.product.localPhotoPath ||
        oldWidget.product.updatedAt != widget.product.updatedAt) {
      _photoFuture = _loadPhoto();
    }
  }

  Future<Uint8List?> _loadPhoto() async {
    final product = widget.product;

    final photoPath = kIsWeb
        ? await _photoService.getPhotoPath(product.sku)
        : product.localPhotoPath ??
              await _photoService.getPhotoPath(product.sku);

    return _photoService.readPhotoBytes(photoPath);
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    final decodeWidth = (widget.size * pixelRatio)
        .round()
        .clamp(320, 900)
        .toInt();

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8D6FE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List?>(
        future: _photoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bytes = snapshot.data;

          if (bytes == null || bytes.isEmpty) {
            return const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF6D28D9),
              size: 62,
            );
          }

          return Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF6D28D9),
                size: 62,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductIdentitySection extends StatelessWidget {
  const _ProductIdentitySection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return _ProductDetailCard(
      title: 'Product Information',
      icon: Icons.badge_outlined,
      children: [
        _ProductDetailLine(label: 'Product Name', value: product.name),
        _ProductDetailLine(label: 'SKU', value: product.sku),
        _ProductDetailLine(
          label: 'Barcode',
          value: _detailValue(product.barcode),
        ),
        _ProductDetailLine(
          label: 'Status',
          value: product.active ? 'Active' : 'Inactive',
        ),
      ],
    );
  }
}

class _ProductStockSection extends StatelessWidget {
  const _ProductStockSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return _ProductDetailCard(
      title: 'Stock Information',
      icon: Icons.warehouse_outlined,
      children: [
        _ProductDetailLine(
          label: 'Stock Status',
          value: _productStockStatus(product),
          valueColor: _productStockStatusColor(product),
        ),
        _ProductDetailLine(
          label: 'Current SOH',
          value: product.currentStock.toString(),
        ),
        _ProductDetailLine(
          label: 'Beginning Stock',
          value: product.beginningStock.toString(),
        ),
        _ProductDetailLine(
          label: 'Minimum Stock',
          value: product.minimumStock.toString(),
        ),
        _ProductDetailLine(
          label: 'Maximum Stock',
          value: product.maximumStock.toString(),
        ),
      ],
    );
  }
}

class _ProductPricingSection extends StatelessWidget {
  const _ProductPricingSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return _ProductDetailCard(
      title: 'Pricing',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        _ProductDetailLine(
          label: 'Retail Price',
          value: _formatCurrency(product.sellingPrice),
        ),
        _ProductDetailLine(
          label: 'Cost Price',
          value: _formatCurrency(product.costPrice),
        ),
      ],
    );
  }
}

class _ProductClassificationSection extends StatelessWidget {
  const _ProductClassificationSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return _ProductDetailCard(
      title: 'Classification',
      icon: Icons.account_tree_outlined,
      children: [
        _ProductDetailLine(
          label: 'Department',
          value: _classification(product.category),
        ),
        _ProductDetailLine(
          label: 'Class',
          value: _classification(product.productClass),
        ),
        _ProductDetailLine(
          label: 'Subclass',
          value: _classification(product.subcategory),
        ),
      ],
    );
  }
}

class _ProductAuditSection extends StatelessWidget {
  const _ProductAuditSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return _ProductDetailCard(
      title: 'Record Information',
      icon: Icons.history,
      children: [
        _ProductDetailLine(
          label: 'Last Updated',
          value: _formatUpdatedAt(product.updatedAt),
        ),
        const _ProductDetailLine(label: 'Access', value: 'Read-only'),
      ],
    );
  }
}

class _ProductDetailCard extends StatelessWidget {
  const _ProductDetailCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF5B5CEB), size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}

class _ProductDetailLine extends StatelessWidget {
  const _ProductDetailLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _detailValue(String? value) {
  final normalized = value?.trim() ?? '';

  return normalized.isEmpty ? 'Not available' : normalized;
}

String _productStockStatus(Product product) {
  if (product.currentStock <= 0) {
    return 'Out of Stock';
  }

  if (product.currentStock <= product.minimumStock) {
    return 'Low Stock';
  }

  return 'In Stock';
}

Color _productStockStatusColor(Product product) {
  if (product.currentStock <= 0) {
    return const Color(0xFFDC2626);
  }

  if (product.currentStock <= product.minimumStock) {
    return const Color(0xFFD97706);
  }

  return const Color(0xFF047857);
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
