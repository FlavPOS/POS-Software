import 'package:file_saver/file_saver.dart';

import '../models/product_update_template_package.dart';
import 'product_update_template_service.dart';

class ProductUpdateTemplateDownloadService {
  ProductUpdateTemplateDownloadService._();

  static final ProductUpdateTemplateDownloadService instance =
      ProductUpdateTemplateDownloadService._();

  final ProductUpdateTemplateService _templateService =
      ProductUpdateTemplateService.instance;

  Future<ProductUpdateTemplatePackage> downloadTemplate() async {
    final package = await _templateService.createPackage();

    final baseName = package.fileName.toLowerCase().endsWith('.zip')
        ? package.fileName.substring(0, package.fileName.length - 4)
        : package.fileName;

    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: package.bytes,
      fileExtension: 'zip',
      includeExtension: true,
      mimeType: MimeType.custom,
      customMimeType: 'application/zip',
    );

    return package;
  }
}
