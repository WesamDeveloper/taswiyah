import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;

  LocalDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('deyoun_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add payments table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        tenant_id INTEGER,
        branch_id INTEGER,
        debt_id INTEGER,
        customer_id INTEGER,
        amount REAL NOT NULL,
        created_at TEXT,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    // Customers Table
    await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY,
      tenant_id INTEGER,
      branch_id INTEGER,
      name TEXT NOT NULL,
      primary_phone TEXT NOT NULL,
      secondary_phone TEXT,
      address TEXT,
      email TEXT,
      remaining_balance REAL DEFAULT 0,
      notify_on_debt INTEGER DEFAULT 0,
      reminder_frequency_days INTEGER,
      next_reminder_date TEXT,
      is_synced INTEGER DEFAULT 1
    )
    ''');

    // Debts Table
    await db.execute('''
    CREATE TABLE debts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER,
      tenant_id INTEGER,
      branch_id INTEGER,
      customer_id INTEGER,
      amount REAL NOT NULL,
      paid REAL DEFAULT 0,
      status TEXT DEFAULT 'unpaid',
      due_date TEXT,
      notes TEXT,
      created_at TEXT,
      is_synced INTEGER DEFAULT 1,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
    )
    ''');

    // Payments Table
    await db.execute('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER,
      tenant_id INTEGER,
      branch_id INTEGER,
      debt_id INTEGER,
      customer_id INTEGER,
      amount REAL NOT NULL,
      created_at TEXT,
      is_synced INTEGER DEFAULT 1,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
    )
    ''');

    // Sync Queue Table (for tracking operations made offline)
    // operation: 'add_customer', 'add_debt', 'add_payment', 'update_customer'
    await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');
  }

  // --- Customers ---
  Future<void> saveCustomer(Map<String, dynamic> customer, {bool isSynced = true}) async {
    final db = await instance.database;
    await db.insert('customers', {
      'id': customer['id'],
      'tenant_id': customer['tenant_id'],
      'branch_id': customer['branch_id'],
      'name': customer['name'],
      'primary_phone': customer['primary_phone'],
      'secondary_phone': customer['secondary_phone'],
      'address': customer['address'],
      'email': customer['email'],
      'remaining_balance': customer['remaining_balance'] ?? 0,
      'notify_on_debt': (customer['notify_on_debt'] == 1 || customer['notify_on_debt'] == true) ? 1 : 0,
      'reminder_frequency_days': customer['reminder_frequency_days'],
      'next_reminder_date': customer['next_reminder_date'],
      'is_synced': isSynced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await instance.database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final db = await instance.database;
    return await db.query(
      'customers',
      where: 'name LIKE ? OR primary_phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getCustomer(int id) async {
    final db = await instance.database;
    final results = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> deleteCustomer(int id) async {
    final db = await instance.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    // Cascade delete is defined on the foreign key for debts, 
    // but sqflite needs PRAGMA foreign_keys = ON to respect it automatically.
    // So we'll explicitly delete debts as well just in case.
    await db.delete('debts', where: 'customer_id = ?', whereArgs: [id]);
    await db.delete('payments', where: 'customer_id = ?', whereArgs: [id]);
  }

  Future<void> clearSyncedCustomers() async {
    final db = await instance.database;
    await db.delete('customers', where: 'is_synced = 1');
  }

  // --- Debts ---
  Future<void> saveDebt(Map<String, dynamic> debt, {bool isSynced = true}) async {
    final db = await instance.database;
    // If it's from local DB, it has remote_id. If from server, it has id which is the remote_id.
    final remoteId = debt['remote_id'] ?? debt['id'];
    
    // Check if debt with this remote_id already exists
    final existing = await db.query('debts', where: 'remote_id = ?', whereArgs: [remoteId]);
    
    final data = {
      'remote_id': remoteId,
      'tenant_id': debt['tenant_id'],
      'branch_id': debt['branch_id'],
      'customer_id': debt['customer_id'],
      'amount': debt['amount'],
      'paid': debt['paid'] ?? 0,
      'status': debt['status'] ?? 'unpaid',
      'due_date': debt['due_date'],
      'notes': debt['notes'],
      'created_at': debt['created_at'],
      'is_synced': isSynced ? 1 : 0,
    };

    if (existing.isNotEmpty) {
      await db.update('debts', data, where: 'remote_id = ?', whereArgs: [remoteId]);
    } else {
      await db.insert('debts', data);
    }
  }

  Future<void> deleteDebtByRemoteId(int remoteId) async {
    final db = await instance.database;
    await db.delete('debts', where: 'remote_id = ?', whereArgs: [remoteId]);
  }

  Future<void> clearAllSyncedDebts() async {
    final db = await instance.database;
    await db.delete('debts', where: 'is_synced = 1');
  }

  Future<void> clearSyncedCustomerDebts(int customerId) async {
    final db = await instance.database;
    await db.delete('debts', where: 'customer_id = ? AND is_synced = 1', whereArgs: [customerId]);
  }

  Future<List<Map<String, dynamic>>> getCustomerDebts(int customerId) async {
    final db = await instance.database;
    return await db.query('debts', where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getAllDebts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT d.*, c.name as customer_name 
      FROM debts d 
      LEFT JOIN customers c ON d.customer_id = c.id 
      ORDER BY d.created_at DESC
    ''');
  }

  // --- Payments ---
  Future<void> savePayment(Map<String, dynamic> payment, {bool isSynced = true}) async {
    final db = await instance.database;
    final remoteId = payment['remote_id'] ?? payment['id'];
    
    final existing = await db.query('payments', where: 'remote_id = ?', whereArgs: [remoteId]);
    
    // Some payments from backend might not have customer_id directly (they have debt_id).
    // We should ensure customer_id is stored if possible, or derive it.
    // If it's passed from the app, it will have customer_id.
    int? customerId = payment['customer_id'];
    if (customerId == null && payment['debt_id'] != null) {
      final debtRes = await db.query('debts', where: 'remote_id = ?', whereArgs: [payment['debt_id']]);
      if (debtRes.isNotEmpty) {
        customerId = debtRes.first['customer_id'] as int?;
      }
    }

    final data = {
      'remote_id': remoteId,
      'tenant_id': payment['tenant_id'],
      'branch_id': payment['branch_id'],
      'debt_id': payment['debt_id'],
      'customer_id': customerId,
      'amount': payment['amount'],
      'created_at': payment['created_at'],
      'is_synced': isSynced ? 1 : 0,
    };

    if (existing.isNotEmpty) {
      await db.update('payments', data, where: 'remote_id = ?', whereArgs: [remoteId]);
    } else {
      await db.insert('payments', data);
    }
  }

  Future<void> deletePaymentByRemoteId(int remoteId) async {
    final db = await instance.database;
    await db.delete('payments', where: 'remote_id = ?', whereArgs: [remoteId]);
  }

  Future<void> clearAllSyncedPayments() async {
    final db = await instance.database;
    await db.delete('payments', where: 'is_synced = 1');
  }

  Future<void> clearSyncedCustomerPayments(int customerId) async {
    final db = await instance.database;
    await db.delete('payments', where: 'customer_id = ? AND is_synced = 1', whereArgs: [customerId]);
  }

  Future<List<Map<String, dynamic>>> getCustomerPayments(int customerId) async {
    final db = await instance.database;
    return await db.query('payments', where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getAllPayments() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as customer_name 
      FROM payments p 
      LEFT JOIN customers c ON p.customer_id = c.id 
      ORDER BY p.created_at DESC
    ''');
  }

  // --- Sync Queue ---
  Future<void> addToSyncQueue(String operation, String payload) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'operation': operation,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<Map<String, dynamic>?> getSyncQueueItem(int id) async {
    final db = await instance.database;
    final results = await db.query('sync_queue', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> replaceCustomerTempId(int tempId, int newId) async {
    final db = await instance.database;
    
    // 1. Update primary key and sync status in customers table
    await db.update('customers', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [tempId]);

    // 2. Update foreign keys in local tables
    await db.update('debts', {'customer_id': newId}, where: 'customer_id = ?', whereArgs: [tempId]);
    await db.update('payments', {'customer_id': newId}, where: 'customer_id = ?', whereArgs: [tempId]);
    
    // 2. Update payloads in sync_queue
    final queue = await db.query('sync_queue');
    for (var item in queue) {
      if (item['payload'] != null) {
        String payloadStr = item['payload'] as String;
        // Simple string replacement could be risky, but since it's JSON, parsing is safer
        try {
          final Map<String, dynamic> payload = jsonDecode(payloadStr);
          bool modified = false;
          
          if (payload['customer_id'] == tempId) {
            payload['customer_id'] = newId;
            modified = true;
          }
          if (payload['id'] == tempId && item['operation'] == 'update_customer') {
            payload['id'] = newId;
            modified = true;
          }
          
          if (modified) {
            await db.update(
              'sync_queue', 
              {'payload': jsonEncode(payload)}, 
              where: 'id = ?', 
              whereArgs: [item['id']]
            );
          }
        } catch (e) {
          // ignore parsing error
        }
      }
    }
  }

  Future<void> replaceDebtTempId(int tempId, int newId) async {
    final db = await instance.database;
    
    // 1. Update primary key and sync status in debts table
    await db.update('debts', {'remote_id': newId, 'is_synced': 1}, where: 'remote_id = ?', whereArgs: [tempId]);

    // 2. Update foreign keys in local tables
    await db.update('payments', {'debt_id': newId}, where: 'debt_id = ?', whereArgs: [tempId]);
    
    // 2. Update payloads in sync_queue
    final queue = await db.query('sync_queue');
    for (var item in queue) {
      if (item['payload'] != null) {
        String payloadStr = item['payload'] as String;
        try {
          final Map<String, dynamic> payload = jsonDecode(payloadStr);
          bool modified = false;
          
          if (payload['debt_id'] == tempId) {
            payload['debt_id'] = newId;
            modified = true;
          }
          
          if (modified) {
            await db.update(
              'sync_queue', 
              {'payload': jsonEncode(payload)}, 
              where: 'id = ?', 
              whereArgs: [item['id']]
            );
          }
        } catch (e) {
          // ignore
        }
      }
    }
  }

  Future<void> markPaymentAsSynced(int id) async {
    final db = await instance.database;
    await db.update('payments', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markCustomerAsSynced(int id) async {
    final db = await instance.database;
    await db.update('customers', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeFromSyncQueue(int id) async {
    final db = await instance.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('customers');
    await db.delete('debts');
    await db.delete('payments');
    await db.delete('sync_queue');
  }
}
