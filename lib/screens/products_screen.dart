import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/product_service.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _service = ProductService();
  final ProductRepository _repository = ProductRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      setState(() {
        _query = value.trim().toLowerCase();
      });
    });

    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();

    setState(() {
      _query = '';
    });
  }

  List<Product> _filteredProducts(List<Product> products) {
    if (_query.isEmpty) return products;

    return products.where((product) {
      final name = product.name.toLowerCase();
      final sku = product.sku.toLowerCase();
      final barcode = (product.barcode ?? '').toLowerCase();

      return name.contains(_query) ||
          sku.startsWith(_query) ||
          barcode.startsWith(_query);
    }).toList();
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ProductFormScreen(product: product);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          StreamBuilder<DatabaseEvent>(
            stream: _service.connectedRef.onValue,
            builder: (context, snapshot) {
              final online = snapshot.data?.snapshot.value == true;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: online
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFF7ED),
                child: Row(
                  children: [
                    Icon(
                      online
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 18,
                      color: online
                          ? const Color(0xFF047857)
                          : const Color(0xFFC2410C),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      online
                          ? 'Online - Live sync'
                          : 'Offline - Changes will sync later',
                      style: TextStyle(
                        color: online
                            ? const Color(0xFF047857)
                            : const Color(0xFFC2410C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search name, SKU, or barcode',
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: kIsWeb
                  ? _service.watchProducts()
                  : _repository.watchProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load products.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = _filteredProducts(snapshot.data!);

                if (products.isEmpty) {
                  return _EmptyProducts(
                    searching: _query.isNotEmpty,
                    onAdd: () => _openForm(),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: products.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (context, index) {
                    final product = products[index];

                    return _ProductCard(
                      product: product,
                      onTap: () => _openForm(product: product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: product.active ? 1 : 0.58,
      child: Card(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
            backgroundColor: product.active
                ? const Color(0xFFEDE9FE)
                : const Color(0xFFE5E7EB),
            child: Icon(
              Icons.inventory_2_outlined,
              color: product.active
                  ? const Color(0xFF6D28D9)
                  : const Color(0xFF6B7280),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: product.active
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.active ? 'ACTIVE' : 'INACTIVE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'SKU: ${product.sku}\n'
              'Selling: PHP ${product.sellingPrice.toStringAsFixed(2)}'
              '   Stock: ${product.beginningStock}',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.searching, required this.onAdd});

  final bool searching;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFEDE9FE),
              child: Icon(
                searching
                    ? Icons.search_off_outlined
                    : Icons.inventory_2_outlined,
                size: 36,
                color: const Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'No matching products' : 'No products yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try another name, SKU, or barcode.'
                  : 'Add your first product to build the catalog.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            if (!searching) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
