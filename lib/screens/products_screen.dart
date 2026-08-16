import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_update_template_package.dart';
import '../models/product_item_master_export.dart';
import '../models/product_delete_result.dart';
import '../models/product_import_package.dart';
import '../repositories/product_repository.dart';
import '../services/product_delete_service.dart';
import '../services/product_photo_service.dart';
import '../services/product_picture_update_parse_service.dart';
import '../services/product_picture_update_picker_service.dart';
import '../services/product_item_master_export_service.dart';
import '../services/product_import_download_service.dart';
import '../services/product_import_picker_service.dart';
import '../services/product_import_excel_service.dart';
import '../services/product_import_package_service.dart';
import '../services/product_update_template_download_service.dart';
import '../services/product_update_template_service.dart';
import '../services/product_update_picker_service.dart';
import '../services/product_update_package_service.dart';
import '../services/product_update_excel_service.dart';
import '../services/product_service.dart';
import 'product_form_screen.dart';
import 'product_import_review_screen.dart';
import 'product_picture_update_review_screen.dart';
import 'product_update_review_screen.dart';

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

  final ProductUpdateTemplateDownloadService
  _productUpdateTemplateDownloadService =
      ProductUpdateTemplateDownloadService.instance;

  bool _downloadingProductUpdateTemplate = false;

  final ProductItemMasterExportService _itemMasterExportService =
      ProductItemMasterExportService.instance;

  bool _exportingItemMaster = false;
  final TextEditingController _searchController = TextEditingController();

  final ProductImportPackageService _importPackageService =
      ProductImportPackageService.instance;

  final ProductImportExcelService _importExcelService =
      ProductImportExcelService.instance;

  final ProductImportPickerService _importPickerService =
      ProductImportPickerService.instance;

  final ProductPictureUpdatePickerService _pictureUpdatePickerService =
      ProductPictureUpdatePickerService.instance;

  final ProductPictureUpdateParseService _pictureUpdateParseService =
      ProductPictureUpdateParseService.instance;

  bool _processingPictureUpdate = false;

  int _pictureRefreshVersion = 0;

  final ProductUpdatePickerService _productUpdatePickerService =
      ProductUpdatePickerService.instance;

  final ProductUpdatePackageService _productUpdatePackageService =
      ProductUpdatePackageService.instance;

  final ProductUpdateExcelService _productUpdateExcelService =
      ProductUpdateExcelService.instance;

  bool _processingProductUpdate = false;

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

  Future<void> _selectProductUpdateFile() async {
    if (_processingProductUpdate) {
      return;
    }

    try {
      final selectedFile = await _productUpdatePickerService.pickFile();

      if (selectedFile == null || !mounted) {
        return;
      }

      setState(() {
        _processingProductUpdate = true;
      });

      final updatePackage = _productUpdatePackageService.validate(selectedFile);

      final parseResult = await _productUpdateExcelService.parse(updatePackage);

      if (!mounted) {
        return;
      }

      final productsUpdated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) {
            return ProductUpdateReviewScreen(result: parseResult);
          },
        ),
      );

      if (productsUpdated == true && mounted) {
        setState(() {
          _pictureRefreshVersion++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Existing products updated '
              'successfully.',
            ),
          ),
        );
      }
    } on ProductUpdatePickerException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on ProductUpdatePackageException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on ProductUpdateExcelException catch (error) {
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
            'Unable to prepare the Product '
            'Update: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingProductUpdate = false;
        });
      }
    }
  }

  Future<void> _selectPictureUpdateZip() async {
    if (_processingPictureUpdate) {
      return;
    }

    try {
      final selectedFile = await _pictureUpdatePickerService.pickZip();

      if (selectedFile == null || !mounted) {
        return;
      }

      setState(() {
        _processingPictureUpdate = true;
      });

      final updatePackage = await _pictureUpdateParseService.parse(
        selectedFile,
      );

      if (!mounted) {
        return;
      }

      final picturesUpdated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) {
            return ProductPictureUpdateReviewScreen(package: updatePackage);
          },
        ),
      );

      if (picturesUpdated == true && mounted) {
        setState(() {
          _pictureRefreshVersion++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Product pictures updated '
              'successfully.',
            ),
          ),
        );
      }
    } on ProductPictureUpdatePickerException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on ProductPictureUpdateParseException catch (error) {
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
            'Unable to prepare the picture '
            'update: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingPictureUpdate = false;
        });
      }
    }
  }

  Future<void> _downloadItemMaster() async {
    if (_exportingItemMaster) {
      return;
    }

    setState(() {
      _exportingItemMaster = true;
    });

    try {
      final export = await _itemMasterExportService.createExport();

      await _itemMasterExportService.download(export);

      if (!mounted) {
        return;
      }

      await _showItemMasterExportResult(export);
    } on ProductItemMasterExportException catch (error) {
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
            'Unable to download the Item '
            'Master: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingItemMaster = false;
        });
      }
    }
  }

  Future<void> _showItemMasterExportResult(
    ProductItemMasterExport export,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Item Master Downloaded'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExportResultLine(
                label: 'Products Exported',
                value: export.productsExported,
              ),
              _ExportResultLine(
                label: 'Pictures Included',
                value: export.picturesIncluded,
              ),
              _ExportResultLine(
                label: 'Pictures Missing',
                value: export.picturesMissing,
              ),
              _ExportResultLine(
                label: 'Picture Failures',
                value: export.pictureFailures,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('ZIP File Size')),
                  Text(
                    export.formattedFileSize,
                    style: const TextStyle(
                      color: Color(0xFF5B21B6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
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

  Future<void> _downloadProductUpdateTemplate() async {
    if (_downloadingProductUpdateTemplate) {
      return;
    }

    setState(() {
      _downloadingProductUpdateTemplate = true;
    });

    try {
      final package = await _productUpdateTemplateDownloadService
          .downloadTemplate();

      if (!mounted) {
        return;
      }

      await _showProductUpdateTemplateResult(package);
    } on ProductUpdateTemplateException catch (error) {
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
            'Unable to download the Product '
            'Update Template: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingProductUpdateTemplate = false;
        });
      }
    }
  }

  Future<void> _showProductUpdateTemplateResult(
    ProductUpdateTemplatePackage package,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Product Update Template Downloaded'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExportResultLine(
                label: 'Active Products',
                value: package.activeProducts,
              ),
              _ExportResultLine(
                label: 'With Pictures',
                value: package.productsWithPictures,
              ),
              _ExportResultLine(
                label: 'Missing Pictures',
                value: package.productsMissingPictures,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('ZIP File Size')),
                  Text(
                    package.formattedFileSize,
                    style: const TextStyle(
                      color: Color(0xFF5B21B6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Enter update values only for '
                'products that need changes. '
                'Blank editable cells will keep '
                'their existing values.',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
              ),
            ],
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
        actions: <Widget>[
          StreamBuilder<DatabaseEvent>(
            stream: _service.connectedRef.onValue,
            builder: (context, snapshot) {
              final online = snapshot.data?.snapshot.value == true;

              return _ProductSyncStatus(online: online);
            },
          ),
          const SizedBox(width: 10),
        ],
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

                  case 'update_existing':
                    _selectProductUpdateFile();
                    break;

                  case 'update_pictures':
                    _selectPictureUpdateZip();
                    break;

                  case 'update_template':
                    _downloadProductUpdateTemplate();
                    break;

                  case 'template':
                    _downloadImportTemplate();
                    break;

                  case 'item_master':
                    _downloadItemMaster();
                    break;

                  case 'select':
                    _startSelectionMode();
                    break;
                }
              },
              itemBuilder: (context) {
                return <PopupMenuEntry<String>>[
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
                    value: 'update_existing',
                    enabled: !_processingProductUpdate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _processingProductUpdate
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.edit_note_outlined),
                      title: Text(
                        _processingProductUpdate
                            ? 'Preparing Product Update...'
                            : 'Update Existing Products',
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'update_pictures',
                    enabled: !_processingPictureUpdate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _processingPictureUpdate
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.add_photo_alternate_outlined),
                      title: Text(
                        _processingPictureUpdate
                            ? 'Preparing Picture Update...'
                            : 'Update Product Pictures',
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'update_template',
                    enabled: !_downloadingProductUpdateTemplate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _downloadingProductUpdateTemplate
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.system_update_alt_outlined),
                      title: Text(
                        _downloadingProductUpdateTemplate
                            ? 'Preparing Update Template...'
                            : 'Download Product Update '
                                  'Template',
                      ),
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
                    value: 'item_master',
                    enabled: !_exportingItemMaster,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _exportingItemMaster
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.folder_zip_outlined),
                      title: Text(
                        _exportingItemMaster
                            ? 'Preparing Item Master...'
                            : 'Download Item Master '
                                  'with Pictures',
                      ),
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
                            pictureRefreshVersion: _pictureRefreshVersion,
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

