import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

/// Local SQLite store. All data stays on the phone.
class AppDb {
  AppDb._(this._db);

  final Database _db;

  static Future<AppDb> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'money.db'),
      version: 5,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
        if (oldVersion < 3) await _upgradeToV3(db);
        if (oldVersion < 4) await _upgradeToV4(db);
        if (oldVersion < 5) await _upgradeToV5(db);
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE txns(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            merchant TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            account TEXT NOT NULL DEFAULT '',
            date INTEGER NOT NULL,
            source TEXT NOT NULL DEFAULT 'manual',
            source_ref TEXT,
            raw TEXT
          )''');
        await db.execute('CREATE UNIQUE INDEX txns_source ON txns(source, source_ref)');
        await db.execute('CREATE INDEX txns_date ON txns(date)');
        await db.execute('CREATE TABLE budgets(category TEXT PRIMARY KEY, amount REAL NOT NULL)');
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            due_day INTEGER NOT NULL,
            category TEXT NOT NULL,
            last_paid INTEGER
          )''');
        await db.execute('CREATE TABLE rules(merchant TEXT PRIMARY KEY, category TEXT NOT NULL)');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await _upgradeToV2(db);
        await _upgradeToV3(db);
        await _upgradeToV4(db);
        await _upgradeToV5(db);
      },
    );
    return AppDb._(db);
  }

  /// v2: "not an expense" flag and user-created categories.
  static Future<void> _upgradeToV2(Database db) async {
    await db.execute('ALTER TABLE txns ADD COLUMN excluded INTEGER NOT NULL DEFAULT 0');
    await db.execute('''
      CREATE TABLE categories(
        key TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        icon INTEGER NOT NULL,
        color INTEGER NOT NULL,
        income INTEGER NOT NULL DEFAULT 0
      )''');
  }

  /// v3: names the user gave to payees ("raju.k" -> "Raju (plumber)").
  /// v5: categories can count as savings.
  static Future<void> _upgradeToV5(Database db) async {
    await db.execute('ALTER TABLE categories ADD COLUMN saving INTEGER NOT NULL DEFAULT 0');
  }

  /// v4: refunds linked to expenses.
  static Future<void> _upgradeToV4(Database db) async {
    await db.execute('''
      CREATE TABLE refunds(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_id INTEGER NOT NULL,
        income_id INTEGER NOT NULL,
        amount REAL NOT NULL
      )''');
  }

  Future<List<RefundLink>> refunds() async => (await _db.query('refunds')).map(RefundLink.fromMap).toList();

  Future<int> addRefund(RefundLink r) => _db.insert('refunds', r.toMap()..remove('id'));

  Future<void> deleteRefund(int id) => _db.delete('refunds', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteRefundsFor(int txnId) =>
      _db.delete('refunds', where: 'expense_id = ? OR income_id = ?', whereArgs: [txnId, txnId]);

  static Future<void> _upgradeToV3(Database db) async {
    await db.execute('CREATE TABLE aliases(raw TEXT PRIMARY KEY, name TEXT NOT NULL)');
  }

  Future<Map<String, String>> aliases() async {
    final rows = await _db.query('aliases');
    return {for (final r in rows) r['raw'] as String: r['name'] as String};
  }

  Future<void> setAlias(String raw, String name) =>
      _db.insert('aliases', {'raw': raw, 'name': name}, conflictAlgorithm: ConflictAlgorithm.replace);

  // Custom categories
  Future<List<Category>> customCategories() async {
    final rows = await _db.query('categories', orderBy: 'label COLLATE NOCASE');
    return rows.map(customCategoryFromMap).toList();
  }

  Future<void> addCategory(String key, String label, int iconIndex, int colorIndex, bool income, {bool saving = false}) =>
      _db.insert('categories', {
        'key': key,
        'label': label,
        'icon': iconIndex,
        'color': colorIndex,
        'income': income ? 1 : 0,
        'saving': saving ? 1 : 0,
      });

  /// Creates or replaces a category row. For a built-in key this stores the
  /// user's name, icon and colour for it.
  Future<void> saveCategory(String key, String label, int iconIndex, int colorIndex, bool income, {bool saving = false}) =>
      _db.insert(
      'categories',
      {
        'key': key,
        'label': label,
        'icon': iconIndex,
        'color': colorIndex,
        'income': income ? 1 : 0,
        'saving': saving ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace);

  /// Drops the user's changes to a built-in category.
  Future<void> resetCategory(String key) => _db.delete('categories', where: 'key = ?', whereArgs: [key]);

  /// Removes a category and moves its transactions and bills to [fallback].
  Future<void> deleteCategory(String key, String fallback) async {
    await _db.update('txns', {'category': fallback}, where: 'category = ?', whereArgs: [key]);
    await _db.update('bills', {'category': fallback}, where: 'category = ?', whereArgs: [key]);
    await _db.delete('budgets', where: 'category = ?', whereArgs: [key]);
    await _db.delete('rules', where: 'category = ?', whereArgs: [key]);
    await _db.delete('categories', where: 'key = ?', whereArgs: [key]);
  }

  /// Deletes several transactions by id.
  Future<void> deleteTxns(List<int> ids) async {
    if (ids.isEmpty) return;
    await _db.delete('txns', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
  }

  // Transactions
  Future<List<Txn>> allTxns() async {
    final rows = await _db.query('txns', orderBy: 'date DESC');
    return rows.map(Txn.fromMap).toList();
  }

  Future<int> insertTxn(Txn t) => _db.insert('txns', t.toMap()..remove('id'));

  Future<void> insertTxns(List<Txn> list) async {
    final batch = _db.batch();
    for (final t in list) {
      batch.insert('txns', t.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTxn(Txn t) => _db.update('txns', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTxn(int id) => _db.delete('txns', where: 'id = ?', whereArgs: [id]);

  // Budgets ('_total' is the overall monthly budget)
  Future<Map<String, double>> budgets() async {
    final rows = await _db.query('budgets');
    return {for (final r in rows) r['category'] as String: (r['amount'] as num).toDouble()};
  }

  Future<void> setBudget(String category, double amount) async {
    if (amount <= 0) {
      await _db.delete('budgets', where: 'category = ?', whereArgs: [category]);
    } else {
      await _db.insert('budgets', {'category': category, 'amount': amount},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Bills
  Future<List<Bill>> bills() async {
    final rows = await _db.query('bills', orderBy: 'due_day ASC');
    return rows.map(Bill.fromMap).toList();
  }

  Future<void> saveBill(Bill b) async {
    if (b.id == null) {
      await _db.insert('bills', b.toMap()..remove('id'));
    } else {
      await _db.update('bills', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
    }
  }

  Future<void> deleteBill(int id) => _db.delete('bills', where: 'id = ?', whereArgs: [id]);

  // Learned category rules (merchant -> category)
  Future<Map<String, String>> rules() async {
    final rows = await _db.query('rules');
    return {for (final r in rows) r['merchant'] as String: r['category'] as String};
  }

  Future<void> setRule(String merchant, String category) => _db.insert(
      'rules', {'merchant': merchant, 'category': category},
      conflictAlgorithm: ConflictAlgorithm.replace);

  // Settings
  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) =>
      _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> clearAll() async {
    for (final table in ['txns', 'budgets', 'bills', 'rules', 'settings', 'categories', 'aliases', 'refunds']) {
      await _db.delete(table);
    }
  }
}
