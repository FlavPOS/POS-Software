import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
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
    if (!_formKey.currentState!.validate()) return;
    final cost = double.parse(_cost.text),
        selling = double.parse(_selling.text);
    if (selling < cost) {
      final ok =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Selling below cost'),
              content: const Text(
                'Selling price is lower than cost price. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      await _service.save(
        id: widget.product?.id,
        name: _name.text,
        sku: _sku.text,
        barcode: _barcode.text,
        costPrice: cost,
        sellingPrice: selling,
        beginningStock: int.parse(_stock.text),
        active: _active,
        oldSku: widget.product?.sku,
        oldBarcode: widget.product?.barcode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.product == null
                ? 'Product saved. It will sync when online.'
                : 'Product updated. It will sync when online.',
          ),
        ),
      );
      Navigator.pop(context);
    } on DuplicateProductException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${e.field} already exists.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
