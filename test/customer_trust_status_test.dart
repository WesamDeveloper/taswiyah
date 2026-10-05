import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:deyoun/features/customers/models/customer_trust_status.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const uuid = Uuid();
  late String dbPath;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taswiyah_test_');
    dbPath = p.join(tempDir.path, 'test_taswiyah.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Customer Trust Status & Filtering Test Suite', () {
    test('Case 1: Newly created customer has trustStatus = unknown and appears only in All filter', () async {
      final db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
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
            trust_status TEXT DEFAULT 'unknown',
            created_at TEXT
          );
          ''');
          await db.execute('''
          CREATE TABLE debts (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            amount REAL NOT NULL,
            paid REAL DEFAULT 0,
            status TEXT DEFAULT 'unpaid',
            due_date TEXT,
            notes TEXT,
            created_at TEXT
          );
          ''');
        },
      );

      final custId = uuid.v4();
      final newCustomer = {
        'id': custId,
        'name': 'محمد أحمد',
        'primary_phone': '777111222',
        'trust_status': CustomerTrustStatus.unknown.dbValue,
        'created_at': DateTime.now().toIso8601String(),
      };

      await db.insert('customers', newCustomer);

      // Verify status in DB
      final customerInDb = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(customerInDb.first['trust_status'], 'unknown');

      // Filter: "الكل" (all)
      final allList = await db.rawQuery('SELECT * FROM customers');
      expect(allList.any((c) => c['id'] == custId), isTrue);

      // Filter: "موثوق" (trusted)
      final trustedList = await db.rawQuery("SELECT * FROM customers WHERE trust_status = 'trusted'");
      expect(trustedList.any((c) => c['id'] == custId), isFalse);

      // Filter: "غير موثوق" (untrusted)
      final untrustedList = await db.rawQuery("SELECT * FROM customers WHERE trust_status = 'untrusted'");
      expect(untrustedList.any((c) => c['id'] == custId), isFalse);

      await db.close();
    });

    test('Case 2: Changing customer to trusted shows them in All and Trusted, but not Untrusted', () async {
      final db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
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
            trust_status TEXT DEFAULT 'unknown',
            created_at TEXT
          );
          ''');
        },
      );

      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'محمد أحمد',
        'primary_phone': '777111222',
        'trust_status': 'unknown',
      });

      // Update to trusted
      await db.update('customers', {'trust_status': 'trusted'}, where: 'id = ?', whereArgs: [custId]);

      // Verify: shows in "الكل"
      final all = await db.rawQuery('SELECT * FROM customers');
      expect(all.any((c) => c['id'] == custId), isTrue);

      // Verify: shows in "موثوق"
      final trusted = await db.rawQuery("SELECT * FROM customers WHERE trust_status = 'trusted'");
      expect(trusted.any((c) => c['id'] == custId), isTrue);

      // Verify: does NOT show in "غير موثوق"
      final untrusted = await db.rawQuery("SELECT * FROM customers WHERE trust_status = 'untrusted'");
      expect(untrusted.any((c) => c['id'] == custId), isFalse);

      await db.close();
    });

    test('Case 3: Changing customer to untrusted shows them in All and Untrusted, but not Trusted', () async {
      final db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
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
            trust_status TEXT DEFAULT 'unknown',
            created_at TEXT
          );
          ''');
        },
      );

      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'محمد أحمد',
        'primary_phone': '777111222',
        'trust_status': 'trusted',
      });

      // Update to untrusted
      await db.update('customers', {'trust_status': 'untrusted'}, where: 'id = ?', whereArgs: [custId]);

      // Verify: shows in "الكل"
      final all = await db.rawQuery('SELECT * FROM customers');
      expect(all.any((c) => c['id'] == custId), isTrue);

      // Verify: does NOT show in "موثوق"
      final trusted = await db.rawQuery("SELECT * FROM customers WHERE trust_status = 'trusted'");
      expect(trusted.any((c) => c['id'] == custId), isFalse);

      // Verify: shows in "غير موثوق"
      final untrusted = await db.rawQuery("SELECT * FROM customers WHERE trust_status = 'untrusted'");
      expect(untrusted.any((c) => c['id'] == custId), isTrue);

      await db.close();
    });

    test('Case 4: Closing and reopening database preserves customer trust status', () async {
      final custId = uuid.v4();

      // Open, insert, and close
      var db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
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
            trust_status TEXT DEFAULT 'unknown',
            created_at TEXT
          );
          ''');
        },
      );

      await db.insert('customers', {
        'id': custId,
        'name': 'خالد السعيد',
        'primary_phone': '777888999',
        'trust_status': 'trusted',
      });
      await db.close();

      // Reopen database from the same file path (simulating app restart)
      db = await openDatabase(dbPath, version: 4);

      final reloaded = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(reloaded.isNotEmpty, isTrue);
      expect(reloaded.first['name'], 'خالد السعيد');
      expect(reloaded.first['trust_status'], 'trusted');

      await db.close();
    });

    test('Case 5: Migration preserves existing customer data and assigns trust_status = unknown', () async {
      // 1. Create database at version 3 with OLD schema (no trust_status column)
      var db = await openDatabase(
        dbPath,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            primary_phone TEXT NOT NULL,
            secondary_phone TEXT,
            address TEXT,
            email TEXT,
            remaining_balance REAL DEFAULT 1500,
            notify_on_debt INTEGER DEFAULT 0,
            reminder_frequency_days INTEGER,
            next_reminder_date TEXT,
            created_at TEXT
          );
          ''');
        },
      );

      // Insert existing old customers
      final cust1Id = uuid.v4();
      final cust2Id = uuid.v4();
      await db.insert('customers', {
        'id': cust1Id,
        'name': 'عميل قديم ١',
        'primary_phone': '777000001',
        'address': 'صنعاء',
        'remaining_balance': 5000.0,
      });
      await db.insert('customers', {
        'id': cust2Id,
        'name': 'عميل قديم ٢',
        'primary_phone': '777000002',
        'address': 'عدن',
        'remaining_balance': 2500.0,
      });

      await db.close();

      // 2. Open database at version 4 with migration logic
      db = await openDatabase(
        dbPath,
        version: 4,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 4) {
            final columns = await db.rawQuery('PRAGMA table_info(customers);');
            final hasTrustStatus = columns.any((col) => col['name'] == 'trust_status');
            if (!hasTrustStatus) {
              await db.execute("ALTER TABLE customers ADD COLUMN trust_status TEXT DEFAULT 'unknown';");
            }
            await db.execute("UPDATE customers SET trust_status = 'unknown' WHERE trust_status IS NULL OR trust_status = '';");
          }
        },
      );

      // Verify old customer data is 100% intact
      final migrated1 = await db.query('customers', where: 'id = ?', whereArgs: [cust1Id]);
      expect(migrated1.isNotEmpty, isTrue);
      expect(migrated1.first['name'], 'عميل قديم ١');
      expect(migrated1.first['primary_phone'], '777000001');
      expect(migrated1.first['address'], 'صنعاء');
      expect(migrated1.first['remaining_balance'], 5000.0);
      expect(migrated1.first['trust_status'], 'unknown');

      final migrated2 = await db.query('customers', where: 'id = ?', whereArgs: [cust2Id]);
      expect(migrated2.isNotEmpty, isTrue);
      expect(migrated2.first['name'], 'عميل قديم ٢');
      expect(migrated2.first['primary_phone'], '777000002');
      expect(migrated2.first['address'], 'عدن');
      expect(migrated2.first['remaining_balance'], 2500.0);
      expect(migrated2.first['trust_status'], 'unknown');

      await db.close();
    });

    test('Case 6: Search AND Filter work together simultaneously', () async {
      final db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
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
            trust_status TEXT DEFAULT 'unknown',
            created_at TEXT
          );
          ''');
          await db.execute('''
          CREATE TABLE debts (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            amount REAL NOT NULL,
            paid REAL DEFAULT 0,
            status TEXT DEFAULT 'unpaid',
            due_date TEXT,
            notes TEXT,
            created_at TEXT
          );
          ''');
        },
      );

      // Insert 4 customers with various names and trust statuses
      // 1. Mohammed (trusted)
      final c1 = uuid.v4();
      await db.insert('customers', {'id': c1, 'name': 'محمد عبد الله', 'primary_phone': '771', 'trust_status': 'trusted'});

      // 2. Mohammed (untrusted)
      final c2 = uuid.v4();
      await db.insert('customers', {'id': c2, 'name': 'محمد سعيد', 'primary_phone': '772', 'trust_status': 'untrusted'});

      // 3. Mohammed (unknown)
      final c3 = uuid.v4();
      await db.insert('customers', {'id': c3, 'name': 'محمد صالح', 'primary_phone': '773', 'trust_status': 'unknown'});

      // 4. Ali (trusted)
      final c4 = uuid.v4();
      await db.insert('customers', {'id': c4, 'name': 'علي ناصر', 'primary_phone': '774', 'trust_status': 'trusted'});

      // Helper function matching LocalDbService.searchCustomers
      Future<List<Map<String, dynamic>>> searchWithFilter(String query, String? trustStatus) async {
        if (trustStatus != null && trustStatus.isNotEmpty && trustStatus != 'all') {
          return await db.rawQuery('''
            SELECT c.*, 
              COALESCE((SELECT SUM(amount - paid) FROM debts WHERE customer_id = c.id), 0) as remaining_balance
            FROM customers c 
            WHERE (c.name LIKE ? OR c.primary_phone LIKE ?) AND c.trust_status = ?
            ORDER BY c.name ASC
          ''', ['%$query%', '%$query%', trustStatus]);
        }
        return await db.rawQuery('''
          SELECT c.*, 
            COALESCE((SELECT SUM(amount - paid) FROM debts WHERE customer_id = c.id), 0) as remaining_balance
          FROM customers c 
          WHERE c.name LIKE ? OR c.primary_phone LIKE ?
          ORDER BY c.name ASC
        ''', ['%$query%', '%$query%']);
      }

      // Query: Search "محمد" AND Filter "trusted"
      final trustedMohammed = await searchWithFilter('محمد', 'trusted');
      expect(trustedMohammed.length, 1);
      expect(trustedMohammed.first['id'], c1);
      expect(trustedMohammed.first['name'], 'محمد عبد الله');

      // Query: Search "محمد" AND Filter "untrusted"
      final untrustedMohammed = await searchWithFilter('محمد', 'untrusted');
      expect(untrustedMohammed.length, 1);
      expect(untrustedMohammed.first['id'], c2);
      expect(untrustedMohammed.first['name'], 'محمد سعيد');

      // Query: Search "محمد" AND Filter "all" (or null)
      final allMohammed = await searchWithFilter('محمد', null);
      expect(allMohammed.length, 3);

      // Query: Search "علي" AND Filter "untrusted"
      final untrustedAli = await searchWithFilter('علي', 'untrusted');
      expect(untrustedAli.isEmpty, isTrue);

      await db.close();
    });

    test('Case 7: Updating customer trust status in map does not throw unmodifiable map error', () async {
      final db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
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
            trust_status TEXT DEFAULT 'unknown',
            created_at TEXT
          );
          ''');
          await db.execute('''
          CREATE TABLE debts (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            amount REAL NOT NULL,
            paid REAL DEFAULT 0,
            status TEXT DEFAULT 'unpaid',
            due_date TEXT,
            notes TEXT,
            created_at TEXT
          );
          ''');
        },
      );

      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'عميل تجريبي',
        'primary_phone': '777000333',
        'trust_status': 'unknown',
      });

      // Query customer row from DB
      final queryResult = await db.rawQuery('SELECT * FROM customers WHERE id = ?', [custId]);
      expect(queryResult.isNotEmpty, isTrue);

      // Verify that copying to mutable map allows modifying trust_status safely
      final mutableCustomer = Map<String, dynamic>.from(queryResult.first);
      expect(() {
        mutableCustomer['trust_status'] = CustomerTrustStatus.trusted.dbValue;
      }, returnsNormally);

      expect(mutableCustomer['trust_status'], 'trusted');

      // Update in DB
      await db.update('customers', {'trust_status': 'trusted'}, where: 'id = ?', whereArgs: [custId]);
      final updatedDb = await db.rawQuery('SELECT trust_status FROM customers WHERE id = ?', [custId]);
      expect(updatedDb.first['trust_status'], 'trusted');

      await db.close();
    });

    test('Case 8: Recording payment with notes persists notes and retrieves them correctly', () async {
      final db = await openDatabase(
        dbPath,
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            primary_phone TEXT NOT NULL,
            remaining_balance REAL DEFAULT 0,
            trust_status TEXT DEFAULT 'unknown'
          );
          ''');
          await db.execute('''
          CREATE TABLE payments (
            id TEXT PRIMARY KEY,
            debt_id TEXT,
            customer_id TEXT NOT NULL,
            amount REAL NOT NULL,
            notes TEXT,
            created_at TEXT
          );
          ''');
        },
      );

      final custId = uuid.v4();
      final paymentId = uuid.v4();

      await db.insert('customers', {
        'id': custId,
        'name': 'عميل دفعة',
        'primary_phone': '777444555',
        'remaining_balance': 1000.0,
      });

      // Insert payment with notes
      await db.insert('payments', {
        'id': paymentId,
        'customer_id': custId,
        'amount': 500.0,
        'notes': 'تسديد نقدي من المحل',
        'created_at': DateTime.now().toIso8601String(),
      });

      final payments = await db.query('payments', where: 'customer_id = ?', whereArgs: [custId]);
      expect(payments.length, 1);
      expect(payments.first['amount'], 500.0);
      expect(payments.first['notes'], 'تسديد نقدي من المحل');

      await db.close();
    });

    test('Case 9: SMS URI does not contain + symbols for spaces', () {
      const cleanPhone = '777123456';
      const message = 'تذكير رصيد مستحق\n\nمرحباً محمد';

      // Method A: Uri constructor
      final uriA = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: {'body': message},
      );
      print('Uri constructor: ${uriA.toString()}');

      // Method B: Uri.encodeComponent
      final encoded = Uri.encodeComponent(message);
      final uriB = Uri.parse('sms:$cleanPhone?body=$encoded');
      print('Uri.parse with encodeComponent: ${uriB.toString()}');

      expect(uriA.toString().contains('+'), isTrue); // Proves Uri constructor adds '+'
      expect(uriB.toString().contains('+'), isFalse); // Proves encodeComponent does NOT add '+'
    });
  });
}

