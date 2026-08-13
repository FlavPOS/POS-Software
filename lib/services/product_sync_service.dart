import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';

class ProductSyncService {
  ProductSyncService._();

  static final ProductSyncService instance = ProductSyncService._();

  final FirebaseDatabase _firebase = FirebaseDatabase.instance;

  final ProductRepository _repository = ProductRepository.instance;

  StreamSubscription<DatabaseEvent>? _productsSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _started = false;
  bool _syncing = false;

  DatabaseReference get _productsReference {
    return _firebase.ref('products');
  }

  Future<void> start() async {
    if (kIsWeb || _started) {
      return;
    }

    _started = true;

    _productsSubscription = _productsReference.onValue.listen(
      _handleFirebaseProducts,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Firebase product listener failed: $error');
      },
    );

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isConnected = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (isConnected) {
        unawaited(syncPendingProducts());
      }
    });

    await syncPendingProducts();
  }

  Future<void> saveProduct(Product product) async {
    if (kIsWeb) {
      await _productsReference.child(product.id).update(product.toFirebase());

      return;
    }

    final pendingProduct = product.copyWith(
      syncStatus: ProductSyncStatus.pending,
      clearSyncError: true,
    );

    await _repository.saveLocal(pendingProduct);

    await syncProduct(pendingProduct);
  }

  Future<void> syncProduct(Product product) async {
    if (kIsWeb) {
      return;
    }

    try {
      await _repository.markSyncing(product.id);

      if (product.isDeleted) {
        await _productsReference.child(product.id).remove();
      } else {
        await _productsReference.child(product.id).update(product.toFirebase());
      }

      await _repository.markSynced(product.id);
    } catch (error) {
      await _repository.markFailed(
        productId: product.id,
        error: error.toString(),
      );

      debugPrint('Product ${product.id} queued for sync: $error');
    }
  }

  Future<void> syncPendingProducts() async {
    if (kIsWeb || _syncing) {
      return;
    }

    _syncing = true;

    try {
      final products = await _repository.getPendingProducts();

      for (final product in products) {
        await syncProduct(product);
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _handleFirebaseProducts(DatabaseEvent event) async {
    if (kIsWeb) {
      return;
    }

    final raw = event.snapshot.value;

    if (raw == null) {
      await _repository.refreshProducts();
      return;
    }

    if (raw is! Map) {
      return;
    }

    for (final entry in raw.entries) {
      final value = entry.value;

      if (value is! Map) {
        continue;
      }

      final existingLocal = await _repository.getProductById(
        entry.key.toString(),
      );

      final remoteProduct = Product.fromFirebase(
        id: entry.key.toString(),
        map: Map<Object?, Object?>.from(value),
        localPhotoPath: existingLocal?.localPhotoPath,
      );

      await _repository.upsertFromFirebase(remoteProduct);
    }
  }

  Future<void> stop() async {
    await _productsSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    _productsSubscription = null;
    _connectivitySubscription = null;
    _started = false;
  }
}
