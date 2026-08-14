import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductPhotoService {
  ProductPhotoService._();

  static final ProductPhotoService instance = ProductPhotoService._();

  final ImagePicker _picker = ImagePicker();

  String _photoKey(String sku) {
    final normalizedSku = sku.trim().toUpperCase();
    return 'local_product_photo_$normalizedSku';
  }

  String _safeSku(String sku) {
    return sku.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
  }

  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
  }

  Future<XFile?> takePhoto() {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
  }

  Future<Directory> _photoDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();

    final directory = Directory(
      path.join(documentsDirectory.path, 'product_photos'),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<String> savePhoto({
    required String sku,
    required XFile selectedPhoto,
  }) async {
    final directory = await _photoDirectory();

    final selectedExtension = path.extension(selectedPhoto.path).toLowerCase();

    final extension = selectedExtension.isEmpty ? '.jpg' : selectedExtension;

    final destinationPath = path.join(
      directory.path,
      '${_safeSku(sku)}$extension',
    );

    final destinationFile = File(destinationPath);

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await File(selectedPhoto.path).copy(destinationPath);

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_photoKey(sku), destinationPath);

    return destinationPath;
  }

  Future<String?> getPhotoPath(String sku) async {
    final preferences = await SharedPreferences.getInstance();

    final savedPath = preferences.getString(_photoKey(sku));

    if (savedPath == null || savedPath.isEmpty) {
      return null;
    }

    final savedFile = File(savedPath);

    if (!await savedFile.exists()) {
      await preferences.remove(_photoKey(sku));
      return null;
    }

    return savedPath;
  }

  Future<void> movePhotoToNewSku({
    required String oldSku,
    required String newSku,
  }) async {
    final normalizedOldSku = oldSku.trim().toUpperCase();
    final normalizedNewSku = newSku.trim().toUpperCase();

    if (normalizedOldSku == normalizedNewSku) {
      return;
    }

    final oldPath = await getPhotoPath(normalizedOldSku);

    if (oldPath == null) {
      return;
    }

    final oldFile = File(oldPath);

    if (!await oldFile.exists()) {
      return;
    }

    final directory = await _photoDirectory();

    final oldExtension = path.extension(oldPath);
    final extension = oldExtension.isEmpty ? '.jpg' : oldExtension;

    final newPath = path.join(
      directory.path,
      '${_safeSku(normalizedNewSku)}$extension',
    );

    final newFile = File(newPath);

    if (await newFile.exists()) {
      await newFile.delete();
    }

    await oldFile.rename(newPath);

    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_photoKey(normalizedOldSku));

    await preferences.setString(_photoKey(normalizedNewSku), newPath);
  }

  Future<Uint8List?> readPhotoBytes(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) {
      return null;
    }

    final file = File(photoPath);

    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  Future<void> deletePhoto(String sku) async {
    final preferences = await SharedPreferences.getInstance();

    final key = _photoKey(sku);
    final savedPath = preferences.getString(key);

    if (savedPath != null && savedPath.isNotEmpty) {
      final savedFile = File(savedPath);

      if (await savedFile.exists()) {
        await savedFile.delete();
      }
    }

    await preferences.remove(key);
  }
}