class _ExportResultLine extends StatelessWidget {
  const _ExportResultLine({required this.label, required this.value});

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

  static const double _tabletBreakpoint = 600;

  final int selectedCount;
  final int visibleCount;
  final bool allVisibleSelected;
  final bool deleting;

  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback? onDeleteSelected;

  bool get _hasSelection => selectedCount > 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _tabletBreakpoint;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(
            compact ? 16 : 24,
            0,
            compact ? 16 : 24,
            12,
          ),
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC4B5FD)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: compact ? _buildPhoneToolbar() : _buildTabletToolbar(),
        );
      },
    );
  }

  Widget _buildPhoneToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildModeIcon(),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Selection Mode',
                style: TextStyle(
                  color: Color(0xFF4C1D95),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildSelectedBadge(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSelectVisibleButton()),
            const SizedBox(width: 8),
            _buildCancelButton(),
          ],
        ),
        const SizedBox(height: 12),
        if (_hasSelection)
          SizedBox(width: double.infinity, child: _buildDeleteButton())
        else
          _buildEmptySelectionMessage(),
      ],
    );
  }

  Widget _buildTabletToolbar() {
    return Row(
      children: [
        _buildModeIcon(),
        const SizedBox(width: 9),
        const Text(
          'Selection Mode',
          style: TextStyle(
            color: Color(0xFF4C1D95),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        _buildSelectedBadge(),
        const Spacer(),
        _buildSelectVisibleButton(),
        const SizedBox(width: 8),
        _buildCancelButton(),
        const SizedBox(width: 8),
        if (_hasSelection)
          _buildDeleteButton()
        else
          const Text(
            'Select products to continue',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildModeIcon() {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFDDD6FE),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.checklist_rounded,
        color: Color(0xFF6D28D9),
        size: 19,
      ),
    );
  }

  Widget _buildSelectedBadge() {
    final color = _hasSelection
        ? const Color(0xFF6D28D9)
        : const Color(0xFF6B7280);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _hasSelection
            ? const Color(0xFFEDE9FE)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$selectedCount selected',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSelectVisibleButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF5B21B6),
        side: const BorderSide(color: Color(0xFFC4B5FD)),
      ),
      onPressed: deleting || visibleCount == 0 ? null : onSelectAll,
      icon: Icon(
        allVisibleSelected
            ? Icons.remove_done_outlined
            : Icons.done_all_outlined,
        size: 18,
      ),
      label: Text(
        allVisibleSelected
            ? 'Clear Visible'
            : 'Select All Visible ($visibleCount)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton.icon(
      onPressed: deleting ? null : onCancel,
      icon: const Icon(Icons.close_rounded, size: 18),
      label: const Text('Cancel'),
    );
  }

  Widget _buildEmptySelectionMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app_outlined, color: Color(0xFF6B7280), size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Select products below to enable '
              'bulk deletion.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFB91C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          : const Icon(Icons.delete_outline, size: 19),
      label: Text(
        deleting
            ? 'Deleting Products...'
            : 'Delete $selectedCount Selected '
                  'Product'
                  '${selectedCount == 1 ? '' : 's'}',
        style: const TextStyle(fontWeight: FontWeight.w700),
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
    required this.pictureRefreshVersion,
    required this.deleting,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onSelectionChanged,
    required this.onDelete,
  });

  final Product product;
  final int pictureRefreshVersion;
  final bool deleting;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectionChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).width >= 600;

    final cardHeight = tablet ? 148.0 : 132.0;

    return Opacity(
      opacity: product.active ? 1 : 0.58,
      child: Card(
        margin: EdgeInsets.zero,
        color: selected ? const Color(0xFFF5F3FF) : Colors.white,
        elevation: 0.6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? const BorderSide(color: Color(0xFF7C3AED), width: 1.5)
              : const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: cardHeight,
          child: InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProductThumbnail(
                  key: ValueKey<String>(
                    '${product.id}:'
                    '$pictureRefreshVersion',
                  ),
                  product: product,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'SKU: ${product.sku}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 18,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Selling: PHP '
                              '${product.sellingPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Stock: '
                              '${product.currentStock}',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Align(alignment: Alignment.center, child: _buildTrailing()),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: product.active
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        product.active ? 'ACTIVE' : 'INACTIVE',
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildTrailing() {
    if (selectionMode) {
      return Checkbox(
        value: selected,
        onChanged: deleting
            ? null
            : (_) {
                onSelectionChanged();
              },
      );
    }

    if (deleting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<String>(
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
              leading: Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
              title: Text(
                'Delete Product',
                style: TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          ),
        ];
      },
    );
  }
}

class _ProductThumbnail extends StatefulWidget {
  const _ProductThumbnail({super.key, required this.product});

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

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).width >= 600;

    final imageWidth = tablet ? 140.0 : 124.0;

    return SizedBox(
      width: imageWidth,
      height: double.infinity,
      child: FutureBuilder<Uint8List?>(
        future: _photoFuture,
        builder: (context, snapshot) {
          final bytes = snapshot.data;

          if (bytes == null || bytes.isEmpty) {
            return _placeholder();
          }

          return Image.memory(
            bytes,
            width: imageWidth,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return _placeholder();
            },
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.product.active
          ? const Color(0xFFEDE9FE)
          : const Color(0xFFE5E7EB),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 38,
        color: widget.product.active
            ? const Color(0xFF6D28D9)
            : const Color(0xFF6B7280),
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

class _ProductSyncStatus extends StatelessWidget {
  const _ProductSyncStatus({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final compact = screenWidth < 600;

    final backgroundColor = online
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFF7ED);

    final foregroundColor = online
        ? const Color(0xFF047857)
        : const Color(0xFFC2410C);

    final borderColor = online
        ? const Color(0xFFA7F3D0)
        : const Color(0xFFFED7AA);

    final label = online
        ? compact
              ? 'Online'
              : 'Online - Live sync'
        : compact
        ? 'Offline'
        : 'Offline - Sync later';

    return Center(
      child: Semantics(
        label: online
            ? 'Product synchronization is online'
            : 'Product synchronization is offline',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                size: 16,
                color: foregroundColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
