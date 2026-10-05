import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:deyoun/features/debts/models/overdue_period.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const uuid = Uuid();
  late String dbPath;
  late Directory tempDir;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taswiyah_overdue_test_');
    dbPath = p.join(tempDir.path, 'test_taswiyah_overdue.db');
    db = await openDatabase(
      dbPath,
      version: 5,
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
          notes TEXT,
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
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<List<Map<String, dynamic>>> calculateOverdue(int thresholdDays) async {
    final now = DateTime.now();

    final rawCustomers = await db.rawQuery('''
      SELECT c.*, 
        COALESCE((SELECT SUM(amount - paid) FROM debts WHERE customer_id = c.id OR CAST(customer_id AS TEXT) = CAST(c.id AS TEXT)), 0) as remaining_balance,
        (SELECT MAX(created_at) FROM payments WHERE customer_id = c.id OR CAST(customer_id AS TEXT) = CAST(c.id AS TEXT)) as last_payment_date,
        (SELECT MIN(created_at) FROM debts WHERE (customer_id = c.id OR CAST(customer_id AS TEXT) = CAST(c.id AS TEXT)) AND status != 'paid') as oldest_unpaid_debt_date,
        (SELECT MIN(due_date) FROM debts WHERE (customer_id = c.id OR CAST(customer_id AS TEXT) = CAST(c.id AS TEXT)) AND status != 'paid' AND due_date IS NOT NULL) as earliest_due_date
      FROM customers c
      ORDER BY c.name ASC
    ''');

    final List<Map<String, dynamic>> overdueList = [];

    for (var row in rawCustomers) {
      final remaining = double.tryParse((row['remaining_balance'] ?? 0).toString()) ?? 0.0;
      if (remaining <= 0) continue;

      final lastPaymentStr = row['last_payment_date']?.toString();
      final oldestDebtStr = row['oldest_unpaid_debt_date']?.toString();
      final earliestDueDateStr = row['earliest_due_date']?.toString();
      final customerCreatedStr = row['created_at']?.toString();

      DateTime? referenceDate;

      if (lastPaymentStr != null && lastPaymentStr.isNotEmpty) {
        referenceDate = DateTime.tryParse(lastPaymentStr);
      } else if (oldestDebtStr != null && oldestDebtStr.isNotEmpty) {
        referenceDate = DateTime.tryParse(oldestDebtStr);
      } else if (customerCreatedStr != null && customerCreatedStr.isNotEmpty) {
        referenceDate = DateTime.tryParse(customerCreatedStr);
      }

      if (earliestDueDateStr != null && earliestDueDateStr.isNotEmpty) {
        final dueDate = DateTime.tryParse(earliestDueDateStr);
        if (dueDate != null) {
          if (referenceDate == null || dueDate.isBefore(referenceDate)) {
            referenceDate = dueDate;
          }
        }
      }

      referenceDate ??= now;

      final daysWithoutPayment = now.difference(referenceDate).inDays;

      if (daysWithoutPayment >= thresholdDays) {
        final custMap = Map<String, dynamic>.from(row);
        custMap['remaining_balance'] = remaining;
        custMap['days_overdue'] = daysWithoutPayment;
        custMap['last_payment_date'] = lastPaymentStr;
        custMap['reference_date'] = referenceDate.toIso8601String();
        overdueList.add(custMap);
      }
    }

    overdueList.sort((a, b) {
      final daysA = a['days_overdue'] as int? ?? 0;
      final daysB = b['days_overdue'] as int? ?? 0;
      return daysB.compareTo(daysA);
    });

    return overdueList;
  }

  group('Overdue Debts Calculation Tests', () {
    test('OverduePeriod helper returns correct titles and labels', () {
      expect(OverduePeriod.defaultDays, 30);
      expect(OverduePeriod.getShortLabelForDays(7), 'أسبوع');
      expect(OverduePeriod.getShortLabelForDays(30), 'شهر');
      expect(OverduePeriod.getShortLabelForDays(365), 'سنة');
      expect(OverduePeriod.getShortLabelForDays(45), '45 يوم');

      expect(OverduePeriod.getLabelForDays(30), 'أكثر من شهر (30 يوماً)');
      expect(OverduePeriod.getLabelForDays(7), 'أكثر من أسبوع (7 أيام)');
      expect(OverduePeriod.getLabelForDays(45), 'أكثر من 45 يوماً');
    });

    test('Customer with recent debt (5 days ago) is not overdue under 30 days threshold', () async {
      final now = DateTime.now();
      final custId = uuid.v4();

      await db.insert('customers', {
        'id': custId,
        'name': 'عميل جديد',
        'primary_phone': '777000111',
        'remaining_balance': 500.0,
        'created_at': now.subtract(const Duration(days: 5)).toIso8601String(),
      });

      await db.insert('debts', {
        'id': uuid.v4(),
        'customer_id': custId,
        'amount': 500.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': now.subtract(const Duration(days: 5)).toIso8601String(),
      });

      final overdue30 = await calculateOverdue(30);
      expect(overdue30.isEmpty, isTrue);

      // But under 3 days threshold, they are overdue
      final overdue3 = await calculateOverdue(3);
      expect(overdue3.length, 1);
      expect(overdue3.first['id'], custId);
    });

    test('Customer with debt from 40 days ago and no payment is overdue under 30 days', () async {
      final now = DateTime.now();
      final custId = uuid.v4();

      await db.insert('customers', {
        'id': custId,
        'name': 'عميل متأخر',
        'primary_phone': '777222333',
        'remaining_balance': 1500.0,
        'created_at': now.subtract(const Duration(days: 40)).toIso8601String(),
      });

      await db.insert('debts', {
        'id': uuid.v4(),
        'customer_id': custId,
        'amount': 1500.0,
        'paid': 0.0,
        'status': 'unpaid',
        'created_at': now.subtract(const Duration(days: 40)).toIso8601String(),
      });

      final overdue30 = await calculateOverdue(30);
      expect(overdue30.length, 1);
      expect(overdue30.first['id'], custId);
      expect(overdue30.first['days_overdue'], greaterThanOrEqualTo(40));

      // Under 60 days threshold (شهرين), they are not yet overdue
      final overdue60 = await calculateOverdue(60);
      expect(overdue60.isEmpty, isTrue);
    });

    test('Customer with old debt who made a payment 10 days ago is NOT overdue under 30 days', () async {
      final now = DateTime.now();
      final custId = uuid.v4();

      await db.insert('customers', {
        'id': custId,
        'name': 'عميل مسدد حديثا',
        'primary_phone': '777444555',
        'remaining_balance': 800.0,
        'created_at': now.subtract(const Duration(days: 60)).toIso8601String(),
      });

      await db.insert('debts', {
        'id': uuid.v4(),
        'customer_id': custId,
        'amount': 1000.0,
        'paid': 200.0,
        'status': 'partial',
        'created_at': now.subtract(const Duration(days: 60)).toIso8601String(),
      });

      // Made payment 10 days ago
      await db.insert('payments', {
        'id': uuid.v4(),
        'customer_id': custId,
        'amount': 200.0,
        'created_at': now.subtract(const Duration(days: 10)).toIso8601String(),
      });

      final overdue30 = await calculateOverdue(30);
      expect(overdue30.isEmpty, isTrue);

      // But under 7 days (أسبوع), they have not paid for 10 days, so overdue
      final overdue7 = await calculateOverdue(7);
      expect(overdue7.length, 1);
      expect(overdue7.first['id'], custId);
    });

    test('Customer who fully paid balance (0 remaining) is never overdue', () async {
      final now = DateTime.now();
      final custId = uuid.v4();

      await db.insert('customers', {
        'id': custId,
        'name': 'عميل مخلص دينه',
        'primary_phone': '777888999',
        'remaining_balance': 0.0,
        'created_at': now.subtract(const Duration(days: 100)).toIso8601String(),
      });

      await db.insert('debts', {
        'id': uuid.v4(),
        'customer_id': custId,
        'amount': 1000.0,
        'paid': 1000.0,
        'status': 'paid',
        'created_at': now.subtract(const Duration(days: 100)).toIso8601String(),
      });

      final overdue7 = await calculateOverdue(7);
      final overdue30 = await calculateOverdue(30);
      expect(overdue7.isEmpty, isTrue);
      expect(overdue30.isEmpty, isTrue);
    });
  });
}
