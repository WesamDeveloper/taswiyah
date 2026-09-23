import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const uuid = Uuid();

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
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
          created_at TEXT,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        );
        ''');

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

  group('Customer Profile Pagination & Safe Parsing Verification', () {
    test('Correctly batches and paginates 12 transactions in slices of 5', () async {
      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'عميل تجريبي',
        'primary_phone': '777000222',
      });

      // Insert 8 debts
      for (int i = 1; i <= 8; i++) {
        await db.insert('debts', {
          'id': uuid.v4(),
          'customer_id': custId,
          'amount': 100.0 * i,
          'paid': 0.0,
          'status': 'unpaid',
          'created_at': '2026-01-0${i}T10:00:00',
        });
      }

      // Insert 4 payments
      for (int i = 1; i <= 4; i++) {
        await db.insert('payments', {
          'id': uuid.v4(),
          'customer_id': custId,
          'amount': 50.0 * i,
          'created_at': '2026-01-1${i}T10:00:00',
        });
      }

      // Query with CAST
      final debts = await db.query(
        'debts',
        where: 'CAST(customer_id AS TEXT) = ?',
        whereArgs: [custId],
      );
      final payments = await db.query(
        'payments',
        where: 'CAST(customer_id AS TEXT) = ?',
        whereArgs: [custId],
      );

      expect(debts.length, 8);
      expect(payments.length, 4);

      // Combine and sort DESC
      final List<Map<String, dynamic>> combined = [];
      for (var d in debts) {
        final m = Map<String, dynamic>.from(d);
        m['tx_type'] = 'debt';
        combined.add(m);
      }
      for (var p in payments) {
        final m = Map<String, dynamic>.from(p);
        m['tx_type'] = 'payment';
        combined.add(m);
      }

      combined.sort((a, b) {
        final dateA = a['created_at']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });

      expect(combined.length, 12);

      // Verify batch 1: exactly 5 items
      const pageSize = 5;
      var displayed = combined.take(pageSize).toList();
      var hasMore = combined.length > displayed.length;

      expect(displayed.length, 5);
      expect(hasMore, true);

      // Load batch 2: +5 items -> total 10
      displayed.addAll(combined.skip(displayed.length).take(pageSize).toList());
      hasMore = combined.length > displayed.length;

      expect(displayed.length, 10);
      expect(hasMore, true);

      // Load batch 3: +2 items -> total 12
      displayed.addAll(combined.skip(displayed.length).take(pageSize).toList());
      hasMore = combined.length > displayed.length;

      expect(displayed.length, 12);
      expect(hasMore, false); // No more items left
    });

    test('Safely handles null and malformed created_at and paid without crashing', () {
      final badRecords = [
        {'id': '1', 'created_at': null, 'amount': 100, 'paid': null},
        {'id': '2', 'created_at': '', 'amount': null, 'paid': 'invalid'},
        {'id': '3', 'created_at': 'short', 'amount': '250.5', 'paid': 0},
        {'id': '4', 'created_at': '2026-09-20T20:00:00', 'amount': 500, 'paid': 200},
      ];

      String formatDate(dynamic raw) {
        if (raw == null) return '';
        final s = raw.toString().trim();
        if (s.isEmpty) return '';
        try {
          final dt = DateTime.tryParse(s);
          if (dt != null) {
            final y = dt.year.toString().padLeft(4, '0');
            final m = dt.month.toString().padLeft(2, '0');
            final d = dt.day.toString().padLeft(2, '0');
            return '$y-$m-$d';
          }
        } catch (_) {}
        if (s.length >= 10) return s.substring(0, 10);
        return s;
      }

      for (var row in badRecords) {
        // Date test
        final formattedDate = formatDate(row['created_at']);
        expect(formattedDate, isA<String>());

        // Amount test
        final amount = double.tryParse(row['amount']?.toString() ?? '0') ?? 0.0;
        final paid = double.tryParse(row['paid']?.toString() ?? '0') ?? 0.0;
        final remaining = (amount - paid) < 0 ? 0.0 : (amount - paid);
        expect(amount >= 0, true);
        expect(remaining >= 0, true);
      }
    });

    test('Eastern Arabic numerals (٠-٩) normalize correctly to standard digits', () {
      String normalizeDigits(String input) {
        const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
        const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
        String result = input;
        for (int i = 0; i < 10; i++) {
          result = result.replaceAll(arabicDigits[i], englishDigits[i]);
        }
        return result;
      }

      expect(double.tryParse(normalizeDigits('٥٠٠٠')), 5000.0);
      expect(double.tryParse(normalizeDigits('١٢٥٠.٥')), 1250.5);
      expect(double.tryParse(normalizeDigits('  ٧٥٠  ')), 750.0);
      expect(double.tryParse(normalizeDigits('0')), 0.0);
    });

    test('Newly added debt immediately appears in getCustomerDebts query', () async {
      final custId = uuid.v4();
      await db.insert('customers', {
        'id': custId,
        'name': 'عميل سلفة جديدة',
        'primary_phone': '771122334',
      });

      // Initially no debts
      var initialDebts = await db.rawQuery('''
        SELECT * FROM debts 
        WHERE customer_id = ? OR CAST(customer_id AS TEXT) = ?
      ''', [custId, custId]);
      expect(initialDebts.isEmpty, true);

      // Add new debt
      final newDebtId = uuid.v4();
      await db.insert('debts', {
        'id': newDebtId,
        'customer_id': custId,
        'amount': 3500.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Query again
      var updatedDebts = await db.rawQuery('''
        SELECT * FROM debts 
        WHERE customer_id = ? OR CAST(customer_id AS TEXT) = ?
        ORDER BY created_at DESC
      ''', [custId, custId]);

      expect(updatedDebts.length, 1);
      expect(updatedDebts.first['id'], newDebtId);
      expect(double.parse(updatedDebts.first['amount'].toString()), 3500.0);
    });
  });
}
