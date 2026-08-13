import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../repositories/product_repository.dart';
import '../services/product_sync_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final ProductSyncService _syncService = ProductSyncService.instance;

  static const Uuid _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();
  late final TextEditingController _name,
      _sku,
      _barcode,
      _cost,
      _selling,
      _stock;
  late bool _active;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(text: p?.costPrice.toStringAsFixed(2) ?? '');
    _selling = TextEditingController(
      text: p?.sellingPrice.toStringAsFixed(2) ?? '',
    );
    _stock = TextEditingController(text: p?.beginningStock.toString() ?? '0');
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _cost, _selling, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _money(String? v) {
    final n = double.tryParse(v ?? '');
    return n == null
        ? 'Enter a valid number'
        : n < 0
        ? 'Cannot be negative'
        : null;
  }

  String? _integer(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null
        ? 'Enter a whole number'
        : n < 0
        ? 'Cannot be negative'
        : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final costPrice = double.parse(_cost.text.trim());

    final sellingPrice = double.parse(_selling.text.trim());

    if (sellingPrice < costPrice) {
      final continueSaving =
          await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Selling below cost'),
                content: const Text(
                  'Selling price is lower than cost price. '
                  'Do you want to continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!continueSaving) {
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final existingProduct = widget.product;

      final beginningStock = int.parse(_stock.text.trim());

      final normalizedSku = _sku.text.trim().toUpperCase();

      final normalizedBarcode = _barcode.text.trim().isEmpty
          ? null
          : _barcode.text.trim();

      final product = Product(
        id: existingProduct?.id ?? _uuid.v4(),
        name: _name.text.trim(),
        sku: normalizedSku,
        barcode: normalizedBarcode,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        beginningStock: beginningStock,
        currentStock: existingProduct == null
            ? beginningStock
            : existingProduct.currentStock,
        active: _active,
        localPhotoPath: existingProduct?.localPhotoPath,
        createdAt: existingProduct?.createdAt ?? now,
        updatedAt: now,
        syncStatus: ProductSyncStatus.pending,
        syncError: null,
        isDeleted: false,
      );

      if (kIsWeb) {
        await _service.save(
          id: existingProduct?.id,
          name: product.name,
          sku: product.sku,
          barcode: product.barcode,
          costPrice: product.costPrice,
          sellingPrice: product.sellingPrice,
          beginningStock: product.beginningStock,
          active: product.active,
          oldSku: existingProduct?.sku,
          oldBarcode: existingProduct?.barcode,
        );
      } else {
        await _syncService.saveProduct(product);
      }

      if (!mounted) {
        return;
      }

      final message = kIsWeb
          ? existingProduct == null
                ? 'Product saved successfully.'
                : 'Product updated successfully.'
          : existingProduct == null
          ? 'Product saved locally. Sync will continue automatically.'
          : 'Product updated locally. Sync will continue automatically.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      Navigator.pop(context);
    } on DuplicateLocalProductException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } on DuplicateProductException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.field} already exists.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save product: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Product name',
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sku,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'SKU',
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Barcode (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cost price',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: _money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _selling,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Selling price',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: _money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Beginning stock',
              border: OutlineInputBorder(),
            ),
            validator: _integer,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active product'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Product'),
          ),
        ],
      ),
    ),
  );
}
