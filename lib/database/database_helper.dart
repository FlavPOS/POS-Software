import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String databaseName = 'simple_pos.db';
  static const int databaseVersion = 1;

  static const String productsTable = 'products';

  Database? _database;

  Future<Database> get database async {
    final existingDatabase = _database;

    if (existingDatabase != null) {
      return existingDatabase;
    }

    final initializedDatabase = await _initializeDatabase();
    _database = initializedDatabase;

    return initializedDatabase;
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();

    final databasePath = path.join(databasesPath, databaseName);

    return openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onConfigure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database database, int version) async {
    await _createProductsTable(database);
    await _createProductIndexes(database);
  }

  Future<void> _onOpen(Database database) async {
    // Safety net for fresh installations or interrupted migrations.
    await _createProductsTable(database);
    await _createProductIndexes(database);
  }

  Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createProductsTable(database);
      await _createProductIndexes(database);
    }
  }

  Future<void> _createProductsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $productsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT NOT NULL COLLATE NOCASE,
        barcode TEXT COLLATE NOCASE,
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        beginning_stock INTEGER NOT NULL DEFAULT 0,
        current_stock INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        local_photo_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
      ''');
  }

  Future<void> _createProductIndexes(Database database) async {
    await database.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS
      idx_products_sku
      ON $productsTable(sku)
      ''');

    await database.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS
      idx_products_barcode
      ON $productsTable(barcode)
      WHERE barcode IS NOT NULL
      AND TRIM(barcode) != ''
      ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_products_name
      ON $productsTable(name)
      ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_products_sync_status
      ON $productsTable(sync_status)
      ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_products_updated_at
      ON $productsTable(updated_at)
      ''');
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> close() async {
    final currentDatabase = _database;

    if (currentDatabase == null) {
      return;
    }

    await currentDatabase.close();
    _database = null;
  }

  Future<String> getDatabasePath() async {
    final databasesPath = await getDatabasesPath();

    return path.join(databasesPath, databaseName);
  }

  Future<void> clearAllProducts() async {
    final localDatabase = await database;

    await localDatabase.delete(productsTable);
  }
}
