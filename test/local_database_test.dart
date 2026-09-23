import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  // Setup FFI for running tests locally on desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const uuid = Uuid();

  setUp(() async {
    // Create an in-memory SQLite database using the exact v3 schema
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        // Business Profile
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

        // Customers
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

        // Debts
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

        // Payments
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
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Local-First Customer Operations', () {
    test('Create and Read customer with UUID', () async {
      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'علي محمد أحمد',
        'primary_phone': '777123456',
        'remaining_balance': 0.0,
        'notify_on_debt': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      final result = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(result.isNotEmpty, true);
      expect(result.first['name'], 'علي محمد أحمد');
      expect(result.first['id'], custId);
    });

    test('Update customer details locally', () async {
      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'سامي سالم',
        'primary_phone': '777000111',
        'remaining_balance': 0.0,
      });

      await db.update(
        'customers',
        {'name': 'سامي سالم العولقي', 'primary_phone': '777999888'},
        where: 'id = ?',
        whereArgs: [custId],
      );

      final result = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(result.first['name'], 'سامي سالم العولقي');
      expect(result.first['primary_phone'], '777999888');
    });

    test('Delete customer cascades to debts and payments', () async {
      final custId = uuid.v4();
      final debtId = uuid.v4();
      final paymentId = uuid.v4();

      await db.insert('customers', {'id': custId, 'name': 'خالد', 'primary_phone': '777'});
      await db.insert('debts', {'id': debtId, 'customer_id': custId, 'amount': 1000.0, 'paid': 0.0});
      await db.insert('payments', {'id': paymentId, 'customer_id': custId, 'amount': 500.0});

      // Delete customer
      await db.delete('customers', where: 'id = ?', whereArgs: [custId]);

      final remainingDebts = await db.query('debts', where: 'customer_id = ?', whereArgs: [custId]);
      final remainingPayments = await db.query('payments', where: 'customer_id = ?', whereArgs: [custId]);

      expect(remainingDebts.isEmpty, true);
      expect(remainingPayments.isEmpty, true);
    });
  });

  group('Debts and Atomic FIFO Payment Settlement', () {
    test('Adding multiple debts updates total balance correctly', () async {
      final custId = uuid.v4();
      await db.insert('customers', {'id': custId, 'name': 'جميل', 'primary_phone': '777333222'});

      final debt1 = uuid.v4();
      final debt2 = uuid.v4();

      await db.insert('debts', {
        'id': debt1,
        'customer_id': custId,
        'amount': 5000.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': '2026-01-01T10:00:00',
      });

      await db.insert('debts', {
        'id': debt2,
        'customer_id': custId,
        'amount': 3000.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': '2026-01-02T10:00:00',
      });

      final totalRes = await db.rawQuery(
        'SELECT SUM(amount - paid) as total FROM debts WHERE customer_id = ?',
        [custId],
      );
      final double totalDebt = double.parse(totalRes.first['total'].toString());
      expect(totalDebt, 8000.0);
    });

    test('Payment settles debts using FIFO (First-In First-Out)', () async {
      final custId = uuid.v4();
      await db.insert('customers', {'id': custId, 'name': 'أحمد حسن', 'primary_phone': '771122334'});

      final debt1Id = uuid.v4();
      final debt2Id = uuid.v4();

      // Debt 1: 5000 (Older)
      await db.insert('debts', {
        'id': debt1Id,
        'customer_id': custId,
        'amount': 5000.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': '2026-01-01T10:00:00',
      });

      // Debt 2: 3000 (Newer)
      await db.insert('debts', {
        'id': debt2Id,
        'customer_id': custId,
        'amount': 3000.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': '2026-01-02T10:00:00',
      });

      // Customer pays 6000
      // Expected result:
      // Debt 1 (5000): Paid = 5000, Status = 'paid'
      // Debt 2 (3000): Paid = 1000, Status = 'partial', Remaining on debt = 2000
      // Total remaining balance = 2000
      const double paymentAmount = 6000.0;

      await db.transaction((txn) async {
        final debts = await txn.query(
          'debts',
          where: 'customer_id = ? AND status != ?',
          whereArgs: [custId, 'paid'],
          orderBy: 'created_at ASC',
        );

        double remainingPayment = paymentAmount;

        for (var debt in debts) {
          if (remainingPayment <= 0) break;

          final id = debt['id'].toString();
          final amount = double.parse(debt['amount'].toString());
          final paid = double.parse((debt['paid'] ?? 0).toString());
          final remainingOnDebt = amount - paid;

          if (remainingOnDebt > 0) {
            final double toApply = remainingPayment >= remainingOnDebt ? remainingOnDebt : remainingPayment;
            final double newPaid = paid + toApply;
            final String newStatus = (newPaid >= amount) ? 'paid' : 'partial';

            await txn.update(
              'debts',
              {'paid': newPaid, 'status': newStatus},
              where: 'id = ?',
              whereArgs: [id],
            );

            remainingPayment -= toApply;
          }
        }

        await txn.insert('payments', {
          'id': uuid.v4(),
          'customer_id': custId,
          'amount': paymentAmount,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      // Verify Debt 1
      final resDebt1 = await db.query('debts', where: 'id = ?', whereArgs: [debt1Id]);
      expect(resDebt1.first['paid'], 5000.0);
      expect(resDebt1.first['status'], 'paid');

      // Verify Debt 2
      final resDebt2 = await db.query('debts', where: 'id = ?', whereArgs: [debt2Id]);
      expect(resDebt2.first['paid'], 1000.0);
      expect(resDebt2.first['status'], 'partial');

      // Verify Total Remaining
      final balRes = await db.rawQuery(
        'SELECT SUM(amount - paid) as balance FROM debts WHERE customer_id = ?',
        [custId],
      );
      final double finalBalance = double.parse(balRes.first['balance'].toString());
      expect(finalBalance, 2000.0);
    });

    test('Data integrity rules: paid <= amount and balance >= 0', () async {
      final custId = uuid.v4();
      final debtId = uuid.v4();
      await db.insert('customers', {'id': custId, 'name': 'سعيد', 'primary_phone': '778899001'});
      await db.insert('debts', {
        'id': debtId,
        'customer_id': custId,
        'amount': 2000.0,
        'paid': 0.0,
        'status': 'unpaid',
      });

      // Apply exact payment of 2000
      await db.update('debts', {'paid': 2000.0, 'status': 'paid'}, where: 'id = ?', whereArgs: [debtId]);

      final check = await db.query('debts', where: 'id = ?', whereArgs: [debtId]);
      final double paid = double.parse(check.first['paid'].toString());
      final double amount = double.parse(check.first['amount'].toString());
      
      expect(paid <= amount, true);
      expect(amount - paid >= 0, true);
    });
  });

  group('Local Business Profile (Standalone Multi-Tenancy)', () {
    test('Save and Retrieve Business Profile without server tenant', () async {
      final profId = uuid.v4();
      await db.insert('business_profile', {
        'id': profId,
        'business_name': 'مؤسسة النور التجارية',
        'owner_name': 'محمد عبد الله',
        'phone': '777888999',
        'address': 'صنعاء - شارع الستين',
        'currency': 'ر.ي',
        'auto_remind_day': 25,
        'avatar_icon': 'store',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final result = await db.query('business_profile', limit: 1);
      expect(result.isNotEmpty, true);
      expect(result.first['business_name'], 'مؤسسة النور التجارية');
      expect(result.first['owner_name'], 'محمد عبد الله');
      expect(result.first['currency'], 'ر.ي');
      expect(result.first['auto_remind_day'], 25);
    });
  });
}
