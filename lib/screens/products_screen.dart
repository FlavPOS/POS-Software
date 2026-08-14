import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_delete_result.dart';
import '../models/product_import_package.dart';
import '../repositories/product_repository.dart';
import '../services/product_delete_service.dart';
import '../services/product_photo_service.dart';
import '../services/product_import_download_service.dart';
import '../services/product_import_picker_service.dart';
import '../services/product_import_excel_service.dart';
import '../services/product_import_package_service.dart';
import '../services/product_service.dart';
import 'product_form_screen.dart';
import 'product_import_review_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _service = ProductService();
  final ProductRepository _repository = ProductRepository.instance;

  final ProductDeleteService _deleteService = ProductDeleteService.instance;

  final Set<String> _deletingProductIds = <String>{};

  bool _selectionMode = false;

  final Set<String> _selectedProductIds = <String>{};

  bool _deletingSelection = false;

  final ProductImportDownloadService _importDownloadService =
      ProductImportDownloadService.instance;
  final TextEditingController _searchController = TextEditingController();

  final ProductImportPackageService _importPackageService =
      ProductImportPackageService.instance;

  final ProductImportExcelService _importExcelService =
      ProductImportExcelService.instance;

  final ProductImportPickerService _importPickerService =
      ProductImportPickerService.instance;

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

  Future<void> _downloadImportTemplate() async {
    try {
      final result = await _importDownloadService.downloadTemplate();

      if (!mounted) {
        return;
      }

      if (result == ProductTemplateDownloadResult.cancelled) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product import template saved successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save the import template: $error')),
      );
    }
  }

  Future<void> _selectImportFile() async {
    try {
      final file = await _importPickerService.pickFile();

      if (file == null || !mounted) {
        return;
      }

      final shouldContinue =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Import File Selected'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(file.fileName),
                    const SizedBox(height: 14),
                    const Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(file.displayType),
                    const SizedBox(height: 14),
                    const Text(
                      'Size',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(file.formattedSize),
                  ],
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
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldContinue || !mounted) {
        return;
      }

      final importPackage = _importPackageService.validate(file);

      if (!mounted) {
        return;
      }

      await _showPackageSummary(importPackage);
    } on ProductImportPickerException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open the selected file: '
            '$error',
          ),
        ),
      );
    }
  }

  Future<void> _showPackageSummary(ProductImportPackage importPackage) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import Package Validated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workbook',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(importPackage.workbookFileName),
              const SizedBox(height: 14),
              const Text(
                'Pictures Found',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(importPackage.pictureCount.toString()),
              const SizedBox(height: 14),
              const Text(
                'Package Warnings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(importPackage.warnings.length.toString()),
              if (importPackage.warnings.isNotEmpty)
                ...importPackage.warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                _previewParsedProducts(importPackage);
              },
              child: const Text('Preview Products'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _previewParsedProducts(
    ProductImportPackage importPackage,
  ) async {
    try {
      final result = _importExcelService.parse(importPackage);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Product Import Preview'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ImportTotalRow(
                  label: 'Products Found',
                  value: result.totalRows,
                ),
                _ImportTotalRow(label: 'Valid Rows', value: result.validRows),
                _ImportTotalRow(
                  label: 'Rows with Warnings',
                  value: result.warningRows,
                ),
                _ImportTotalRow(
                  label: 'Rows with Errors',
                  value: result.errorRows,
                ),
                _ImportTotalRow(
                  label: 'Pictures Matched',
                  value: result.picturesMatched,
                ),
                _ImportTotalRow(
                  label: 'Pictures Missing',
                  value: result.picturesMissing,
                ),
                if (result.workbookWarnings.isNotEmpty) ...[
                  const Divider(height: 24),
                  ...result.workbookWarnings.map((warning) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '• $warning',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) {
                        return ProductImportReviewScreen(result: result);
                      },
                    ),
                  );
                },
                child: const Text('Review Rows'),
              ),
            ],
          );
        },
      );
    } on ProductImportExcelException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to preview the products: '
            '$error',
          ),
        ),
      );
    }
  }

  void _startSelectionMode() {
    if (_deletingSelection) {
      return;
    }

    setState(() {
      _selectionMode = true;
      _selectedProductIds.clear();
    });
  }

  void _cancelSelectionMode() {
    if (_deletingSelection) {
      return;
    }

    setState(() {
      _selectionMode = false;
      _selectedProductIds.clear();
    });
  }

  void _toggleProductSelection(Product product) {
    if (_deletingSelection) {
      return;
    }

    setState(() {
      if (!_selectedProductIds.add(product.id)) {
        _selectedProductIds.remove(product.id);
      }
    });
  }

  bool _areAllVisibleSelected(List<Product> visibleProducts) {
    if (visibleProducts.isEmpty) {
      return false;
    }

    return visibleProducts.every((product) {
      return _selectedProductIds.contains(product.id);
    });
  }

  void _toggleAllVisible(List<Product> visibleProducts) {
    if (_deletingSelection || visibleProducts.isEmpty) {
      return;
    }

    final visibleIds = visibleProducts.map((product) => product.id).toSet();

    final allVisibleSelected = visibleIds.every(_selectedProductIds.contains);

    setState(() {
      if (allVisibleSelected) {
        _selectedProductIds.removeAll(visibleIds);
      } else {
        _selectedProductIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _deleteSelectedProducts(List<Product> allProducts) async {
    if (_deletingSelection || _selectedProductIds.isEmpty) {
      return;
    }

    final selectedProducts = allProducts
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();

    if (selectedProducts.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No selected products were found.')),
      );

      return;
    }

    final count = selectedProducts.length;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(
                'Delete $count selected '
                'product${count == 1 ? '' : 's'}?',
              ),
              content: const Text(
                'The selected products will be '
                'removed from the active product '
                'list. Their saved pictures will '
                'also be removed.\n\n'
                'This action cannot be undone '
                'from this screen.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    'Delete $count '
                    'Product${count == 1 ? '' : 's'}',
                  ),
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
      _deletingSelection = true;
    });

    try {
      final result = await _deleteService.deleteProducts(selectedProducts);

      if (!mounted) {
        return;
      }

      final deletedIds = result.items
          .where((item) => item.deleted)
          .map((item) => item.product.id)
          .toSet();

      setState(() {
        _selectedProductIds.removeAll(deletedIds);

        if (_selectedProductIds.isEmpty) {
          _selectionMode = false;
        }
      });

      await _showDeleteSelectedResults(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete the selected '
            'products: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingSelection = false;
        });
      }
    }
  }

  Future<void> _showDeleteSelectedResults(ProductDeleteResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final failedItems = result.items.where((item) => item.failed).toList();

        final pictureFailures = result.items
            .where((item) => item.pictureFailed)
            .toList();

        return AlertDialog(
          title: const Text('Product Deletion Results'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeleteResultLine(label: 'Selected', value: result.total),
                _DeleteResultLine(label: 'Deleted', value: result.deleted),
                _DeleteResultLine(label: 'Failed', value: result.failed),
                const Divider(height: 24),
                _DeleteResultLine(
                  label: 'Pictures Deleted',
                  value: result.picturesDeleted,
                ),
                _DeleteResultLine(
                  label: 'Picture Failures',
                  value: result.pictureFailures,
                ),
                if (failedItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Failed Products',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...failedItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${item.product.name}\n'
                        '  ${item.message}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                if (pictureFailures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Picture Cleanup Failures',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...pictureFailures.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${item.product.name}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOneProduct(Product product) async {
    if (_deletingProductIds.contains(product.id)) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text('Delete "${product.name}"?'),
              content: const Text(
                'The product will be removed from '
                'the active product list. The saved '
                'product picture will also be removed.\n\n'
                'This action cannot be undone from '
                'this screen.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Product'),
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
      _deletingProductIds.add(product.id);
    });

    try {
      final result = await _deleteService.deleteProducts(<Product>[product]);

      if (!mounted) {
        return;
      }

      final item = result.items.first;

      if (item.deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.pictureFailed
                  ? '${product.name} was deleted, '
                        'but the picture cleanup failed.'
                  : '${product.name} was deleted successfully.',
            ),
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Product Not Deleted'),
              content: Text(item.message),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete ${product.name}: '
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingProductIds.remove(product.id);
        });
      }
    }
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
      floatingActionButton: _selectionMode
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Product actions',
              position: PopupMenuPosition.over,
              onSelected: (value) {
                switch (value) {
                  case 'add':
                    _openForm();
                    break;

                  case 'import':
                    _selectImportFile();
                    break;

                  case 'template':
                    _downloadImportTemplate();
                    break;

                  case 'select':
                    _startSelectionMode();
                    break;
                }
              },
              itemBuilder: (context) {
                return const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'add',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.add),
                      title: Text('Add Manually'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'import',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.upload_file_outlined),
                      title: Text('Import Products'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'template',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.download_outlined),
                      title: Text('Download Sample Template'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'select',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.checklist_outlined),
                      title: Text('Select Products'),
                    ),
                  ),
                ];
              },
              child: const FloatingActionButton.extended(
                onPressed: null,
                icon: Icon(Icons.add),
                label: Text('Product Actions'),
              ),
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

                return Column(
                  children: [
                    if (_selectionMode)
                      _SelectionToolbar(
                        selectedCount: _selectedProductIds.length,
                        visibleCount: products.length,
                        allVisibleSelected: _areAllVisibleSelected(products),
                        deleting: _deletingSelection,
                        onCancel: _cancelSelectionMode,
                        onSelectAll: () {
                          _toggleAllVisible(products);
                        },
                        onDeleteSelected: _selectedProductIds.isEmpty
                            ? null
                            : () {
                                _deleteSelectedProducts(snapshot.data!);
                              },
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: products.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 8);
                        },
                        itemBuilder: (context, index) {
                          final product = products[index];

                          return _ProductCard(
                            product: product,
                            deleting: _deletingProductIds.contains(product.id),
                            selectionMode: _selectionMode,
                            selected: _selectedProductIds.contains(product.id),
                            onTap: () {
                              if (_selectionMode) {
                                _toggleProductSelection(product);
                              } else {
                                _openForm(product: product);
                              }
                            },
                            onSelectionChanged: () {
                              _toggleProductSelection(product);
                            },
                            onDelete: () {
                              _deleteOneProduct(product);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteResultLine extends StatelessWidget {
  const _DeleteResultLine({required this.label, required this.value});

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

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.selectedCount,
    required this.visibleCount,
    required this.allVisibleSelected,
    required this.deleting,
    required this.onCancel,
    required this.onSelectAll,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final int visibleCount;
  final bool allVisibleSelected;
  final bool deleting;

  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              color: Color(0xFF5B21B6),
              fontWeight: FontWeight.w800,
            ),
          ),
          TextButton(
            onPressed: deleting || visibleCount == 0 ? null : onSelectAll,
            child: Text(
              allVisibleSelected
                  ? 'Clear Visible'
                  : 'Select All Visible '
                        '($visibleCount)',
            ),
          ),
          TextButton(
            onPressed: deleting ? null : onCancel,
            child: const Text('Cancel Selection'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: deleting ? null : onDeleteSelected,
            icon: deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(
              deleting
                  ? 'Deleting Products...'
                  : 'Delete Selected '
                        '($selectedCount)',
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportTotalRow extends StatelessWidget {
  const _ImportTotalRow({required this.label, required this.value});

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
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.deleting,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onSelectionChanged,
    required this.onDelete,
  });

  final Product product;
  final bool deleting;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectionChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: product.active ? 1 : 0.58,
      child: Card(
        color: selected ? const Color(0xFFF5F3FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? const BorderSide(color: Color(0xFF7C3AED), width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(14),
          leading: _ProductThumbnail(product: product),
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
              '   Stock: ${product.currentStock}',
            ),
          ),
          trailing: selectionMode
              ? Checkbox(
                  value: selected,
                  onChanged: deleting
                      ? null
                      : (_) {
                          onSelectionChanged();
                        },
                )
              : deleting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Product options',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onTap();
                        break;

                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    return const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit Product'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: Color(0xFFB91C1C),
                          ),
                          title: Text(
                            'Delete Product',
                            style: TextStyle(color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                    ];
                  },
                ),
        ),
      ),
    );
  }
}

class _ProductThumbnail extends StatefulWidget {
  const _ProductThumbnail({required this.product});

  final Product product;

  @override
  State<_ProductThumbnail> createState() => _ProductThumbnailState();
}

class _ProductThumbnailState extends State<_ProductThumbnail> {
  final ProductPhotoService _photoService = ProductPhotoService.instance;

  late Future<Uint8List?> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _ProductThumbnail oldWidget) {
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

  Widget _placeholder() {
    return CircleAvatar(
      backgroundColor: widget.product.active
          ? const Color(0xFFEDE9FE)
          : const Color(0xFFE5E7EB),
      child: Icon(
        Icons.inventory_2_outlined,
        color: widget.product.active
            ? const Color(0xFF6D28D9)
            : const Color(0xFF6B7280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _photoFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;

        if (bytes == null || bytes.isEmpty) {
          return _placeholder();
        }

        return CircleAvatar(
          backgroundColor: widget.product.active
              ? const Color(0xFFEDE9FE)
              : const Color(0xFFE5E7EB),
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (exception, stackTrace) {},
        );
      },
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
