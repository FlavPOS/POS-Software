import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/product.dart';

class DuplicateLocalProductException implements Exception {
  const DuplicateLocalProductException(this.field);

  final String field;

  @override
  String toString() {
    return '$field already exists.';
  }
}

class ProductRepository {
  ProductRepository._();

  static final ProductRepository instance = ProductRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final StreamController<List<Product>> _productsController =
      StreamController<List<Product>>.broadcast();

  Stream<List<Product>> watchProducts() {
    Future<void>.microtask(refreshProducts);

    return _productsController.stream;
  }

  Future<List<Product>> getProducts({bool includeDeleted = false}) async {
    final database = await _databaseHelper.database;

    final rows = await database.query(
      DatabaseHelper.productsTable,
      where: includeDeleted ? null : 'is_deleted = ?',
      whereArgs: includeDeleted ? null : <Object?>[0],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Product.fromSqlite).toList();
  }

  Future<Product?> getProductById(String productId) async {
    final database = await _databaseHelper.database;

    final rows = await database.query(
      DatabaseHelper.productsTable,
      where: 'id = ?',
      whereArgs: <Object?>[productId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Product.fromSqlite(rows.first);
  }

  Future<Product?> getProductBySku(String sku) async {
    final database = await _databaseHelper.database;

    final normalizedSku = sku.trim().toUpperCase();

    final rows = await database.query(
      DatabaseHelper.productsTable,
      where: 'sku = ? AND is_deleted = ?',
      whereArgs: <Object?>[normalizedSku, 0],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Product.fromSqlite(rows.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final database = await _databaseHelper.database;

    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) {
      return null;
    }

    final rows = await database.query(
      DatabaseHelper.productsTable,
      where: 'barcode = ? AND is_deleted = ?',
      whereArgs: <Object?>[normalizedBarcode, 0],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Product.fromSqlite(rows.first);
  }

  Future<void> insertLocal(Product product) async {
    final database = await _databaseHelper.database;

    try {
      await database.insert(
        DatabaseHelper.productsTable,
        product.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (error) {
      _throwFriendlyDatabaseError(error);
    }

    await refreshProducts();
  }

  Future<void> updateLocal(Product product) async {
    final database = await _databaseHelper.database;

    try {
      final updatedRows = await database.update(
        DatabaseHelper.productsTable,
        product.toSqlite(),
        where: 'id = ?',
        whereArgs: <Object?>[product.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (updatedRows == 0) {
        await database.insert(
          DatabaseHelper.productsTable,
          product.toSqlite(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    } on DatabaseException catch (error) {
      _throwFriendlyDatabaseError(error);
    }

    await refreshProducts();
  }

  Future<void> saveLocal(Product product) async {
    final existingProduct = await getProductById(product.id);

    if (existingProduct == null) {
      await insertLocal(product);
      return;
    }

    await updateLocal(product);
  }

  Future<void> upsertFromFirebase(Product remoteProduct) async {
    final database = await _databaseHelper.database;

    final localProduct = await getProductById(remoteProduct.id);

    if (localProduct != null) {
      final hasUnsyncedLocalChange =
          localProduct.syncStatus != ProductSyncStatus.synced;

      final localIsNewer = localProduct.updatedAt > remoteProduct.updatedAt;

      if (hasUnsyncedLocalChange && localIsNewer) {
        return;
      }
    }

    final mergedProduct = remoteProduct.copyWith(
      localPhotoPath: localProduct?.localPhotoPath,
      syncStatus: ProductSyncStatus.synced,
      clearSyncError: true,
    );

    try {
      await database.insert(
        DatabaseHelper.productsTable,
        mergedProduct.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      _throwFriendlyDatabaseError(error);
    }

    await refreshProducts();
  }

  Future<List<Product>> getPendingProducts() async {
    final database = await _databaseHelper.database;

    final rows = await database.query(
      DatabaseHelper.productsTable,
      where: 'sync_status IN (?, ?)',
      whereArgs: <Object?>[ProductSyncStatus.pending, ProductSyncStatus.failed],
      orderBy: 'updated_at ASC',
    );

    return rows.map(Product.fromSqlite).toList();
  }

  Future<void> markPending(String productId) async {
    await _updateSyncStatus(
      productId: productId,
      status: ProductSyncStatus.pending,
      clearError: true,
    );
  }

  Future<void> markSyncing(String productId) async {
    await _updateSyncStatus(
      productId: productId,
      status: ProductSyncStatus.syncing,
      clearError: true,
    );
  }

  Future<void> markSynced(String productId) async {
    await _updateSyncStatus(
      productId: productId,
      status: ProductSyncStatus.synced,
      clearError: true,
    );
  }

  Future<void> markFailed({
    required String productId,
    required String error,
  }) async {
    final database = await _databaseHelper.database;

    await database.update(
      DatabaseHelper.productsTable,
      <String, Object?>{
        'sync_status': ProductSyncStatus.failed,
        'sync_error': error,
      },
      where: 'id = ?',
      whereArgs: <Object?>[productId],
    );

    await refreshProducts();
  }

  Future<void> updateLocalPhotoPath({
    required String productId,
    String? localPhotoPath,
  }) async {
    final database = await _databaseHelper.database;

    await database.update(
      DatabaseHelper.productsTable,
      <String, Object?>{'local_photo_path': localPhotoPath},
      where: 'id = ?',
      whereArgs: <Object?>[productId],
    );

    await refreshProducts();
  }

  Future<void> softDeleteLocal({
    required String productId,
    required int updatedAt,
  }) async {
    final database = await _databaseHelper.database;

    await database.update(
      DatabaseHelper.productsTable,
      <String, Object?>{
        'is_deleted': 1,
        'updated_at': updatedAt,
        'sync_status': ProductSyncStatus.pending,
        'sync_error': null,
      },
      where: 'id = ?',
      whereArgs: <Object?>[productId],
    );

    await refreshProducts();
  }

  Future<void> refreshProducts() async {
    if (_productsController.isClosed) {
      return;
    }

    final products = await getProducts();

    _productsController.add(products);
  }

  Future<void> _updateSyncStatus({
    required String productId,
    required String status,
    required bool clearError,
  }) async {
    final database = await _databaseHelper.database;

    await database.update(
      DatabaseHelper.productsTable,
      <String, Object?>{
        'sync_status': status,
        if (clearError) 'sync_error': null,
      },
      where: 'id = ?',
      whereArgs: <Object?>[productId],
    );

    await refreshProducts();
  }

  Never _throwFriendlyDatabaseError(DatabaseException error) {
    final message = error.toString().toLowerCase();

    if (message.contains('idx_products_sku') ||
        message.contains('products.sku')) {
      throw const DuplicateLocalProductException('SKU');
    }

    if (message.contains('idx_products_barcode') ||
        message.contains('products.barcode')) {
      throw const DuplicateLocalProductException('Barcode');
    }

    throw error;
  }

  Future<void> dispose() async {
    await _productsController.close();
  }
}
