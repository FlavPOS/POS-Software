import 'package:file_saver/file_saver.dart';

import 'product_import_template_service.dart';

enum ProductTemplateDownloadResult { saved, cancelled }

class ProductImportDownloadService {
  ProductImportDownloadService._();

  static final ProductImportDownloadService instance =
      ProductImportDownloadService._();

  final ProductImportTemplateService _templateService =
      ProductImportTemplateService.instance;

  Future<ProductTemplateDownloadResult> downloadTemplate() async {
    final package = _templateService.createPackage();

    final fileName = package.fileName.toLowerCase().endsWith('.zip')
        ? package.fileName.substring(0, package.fileName.length - 4)
        : package.fileName;

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: package.bytes,
      fileExtension: 'zip',
      includeExtension: true,
      mimeType: MimeType.custom,
      customMimeType: 'application/zip',
    );

    return ProductTemplateDownloadResult.saved;
  }
}
