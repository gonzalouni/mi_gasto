import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const int backupVersion = 4;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'mi_gasto.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        // El saldo de cada cuenta no se guarda: se calcula sumando movimientos.
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            initial_balance REAL NOT NULL DEFAULT 0,
            currency TEXT NOT NULL DEFAULT 'PEN'
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon TEXT NOT NULL,
            color INTEGER NOT NULL,
            type TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            account_id TEXT NOT NULL REFERENCES accounts (id),
            category_id TEXT NOT NULL REFERENCES categories (id),
            date INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            to_account_id TEXT REFERENCES accounts (id)
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_transactions_date ON transactions (date)');
        await db.execute(
            'CREATE INDEX idx_transactions_account ON transactions (account_id)');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            id TEXT PRIMARY KEY,
            category_id TEXT NOT NULL,
            amount REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE recurring (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            account_id TEXT NOT NULL,
            category_id TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            frequency TEXT NOT NULL,
            next_due INTEGER NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN to_account_id TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budgets (
              id TEXT PRIMARY KEY,
              category_id TEXT NOT NULL,
              amount REAL NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS recurring (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              account_id TEXT NOT NULL,
              category_id TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              frequency TEXT NOT NULL,
              next_due INTEGER NOT NULL,
              active INTEGER NOT NULL DEFAULT 1
            )
          ''');
        }
        // Idempotente: agrega categorías nuevas sin tocar las existentes.
        await _seed(db);
      },
    );
  }

  Future<void> _seed(Database db) async {
    const categories = [
      {'id': 'cat_comida', 'name': 'Comida', 'icon': 'foodTray', 'color': 0xFFE57373, 'type': 'expense'},
      {'id': 'cat_transporte', 'name': 'Transporte', 'icon': 'car', 'color': 0xFF64B5F6, 'type': 'expense'},
      {'id': 'cat_hogar', 'name': 'Hogar', 'icon': 'home', 'color': 0xFFFFB74D, 'type': 'expense'},
      {'id': 'cat_salud', 'name': 'Salud', 'icon': 'heartPulse', 'color': 0xFF4DB6AC, 'type': 'expense'},
      {'id': 'cat_entretenimiento', 'name': 'Entretenimiento', 'icon': 'game', 'color': 0xFFBA68C8, 'type': 'expense'},
      {'id': 'cat_compras', 'name': 'Compras', 'icon': 'shoppingBag', 'color': 0xFFF06292, 'type': 'expense'},
      {'id': 'cat_servicios', 'name': 'Servicios', 'icon': 'bolt', 'color': 0xFFFFD54F, 'type': 'expense'},
      {'id': 'cat_educacion', 'name': 'Educación', 'icon': 'book', 'color': 0xFF7986CB, 'type': 'expense'},
      {'id': 'cat_viajes', 'name': 'Viajes', 'icon': 'plane', 'color': 0xFF4DD0E1, 'type': 'expense'},
      {'id': 'cat_otros_gastos', 'name': 'Otros', 'icon': 'moreCircle', 'color': 0xFF90A4AE, 'type': 'expense'},
      {'id': 'cat_sueldo', 'name': 'Sueldo', 'icon': 'briefcase', 'color': 0xFF81C784, 'type': 'income'},
      {'id': 'cat_freelance', 'name': 'Freelance', 'icon': 'laptop', 'color': 0xFF64B5F6, 'type': 'income'},
      {'id': 'cat_ventas', 'name': 'Ventas', 'icon': 'shop', 'color': 0xFFFFB74D, 'type': 'income'},
      {'id': 'cat_otros_ingresos', 'name': 'Otros ingresos', 'icon': 'addCircle', 'color': 0xFF90A4AE, 'type': 'income'},
      // Categoría fija de las transferencias entre cuentas; no se muestra en
      // los selectores porque su tipo es 'transfer'.
      {'id': 'cat_transferencia', 'name': 'Transferencia', 'icon': 'arrowSwapHorizontal', 'color': 0xFF90A4AE, 'type': 'transfer'},
    ];
    const accounts = [
      {'id': 'acc_efectivo', 'name': 'Efectivo', 'type': 'cash', 'initial_balance': 0.0, 'currency': 'PEN'},
      {'id': 'acc_banco', 'name': 'Banco', 'type': 'bank', 'initial_balance': 0.0, 'currency': 'PEN'},
      {'id': 'acc_billetera', 'name': 'Billetera digital', 'type': 'wallet', 'initial_balance': 0.0, 'currency': 'PEN'},
    ];
    for (final row in categories) {
      await db.insert('categories', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final row in accounts) {
      await db.insert('accounts', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Categorías -------------------------------------------------------------

  Future<List<TxCategory>> getCategories() async {
    final rows = await (await database)
        .query('categories', orderBy: 'type, name');
    return rows.map(TxCategory.fromMap).toList();
  }

  Future<void> insertCategory(TxCategory category) async {
    await (await database).insert('categories', category.toMap());
  }

  Future<void> updateCategory(TxCategory category) async {
    await (await database).update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    await (await database).delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countTransactionsForCategory(String id) async {
    final rows = await (await database).rawQuery(
      'SELECT COUNT(*) AS count FROM transactions WHERE category_id = ?',
      [id],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // Cuentas ----------------------------------------------------------------

  Future<List<Account>> getAccounts() async {
    final rows = await (await database).query('accounts', orderBy: 'name');
    return rows.map(Account.fromMap).toList();
  }

  Future<void> insertAccount(Account account) async {
    await (await database).insert('accounts', account.toMap());
  }

  Future<void> updateAccount(Account account) async {
    await (await database).update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> deleteAccount(String id) async {
    await (await database).delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countTransactionsForAccount(String id) async {
    final rows = await (await database).rawQuery(
      'SELECT COUNT(*) AS count FROM transactions WHERE account_id = ?',
      [id],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // Movimientos ------------------------------------------------------------

  Future<List<AppTransaction>> getTransactions() async {
    final rows =
        await (await database).query('transactions', orderBy: 'date DESC');
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<void> insertTransaction(AppTransaction transaction) async {
    await (await database).insert('transactions', transaction.toMap());
  }

  Future<void> updateTransaction(AppTransaction transaction) async {
    await (await database).update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    await (await database)
        .delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Ajustes ----------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final rows = await (await database)
        .query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await (await database).insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Presupuestos ------------------------------------------------------------

  Future<List<Budget>> getBudgets() async {
    final rows = await (await database).query('budgets', orderBy: 'category_id');
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> insertBudget(Budget budget) async {
    await (await database).insert('budgets', budget.toMap());
  }

  Future<void> updateBudget(Budget budget) async {
    await (await database).update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<void> deleteBudget(String id) async {
    await (await database).delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Recurrentes -------------------------------------------------------------

  Future<List<RecurringRule>> getRecurringRules() async {
    final rows = await (await database)
        .query('recurring', orderBy: 'next_due');
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<void> insertRecurringRule(RecurringRule rule) async {
    await (await database).insert('recurring', rule.toMap());
  }

  Future<void> updateRecurringRule(RecurringRule rule) async {
    await (await database).update(
      'recurring',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<void> deleteRecurringRule(String id) async {
    await (await database).delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  // Respaldo ---------------------------------------------------------------

  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    final settingsRows = await db.query('settings');
    return {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': (await db.query('accounts'))
          .map((row) => Account.fromMap(row).toMap())
          .toList(),
      'categories': (await db.query('categories'))
          .map((row) => TxCategory.fromMap(row).toMap())
          .toList(),
      'transactions': (await db.query('transactions', orderBy: 'date'))
          .map((row) => AppTransaction.fromMap(row).toMap())
          .toList(),
      'budgets': (await db.query('budgets'))
          .map((row) => Budget.fromMap(row).toMap())
          .toList(),
      'recurring': (await db.query('recurring'))
          .map((row) => RecurringRule.fromMap(row).toMap())
          .toList(),
      'settings': {
        for (final row in settingsRows)
          row['key'] as String: row['value'] as String,
      },
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('budgets');
      await txn.delete('recurring');
      await txn.delete('settings');

      for (final row in (data['accounts'] as List).cast<Map<String, dynamic>>()) {
        await txn.insert('accounts', Account.fromMap(row).toMap());
      }
      for (final row
          in (data['categories'] as List).cast<Map<String, dynamic>>()) {
        await txn.insert('categories', TxCategory.fromMap(row).toMap());
      }
      for (final row
          in (data['transactions'] as List).cast<Map<String, dynamic>>()) {
        await txn.insert('transactions', AppTransaction.fromMap(row).toMap());
      }
      // 'budgets' y 'recurring' son opcionales para aceptar respaldos antiguos.
      final budgetRows = data['budgets'];
      if (budgetRows is List) {
        for (final row in budgetRows.cast<Map<String, dynamic>>()) {
          await txn.insert('budgets', Budget.fromMap(row).toMap());
        }
      }
      final recurringRows = data['recurring'];
      if (recurringRows is List) {
        for (final row in recurringRows.cast<Map<String, dynamic>>()) {
          await txn.insert('recurring', RecurringRule.fromMap(row).toMap());
        }
      }
      final settings =
          (data['settings'] as Map<String, dynamic>? ?? const {});
      for (final entry in settings.entries) {
        await txn.insert('settings', {'key': entry.key, 'value': entry.value});
      }
    });
  }
}
