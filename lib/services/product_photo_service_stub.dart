import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class ProductPhotoService {
  ProductPhotoService._();

  static final ProductPhotoService instance = ProductPhotoService._();

  Future<XFile?> pickFromGallery() async {
    return null;
  }

  Future<XFile?> takePhoto() async {
    return null;
  }

  Future<String?> getPhotoPath(String sku) async {
    return null;
  }

  Future<String> savePhoto({
    required String sku,
    required XFile selectedPhoto,
  }) {
    throw UnsupportedError(
      'Permanent local product pictures are available only on Android.',
    );
  }

  Future<void> movePhotoToNewSku({
    required String oldSku,
    required String newSku,
  }) async {}

  Future<void> deletePhoto(String sku) async {}

  Future<Uint8List?> readPhotoBytes(String? photoPath) async {
    return null;
  }
}
