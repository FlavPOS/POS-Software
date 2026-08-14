import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../repositories/product_repository.dart';
import '../services/product_sync_service.dart';

import 'package:image_picker/image_picker.dart';

import '../services/product_photo_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final ProductSyncService _syncService = ProductSyncService.instance;

  static const Uuid _uuid = Uuid();

  final ProductPhotoService _photoService = ProductPhotoService.instance;

  XFile? _selectedPhoto;
  Uint8List? _photoBytes;
  bool _removeExistingPhoto = false;
  bool _loadingPhoto = false;
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

    if (!kIsWeb && p != null) {
      _loadExistingPhoto();
    }
  }

  Future<void> _loadExistingPhoto() async {
    final product = widget.product;

    if (product == null || kIsWeb) {
      return;
    }

    setState(() {
      _loadingPhoto = true;
    });

    final photoPath =
        product.localPhotoPath ?? await _photoService.getPhotoPath(product.sku);

    final photoBytes = await _photoService.readPhotoBytes(photoPath);

    if (!mounted) {
      return;
    }

    setState(() {
      _photoBytes = photoBytes;
      _loadingPhoto = false;
    });
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

  Future<void> _selectProductPhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permanent product pictures are available '
            'in the Android application.',
          ),
        ),
      );

      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Product Picture',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'The picture will be saved only '
                    'on this device.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a Picture'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final selectedPhoto = source == ImageSource.camera
        ? await _photoService.takePhoto()
        : await _photoService.pickFromGallery();

    if (selectedPhoto == null) {
      return;
    }

    final selectedBytes = await selectedPhoto.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPhoto = selectedPhoto;
      _photoBytes = selectedBytes;
      _removeExistingPhoto = false;
    });
  }

  void _removeProductPhoto() {
    setState(() {
      _selectedPhoto = null;
      _photoBytes = null;
      _removeExistingPhoto = true;
    });
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

        String? savedPhotoPath = existingProduct?.localPhotoPath;

        final oldSku = existingProduct?.sku.trim().toUpperCase();

        if (oldSku != null && oldSku.isNotEmpty && oldSku != product.sku) {
          await _photoService.movePhotoToNewSku(
            oldSku: oldSku,
            newSku: product.sku,
          );

          savedPhotoPath = await _photoService.getPhotoPath(product.sku);
        }

        if (_removeExistingPhoto) {
          await _photoService.deletePhoto(product.sku);

          savedPhotoPath = null;
        }

        if (_selectedPhoto != null) {
          savedPhotoPath = await _photoService.savePhoto(
            sku: product.sku,
            selectedPhoto: _selectedPhoto!,
          );
        }

        if (savedPhotoPath != existingProduct?.localPhotoPath) {
          await ProductRepository.instance.updateLocalPhotoPath(
            productId: product.id,
            localPhotoPath: savedPhotoPath,
          );
        }
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

  Widget _buildPhotoSection() {
    final hasPhoto = _photoBytes != null;

    Widget photoContent;

    if (_loadingPhoto) {
      photoContent = const Center(child: CircularProgressIndicator());
    } else if (hasPhoto) {
      photoContent = Image.memory(
        _photoBytes!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 52,
              color: Color(0xFF6B7280),
            ),
          );
        },
      );
    } else {
      photoContent = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 52,
            color: Color(0xFF6D28D9),
          ),
          SizedBox(height: 8),
          Text(
            'Add product picture',
            style: TextStyle(
              color: Color(0xFF6D28D9),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Saved only on this device',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
          ),
        ],
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            InkWell(
              onTap: _selectProductPhoto,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                height: 190,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: photoContent,
              ),
            ),
            if (hasPhoto)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Remove picture',
                    onPressed: _removeProductPhoto,
                    color: Colors.white,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _selectProductPhoto,
          icon: Icon(
            hasPhoto ? Icons.edit_outlined : Icons.add_photo_alternate_outlined,
          ),
          label: Text(hasPhoto ? 'Change Picture' : 'Select Picture'),
        ),
      ],
    );
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
          _buildPhotoSection(),
          const SizedBox(height: 14),
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
