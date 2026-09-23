import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;
  static const Uuid _uuid = Uuid();

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
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Business Profile Table (Local Multi-Tenant / Business Identity)
    await db.execute('''
    CREATE TABLE business_profile (
      id TEXT PRIMARY KEY,
      business_name TEXT NOT NULL,
      owner_name TEXT,
      phone TEXT,
      address TEXT,
      currency TEXT DEFAULT 'ر.ي',
      auto_remind_day INTEGER,
      avatar_icon TEXT DEFAULT 'person',
      created_at TEXT,
      updated_at TEXT
    );
    ''');

    // 2. Customers Table
    await db.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      primary_phone TEXT NOT NULL,
      secondary_phone TEXT,
      address TEXT,
      email TEXT,
      remaining_balance REAL DEFAULT 0,
      notify_on_debt INTEGER DEFAULT 0,
      reminder_frequency_days INTEGER,
      next_reminder_date TEXT,
      created_at TEXT
    );
    ''');

    // 3. Debts Table
    await db.execute('''
    CREATE TABLE debts (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      amount REAL NOT NULL,
      paid REAL DEFAULT 0,
      status TEXT DEFAULT 'unpaid',
      due_date TEXT,
      notes TEXT,
      created_at TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
    );
    ''');

    // 4. Payments Table
    await db.execute('''
    CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      debt_id TEXT,
      customer_id TEXT NOT NULL,
      amount REAL NOT NULL,
      created_at TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
      FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE SET NULL
    );
    ''');

    // 5. Performance Indexes
    await _createIndexes(db);
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers (name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers (primary_phone);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_debts_customer ON debts (customer_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_debts_status ON debts (status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_customer ON payments (customer_id);');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
      );
      ''');
    }

    if (oldVersion < 3) {
      // Safe Migration to v3:
      // Remove backend/sync columns (tenant_id, branch_id, remote_id, is_synced)
      // Convert IDs to TEXT (UUID compatible) while preserving existing data
      // Add foreign keys and indexes, and create business_profile table

      // 1. Migrate Customers
      await db.execute('''
      CREATE TABLE IF NOT EXISTS customers_v3 (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        primary_phone TEXT NOT NULL,
        secondary_phone TEXT,
        address TEXT,
        email TEXT,
        remaining_balance REAL DEFAULT 0,
        notify_on_debt INTEGER DEFAULT 0,
        reminder_frequency_days INTEGER,
        next_reminder_date TEXT,
        created_at TEXT
      );
      ''');

      try {
        await db.execute('''
        INSERT INTO customers_v3 (id, name, primary_phone, secondary_phone, address, email, remaining_balance, notify_on_debt, reminder_frequency_days, next_reminder_date, created_at)
        SELECT CAST(id AS TEXT), name, primary_phone, secondary_phone, address, email, 
               COALESCE(remaining_balance, 0), 
               COALESCE(notify_on_debt, 0), 
               reminder_frequency_days, next_reminder_date, 
               datetime('now')
        FROM customers;
        ''');
        await db.execute('DROP TABLE customers;');
      } catch (e) {
        // In case table was empty or structure differed
      }
      await db.execute('ALTER TABLE customers_v3 RENAME TO customers;');

      // 2. Migrate Debts
      await db.execute('''
      CREATE TABLE IF NOT EXISTS debts_v3 (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        amount REAL NOT NULL,
        paid REAL DEFAULT 0,
        status TEXT DEFAULT 'unpaid',
        due_date TEXT,
        notes TEXT,
        created_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      );
      ''');

      try {
        await db.execute('''
        INSERT INTO debts_v3 (id, customer_id, amount, paid, status, due_date, notes, created_at)
        SELECT CAST(COALESCE(remote_id, id) AS TEXT), 
               CAST(customer_id AS TEXT), 
               amount, 
               COALESCE(paid, 0), 
               COALESCE(status, 'unpaid'), 
               due_date, notes, 
               COALESCE(created_at, datetime('now'))
        FROM debts;
        ''');
        await db.execute('DROP TABLE debts;');
      } catch (e) {
        // ignore
      }
      await db.execute('ALTER TABLE debts_v3 RENAME TO debts;');

      // 3. Migrate Payments
      await db.execute('''
      CREATE TABLE IF NOT EXISTS payments_v3 (
        id TEXT PRIMARY KEY,
        debt_id TEXT,
        customer_id TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE SET NULL
      );
      ''');

      try {
        await db.execute('''
        INSERT INTO payments_v3 (id, debt_id, customer_id, amount, created_at)
        SELECT CAST(COALESCE(remote_id, id) AS TEXT), 
               CASE WHEN debt_id IS NOT NULL THEN CAST(debt_id AS TEXT) ELSE NULL END, 
               CAST(customer_id AS TEXT), 
               amount, 
               COALESCE(created_at, datetime('now'))
        FROM payments;
        ''');
        await db.execute('DROP TABLE payments;');
      } catch (e) {
        // ignore
      }
      await db.execute('ALTER TABLE payments_v3 RENAME TO payments;');

      // 4. Create Business Profile Table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS business_profile (
        id TEXT PRIMARY KEY,
        business_name TEXT NOT NULL,
        owner_name TEXT,
        phone TEXT,
        address TEXT,
        currency TEXT DEFAULT 'ر.ي',
        auto_remind_day INTEGER,
        avatar_icon TEXT DEFAULT 'person',
        created_at TEXT,
        updated_at TEXT
      );
      ''');

      // 5. Drop sync_queue safely (No longer needed in Local-First)
      try {
        await db.execute('DROP TABLE IF EXISTS sync_queue;');
      } catch (e) {
        // ignore
      }

      // 6. Create Indexes
      await _createIndexes(db);
    }
  }

  // ==========================================
  // --- Business Profile Methods ---
  // ==========================================
  Future<Map<String, dynamic>?> getBusinessProfile() async {
    final db = await instance.database;
    final res = await db.query('business_profile', limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<void> saveBusinessProfile({
    required String businessName,
    String? ownerName,
    String? phone,
    String? address,
    String currency = 'ر.ي',
    int? autoRemindDay,
    String avatarIcon = 'person',
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final existing = await getBusinessProfile();

    if (existing != null) {
      await db.update(
        'business_profile',
        {
          'business_name': businessName,
          'owner_name': ownerName ?? existing['owner_name'],
          'phone': phone ?? existing['phone'],
          'address': address ?? existing['address'],
          'currency': currency,
          'auto_remind_day': autoRemindDay ?? existing['auto_remind_day'],
          'avatar_icon': avatarIcon,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      await db.insert('business_profile', {
        'id': _uuid.v4(),
        'business_name': businessName,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
        'currency': currency,
        'auto_remind_day': autoRemindDay,
        'avatar_icon': avatarIcon,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ==========================================
  // --- Customers Methods ---
  // ==========================================
  Future<String> saveCustomer(Map<String, dynamic> customer) async {
    final db = await instance.database;
    final String id = customer['id']?.toString() ?? _uuid.v4();

    final data = {
      'id': id,
      'name': customer['name'],
      'primary_phone': customer['primary_phone'],
      'secondary_phone': customer['secondary_phone'],
      'address': customer['address'],
      'email': customer['email'],
      'remaining_balance': customer['remaining_balance'] ?? 0,
      'notify_on_debt': (customer['notify_on_debt'] == 1 || customer['notify_on_debt'] == true) ? 1 : 0,
      'reminder_frequency_days': customer['reminder_frequency_days'],
      'next_reminder_date': customer['next_reminder_date'],
      'created_at': customer['created_at'] ?? DateTime.now().toIso8601String(),
    };

    await db.insert('customers', data, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.*, 
        COALESCE((SELECT SUM(amount - paid) FROM debts WHERE customer_id = c.id), 0) as remaining_balance
      FROM customers c 
      ORDER BY c.name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.*, 
        COALESCE((SELECT SUM(amount - paid) FROM debts WHERE customer_id = c.id), 0) as remaining_balance
      FROM customers c 
      WHERE c.name LIKE ? OR c.primary_phone LIKE ?
      ORDER BY c.name ASC
    ''', ['%$query%', '%$query%']);
  }

  Future<Map<String, dynamic>?> getCustomer(dynamic id) async {
    final db = await instance.database;
    final idStr = id.toString().trim();
    final idInt = int.tryParse(idStr);

    final results = await db.rawQuery('''
      SELECT c.*, 
        COALESCE((SELECT SUM(amount - paid) FROM debts WHERE customer_id = c.id OR CAST(customer_id AS TEXT) = CAST(c.id AS TEXT)), 0) as remaining_balance
      FROM customers c 
      WHERE c.id = ? OR CAST(c.id AS TEXT) = ? ${idInt != null ? 'OR c.id = ?' : ''}
    ''', idInt != null ? [idStr, idStr, idInt] : [idStr, idStr]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> deleteCustomer(dynamic id) async {
    final db = await instance.database;
    final idStr = id.toString();
    await db.transaction((txn) async {
      await txn.delete('payments', where: 'customer_id = ?', whereArgs: [idStr]);
      await txn.delete('debts', where: 'customer_id = ?', whereArgs: [idStr]);
      await txn.delete('customers', where: 'id = ?', whereArgs: [idStr]);
    });
  }

  // ==========================================
  // --- Debts Methods ---
  // ==========================================
  Future<String> saveDebt(Map<String, dynamic> debt) async {
    final db = await instance.database;
    final String debtId = debt['id']?.toString() ?? _uuid.v4();
    final String customerId = debt['customer_id'].toString();
    final double amount = double.parse(debt['amount'].toString());
    final double paid = double.parse((debt['paid'] ?? 0).toString());
    final String status = debt['status'] ?? (paid >= amount ? 'paid' : (paid > 0 ? 'partial' : 'unpaid'));

    final data = {
      'id': debtId,
      'customer_id': customerId,
      'amount': amount,
      'paid': paid,
      'status': status,
      'due_date': debt['due_date'],
      'notes': debt['notes'],
      'created_at': debt['created_at'] ?? DateTime.now().toIso8601String(),
    };

    await db.transaction((txn) async {
      await txn.insert('debts', data, conflictAlgorithm: ConflictAlgorithm.replace);
      // Automatically refresh customer remaining balance
      await _refreshCustomerBalance(txn, customerId);
    });

    return debtId;
  }

  Future<void> deleteDebt(dynamic id) async {
    final db = await instance.database;
    final debtId = id.toString();
    await db.transaction((txn) async {
      final res = await txn.query('debts', columns: ['customer_id'], where: 'id = ?', whereArgs: [debtId]);
      if (res.isNotEmpty) {
        final customerId = res.first['customer_id'].toString();
        await txn.delete('payments', where: 'debt_id = ?', whereArgs: [debtId]);
        await txn.delete('debts', where: 'id = ?', whereArgs: [debtId]);
        await _refreshCustomerBalance(txn, customerId);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCustomerDebts(dynamic customerId) async {
    final db = await instance.database;
    final idStr = customerId.toString().trim();
    final idInt = int.tryParse(idStr);

    if (idInt != null) {
      return await db.rawQuery('''
        SELECT * FROM debts 
        WHERE customer_id = ? OR customer_id = ? OR CAST(customer_id AS TEXT) = ?
        ORDER BY created_at DESC
      ''', [idStr, idInt, idStr]);
    } else {
      return await db.rawQuery('''
        SELECT * FROM debts 
        WHERE customer_id = ? OR CAST(customer_id AS TEXT) = ?
        ORDER BY created_at DESC
      ''', [idStr, idStr]);
    }
  }

  Future<List<Map<String, dynamic>>> getAllDebts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT d.*, c.name as customer_name 
      FROM debts d 
      LEFT JOIN customers c ON (d.customer_id = c.id OR CAST(d.customer_id AS TEXT) = CAST(c.id AS TEXT)) 
      ORDER BY d.created_at DESC
    ''');
  }

  // ==========================================
  // --- Payments & FIFO Settlement Engine ---
  // ==========================================
  /// Applies customer payment atomically using FIFO (First-In, First-Out) rule.
  /// Oldest unpaid debts are liquidated first.
  Future<String> recordPaymentTransaction({
    required dynamic customerId,
    required double amount,
    String? specificDebtId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('مبلغ الدفعة يجب أن يكون أكبر من الصفر');
    }

    final db = await instance.database;
    final String custId = customerId.toString();
    final int? idInt = int.tryParse(custId);
    final String paymentId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Verify customer exists
      final custRes = await txn.rawQuery(
        'SELECT * FROM customers WHERE id = ? OR CAST(id AS TEXT) = ? ${idInt != null ? 'OR id = ?' : ''}',
        idInt != null ? [custId, custId, idInt] : [custId, custId],
      );
      if (custRes.isEmpty) {
        throw StateError('العميل غير موجود في قاعدة البيانات');
      }

      // 2. Fetch debts sorted ASCENDING by created_at (FIFO)
      final debts = await txn.rawQuery('''
        SELECT * FROM debts 
        WHERE (customer_id = ? OR CAST(customer_id AS TEXT) = ? ${idInt != null ? 'OR customer_id = ?' : ''})
          AND status != 'paid'
        ORDER BY created_at ASC
      ''', idInt != null ? [custId, custId, idInt] : [custId, custId]);

      double remainingPayment = amount;

      for (var debt in debts) {
        if (remainingPayment <= 0) break;

        final debtId = debt['id'].toString();
        final debtAmount = double.parse(debt['amount'].toString());
        final debtPaid = double.parse((debt['paid'] ?? 0).toString());
        final debtRemaining = debtAmount - debtPaid;

        if (debtRemaining > 0) {
          final double amountToApply = remainingPayment >= debtRemaining ? debtRemaining : remainingPayment;
          final double newPaid = debtPaid + amountToApply;
          final String newStatus = (newPaid >= debtAmount) ? 'paid' : 'partial';

          await txn.update(
            'debts',
            {'paid': newPaid, 'status': newStatus},
            where: 'id = ?',
            whereArgs: [debtId],
          );

          remainingPayment -= amountToApply;
        }
      }

      // 3. Record payment in payments table
      await txn.insert('payments', {
        'id': paymentId,
        'debt_id': specificDebtId?.toString(),
        'customer_id': custId,
        'amount': amount,
        'created_at': now,
      });

      // 4. Update customer remaining balance
      await _refreshCustomerBalance(txn, custId);
    });

    return paymentId;
  }

  Future<void> _refreshCustomerBalance(DatabaseExecutor txn, String customerId) async {
    final idStr = customerId.toString().trim();
    final idInt = int.tryParse(idStr);

    final balanceRes = await txn.rawQuery('''
      SELECT COALESCE(SUM(amount - paid), 0) as balance 
      FROM debts 
      WHERE customer_id = ? OR CAST(customer_id AS TEXT) = ? ${idInt != null ? 'OR customer_id = ?' : ''}
    ''', idInt != null ? [idStr, idStr, idInt] : [idStr, idStr]);

    final double balance = (balanceRes.isNotEmpty && balanceRes.first['balance'] != null)
        ? double.parse(balanceRes.first['balance'].toString())
        : 0.0;

    await txn.rawUpdate('''
      UPDATE customers 
      SET remaining_balance = ? 
      WHERE id = ? OR CAST(id AS TEXT) = ? ${idInt != null ? 'OR id = ?' : ''}
    ''', idInt != null ? [balance < 0 ? 0.0 : balance, idStr, idStr, idInt] : [balance < 0 ? 0.0 : balance, idStr, idStr]);
  }

  Future<List<Map<String, dynamic>>> getCustomerPayments(dynamic customerId) async {
    final db = await instance.database;
    final idStr = customerId.toString().trim();
    final idInt = int.tryParse(idStr);

    if (idInt != null) {
      return await db.rawQuery('''
        SELECT * FROM payments 
        WHERE customer_id = ? OR customer_id = ? OR CAST(customer_id AS TEXT) = ?
        ORDER BY created_at DESC
      ''', [idStr, idInt, idStr]);
    } else {
      return await db.rawQuery('''
        SELECT * FROM payments 
        WHERE customer_id = ? OR CAST(customer_id AS TEXT) = ?
        ORDER BY created_at DESC
      ''', [idStr, idStr]);
    }
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

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('debts');
      await txn.delete('customers');
      await txn.delete('business_profile');
    });
  }
}
