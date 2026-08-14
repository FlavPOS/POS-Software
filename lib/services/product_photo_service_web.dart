import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';
import 'package:image_picker/image_picker.dart';

class ProductPhotoService {
  ProductPhotoService._();

  static final ProductPhotoService instance = ProductPhotoService._();

  static const String _databaseName = 'simple_pos_local_photos';

  static const String _storeName = 'product_photos';

  static const int _databaseVersion = 1;

  final ImagePicker _picker = ImagePicker();

  Database? _database;

  String _normalizeSku(String sku) {
    return sku.trim().toUpperCase();
  }

  String _photoKey(String sku) {
    return _normalizeSku(sku);
  }

  String _localPhotoPath(String sku) {
    return 'indexeddb://$_storeName/${_normalizeSku(sku)}';
  }

  Future<Database> _openDatabase() async {
    final existingDatabase = _database;

    if (existingDatabase != null) {
      return existingDatabase;
    }

    final openedDatabase = await idbFactoryBrowser.open(
      _databaseName,
      version: _databaseVersion,
      onUpgradeNeeded: (event) {
        final database = event.database;

        if (!database.objectStoreNames.contains(_storeName)) {
          database.createObjectStore(_storeName);
        }
      },
    );

    _database = openedDatabase;

    return openedDatabase;
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

  Future<String?> getPhotoPath(String sku) async {
    final bytes = await _getPhotoBytesBySku(sku);

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    return _localPhotoPath(sku);
  }

  Future<String> savePhoto({
    required String sku,
    required XFile selectedPhoto,
  }) async {
    final normalizedSku = _normalizeSku(sku);

    final bytes = await selectedPhoto.readAsBytes();

    final database = await _openDatabase();

    final transaction = database.transaction(_storeName, idbModeReadWrite);

    final store = transaction.objectStore(_storeName);

    await store.put(<String, Object?>{
      'sku': normalizedSku,
      'bytes': bytes.toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, _photoKey(normalizedSku));

    await transaction.completed;

    return _localPhotoPath(normalizedSku);
  }

  Future<void> movePhotoToNewSku({
    required String oldSku,
    required String newSku,
  }) async {
    final normalizedOldSku = _normalizeSku(oldSku);

    final normalizedNewSku = _normalizeSku(newSku);

    if (normalizedOldSku == normalizedNewSku) {
      return;
    }

    final bytes = await _getPhotoBytesBySku(normalizedOldSku);

    if (bytes == null || bytes.isEmpty) {
      return;
    }

    final database = await _openDatabase();

    final transaction = database.transaction(_storeName, idbModeReadWrite);

    final store = transaction.objectStore(_storeName);

    await store.put(<String, Object?>{
      'sku': normalizedNewSku,
      'bytes': bytes.toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, _photoKey(normalizedNewSku));

    await store.delete(_photoKey(normalizedOldSku));

    await transaction.completed;
  }

  Future<void> deletePhoto(String sku) async {
    final database = await _openDatabase();

    final transaction = database.transaction(_storeName, idbModeReadWrite);

    final store = transaction.objectStore(_storeName);

    await store.delete(_photoKey(sku));

    await transaction.completed;
  }

  Future<Uint8List?> readPhotoBytes(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty) {
      return null;
    }

    const prefix = 'indexeddb://product_photos/';

    final sku = photoPath.startsWith(prefix)
        ? photoPath.substring(prefix.length)
        : photoPath;

    return _getPhotoBytesBySku(sku);
  }

  Future<Uint8List?> _getPhotoBytesBySku(String sku) async {
    final database = await _openDatabase();

    final transaction = database.transaction(_storeName, idbModeReadOnly);

    final store = transaction.objectStore(_storeName);

    final rawValue = await store.getObject(_photoKey(sku));

    await transaction.completed;

    if (rawValue is! Map) {
      return null;
    }

    final rawBytes = rawValue['bytes'];

    if (rawBytes is Uint8List) {
      return rawBytes;
    }

    if (rawBytes is List) {
      return Uint8List.fromList(
        rawBytes.map((value) => (value as num).toInt()).toList(),
      );
    }

    return null;
  }
}
