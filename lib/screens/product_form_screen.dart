import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../repositories/product_repository.dart';
import '../services/product_sync_service.dart';

import 'package:image_picker/image_picker.dart';

import '../services/product_photo_service.dart';
import '../services/product_picture_optimization_service.dart';

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

  final ProductPictureOptimizationService _pictureOptimizer =
      ProductPictureOptimizationService.instance;

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
      _stock,
      _minimumStock,
      _maximumStock;
  late bool _active;

  String? _category;
  String? _subcategory;
  String? _productClass;

  bool _saving = false;

  static const List<String> _categories = [
    'Beverages',
    'Food',
    'Health',
    'Beauty',
    'Household',
    'General Merchandise',
  ];

  static const Map<String, List<String>> _subcategories = {
    'Beverages': ['Soft Drinks', 'Water', 'Juice', 'Coffee and Tea'],
    'Food': ['Snacks', 'Biscuits', 'Canned Goods'],
    'Health': ['OTC', 'Vitamins', 'First Aid'],
    'Beauty': ['Skin Care', 'Hair Care', 'Personal Care'],
    'Household': ['Cleaning', 'Laundry', 'Kitchen'],
    'General Merchandise': ['Accessories', 'Supplies', 'Others'],
  };

  static const Map<String, List<String>> _classes = {
    'Soft Drinks': ['Carbonated Drinks', 'Energy Drinks', 'Sports Drinks'],
    'Water': ['Purified Water', 'Mineral Water', 'Sparkling Water'],
    'Juice': ['Fruit Juice', 'Juice Drink'],
    'Coffee and Tea': ['Coffee', 'Tea', 'Ready to Drink'],
    'Snacks': ['Chips', 'Nuts', 'Snack Mix'],
    'Biscuits': ['Cookies', 'Crackers', 'Wafers'],
    'Canned Goods': ['Meat', 'Fish', 'Vegetables'],
    'OTC': ['Pain Relief', 'Cold and Flu', 'Digestive Care'],
    'Vitamins': ['Multivitamins', 'Supplements', 'Minerals'],
    'First Aid': ['Bandages', 'Antiseptics', 'Medical Supplies'],
    'Skin Care': ['Face Care', 'Body Care', 'Sun Care'],
    'Hair Care': ['Shampoo', 'Conditioner', 'Hair Treatment'],
    'Personal Care': ['Deodorant', 'Oral Care', 'Bath Care'],
    'Cleaning': ['Surface Cleaner', 'Disinfectant', 'Cleaning Tools'],
    'Laundry': ['Detergent', 'Fabric Conditioner', 'Laundry Aid'],
    'Kitchen': ['Dishwashing', 'Food Storage', 'Kitchen Tools'],
    'Accessories': [
      'Mobile Accessories',
      'Personal Accessories',
      'Travel Accessories',
    ],
    'Supplies': ['Office Supplies', 'Store Supplies', 'Packaging Supplies'],
    'Others': ['Seasonal', 'Miscellaneous'],
  };
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
    _stock = TextEditingController(text: p?.currentStock.toString() ?? '0');

    _minimumStock = TextEditingController(
      text: p?.minimumStock.toString() ?? '0',
    );

    _maximumStock = TextEditingController(
      text: p == null
          ? '0'
          : p.maximumStock > 0
          ? p.maximumStock.toString()
          : p.currentStock.toString(),
    );
    _category = p?.category;
    _subcategory = p?.subcategory;
    _productClass = p?.productClass;

    _active = p?.active ?? true;

    if (p != null) {
      _loadExistingPhoto();
    }
  }

  Future<void> _loadExistingPhoto() async {
    final product = widget.product;

    if (product == null) {
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
    for (final c in [
      _name,
      _sku,
      _barcode,
      _cost,
      _selling,
      _stock,
      _minimumStock,
      _maximumStock,
    ]) {
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
                    'The picture will be saved locally '
                    'on this device or browser.',
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

  Future<void> _removeProductPhoto() async {
    final shouldRemove =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Remove product image?'),
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
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRemove || !mounted) {
      return;
    }

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

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final existingProduct = widget.product;

      final currentStock = int.parse(_stock.text.trim());

      final minimumStock = int.parse(_minimumStock.text.trim());

      final maximumStock = int.parse(_maximumStock.text.trim());

      if (minimumStock > maximumStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Minimum stock cannot be greater than maximum stock.',
            ),
          ),
        );

        return;
      }

      if (currentStock > maximumStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current stock cannot exceed maximum stock.'),
          ),
        );

        return;
      }

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
        beginningStock: existingProduct?.beginningStock ?? currentStock,
        currentStock: currentStock,
        minimumStock: minimumStock,
        maximumStock: maximumStock,
        category: _category,
        subcategory: _subcategory,
        productClass: _productClass,
        active: _active,
        localPhotoPath: existingProduct?.localPhotoPath,
        createdAt: existingProduct?.createdAt ?? now,
        updatedAt: now,
        syncStatus: ProductSyncStatus.pending,
        syncError: null,
        isDeleted: false,
      );

      XFile? optimizedSelectedPhoto;

      if (_selectedPhoto != null) {
        final sourceBytes = await _selectedPhoto!.readAsBytes();

        final optimized = _pictureOptimizer.optimizeMaster(
          sourceBytes: sourceBytes,
          sku: product.sku,
        );

        optimizedSelectedPhoto = XFile.fromData(
          optimized.bytes,
          name: optimized.fileName,
          mimeType: optimized.mimeType,
        );
      }

      if (kIsWeb) {
        await _service.save(
          id: existingProduct?.id,
          name: product.name,
          sku: product.sku,
          barcode: product.barcode,
          costPrice: product.costPrice,
          sellingPrice: product.sellingPrice,
          beginningStock: product.beginningStock,
          currentStock: product.currentStock,
          minimumStock: product.minimumStock,
          maximumStock: product.maximumStock,
          category: product.category,
          subcategory: product.subcategory,
          productClass: product.productClass,
          active: product.active,
          oldSku: existingProduct?.sku,
          oldBarcode: existingProduct?.barcode,
        );

        String? webPhotoPath = await _photoService.getPhotoPath(product.sku);

        final oldWebSku = existingProduct?.sku.trim().toUpperCase();

        if (oldWebSku != null &&
            oldWebSku.isNotEmpty &&
            oldWebSku != product.sku) {
          await _photoService.movePhotoToNewSku(
            oldSku: oldWebSku,
            newSku: product.sku,
          );

          webPhotoPath = await _photoService.getPhotoPath(product.sku);
        }

        if (_removeExistingPhoto) {
          await _photoService.deletePhoto(product.sku);

          webPhotoPath = null;
        }

        if (_selectedPhoto != null) {
          webPhotoPath = await _photoService.savePhoto(
            sku: product.sku,
            selectedPhoto: optimizedSelectedPhoto!,
          );
        }

        if (webPhotoPath != null) {
          _photoBytes = await _photoService.readPhotoBytes(webPhotoPath);
        }
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
            selectedPhoto: optimizedSelectedPhoto!,
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

  double get _grossMargin {
    final cost = double.tryParse(_cost.text.trim()) ?? 0;

    final selling = double.tryParse(_selling.text.trim()) ?? 0;

    return selling - cost;
  }

  double get _grossMarginPercentage {
    final selling = double.tryParse(_selling.text.trim()) ?? 0;

    if (selling <= 0) {
      return 0;
    }

    return (_grossMargin / selling) * 100;
  }

  Widget _buildGrossMargin() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Color(0xFF5B5CEB),
          ),
          const SizedBox(width: 7),
          Text(
            'Gross margin: '
            '₱${_grossMargin.toStringAsFixed(2)} '
            '(${_grossMarginPercentage.toStringAsFixed(0)}%)',
            style: const TextStyle(color: Color(0xFF5B5CEB)),
          ),
        ],
      ),
    );
  }

  String get _stockStatus {
    final current = int.tryParse(_stock.text.trim()) ?? 0;

    final minimum = int.tryParse(_minimumStock.text.trim()) ?? 0;

    final maximum = int.tryParse(_maximumStock.text.trim()) ?? 0;

    if (current == 0) {
      return 'Out of Stock';
    }

    if (current > 0 && current <= minimum) {
      return 'Low Stock';
    }

    if (current > maximum) {
      return 'Over Maximum';
    }

    return 'Normal';
  }

  Color get _stockStatusColor {
    switch (_stockStatus) {
      case 'Out of Stock':
        return Colors.red.shade700;
      case 'Low Stock':
        return Colors.orange.shade700;
      case 'Over Maximum':
        return const Color(0xFF5B5CEB);
      default:
        return Colors.green.shade700;
    }
  }

  Widget _buildStockStatus() {
    final color = _stockStatusColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          const Text(
            'Stock Status: ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            _stockStatus,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
            'Saved only on this device/browser',
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
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Product name',
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('category-$_category'),
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _category = value;
                      _subcategory = null;
                      _productClass = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('subcategory-$_category-$_subcategory'),
                  initialValue: _subcategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subcategory',
                    border: OutlineInputBorder(),
                  ),
                  items: (_subcategories[_category] ?? const <String>[])
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _category == null
                      ? null
                      : (value) {
                          setState(() {
                            _subcategory = value;
                            _productClass = null;
                          });
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('class-$_subcategory-$_productClass'),
                  initialValue: _productClass,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: (_classes[_subcategory] ?? const <String>[])
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _subcategory == null
                      ? null
                      : (value) {
                          setState(() {
                            _productClass = value;
                          });
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Barcode (optional)',
              hintText: 'Enter or scan barcode',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Scan barcode',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Barcode scanner will be '
                        'connected to the scanner service.',
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF5B5CEB),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  onChanged: (_) {
                    setState(() {});
                  },
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
                  onChanged: (_) {
                    setState(() {});
                  },
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
          _buildGrossMargin(),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stock,
            onChanged: (_) {
              setState(() {});
            },
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Current stock',
              border: OutlineInputBorder(),
            ),
            validator: _integer,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minimumStock,
                  onChanged: (_) {
                    setState(() {});
                  },
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum stock',
                    border: OutlineInputBorder(),
                  ),
                  validator: _integer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _maximumStock,
                  onChanged: (_) {
                    setState(() {});
                  },
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum stock',
                    border: OutlineInputBorder(),
                  ),
                  validator: _integer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStockStatus(),
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
