import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:deyoun/features/backup/models/backup_metadata.dart';
import 'package:deyoun/features/backup/models/backup_payload.dart';
import 'package:deyoun/features/backup/services/backup_snapshot_service.dart';
import 'package:deyoun/features/customers/models/customer_trust_status.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const uuid = Uuid();
  late String dbPath;
  late Directory tempDir;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taswiyah_backup_test_');
    dbPath = p.join(tempDir.path, 'test_backup.db');

    db = await openDatabase(
      dbPath,
      version: 5,
      onCreate: (db, version) async {
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

  group('Google Drive Backup & Restore Snapshot Tests', () {
    test('BackupMetadata serialization and formatting works properly', () {
      final now = DateTime(2026, 10, 5, 16, 30);
      final meta = BackupMetadata(
        id: 'file_123',
        fileName: 'Taswiyah_Backup_2026-10-05_16-30.taswiyah',
        createdAt: now,
        sizeBytes: 2500000,
        appVersion: '1.0.0',
        schemaVersion: 5,
        tablesCount: {'customers': 10, 'debts': 25, 'payments': 15},
        businessName: 'متجر الأمل',
      );

      final json = meta.toJson();
      final fromJson = BackupMetadata.fromJson(json);

      expect(fromJson.id, 'file_123');
      expect(fromJson.fileName, 'Taswiyah_Backup_2026-10-05_16-30.taswiyah');
      expect(fromJson.formattedSize, '2.38 ميجابايت');
      expect(fromJson.formattedDate, '5 أكتوبر 2026');
      expect(fromJson.formattedTime, '4:30 م');
      expect(fromJson.tablesCount['customers'], 10);
      expect(fromJson.tablesCount['debts'], 25);
    });

    test('Creating compressed snapshot captures full database state and restores accurately', () async {
      // 1. Insert test data
      final custId1 = uuid.v4();
      final custId2 = uuid.v4();
      final debtId1 = uuid.v4();
      final paymentId1 = uuid.v4();

      await db.insert('business_profile', {
        'id': 'profile_1',
        'business_name': 'شركة تسوية للمحاسبة',
        'owner_name': 'وسام',
        'currency': 'ر.ي',
      });

      await db.insert('customers', {
        'id': custId1,
        'name': 'محمد أحمد',
        'primary_phone': '777111222',
        'remaining_balance': 5000.0,
        'trust_status': CustomerTrustStatus.trusted.dbValue,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('customers', {
        'id': custId2,
        'name': 'علي خالد',
        'primary_phone': '777333444',
        'remaining_balance': 3000.0,
        'trust_status': CustomerTrustStatus.untrusted.dbValue,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('debts', {
        'id': debtId1,
        'customer_id': custId1,
        'amount': 5000.0,
        'paid': 1000.0,
        'status': 'partial',
        'notes': 'بضاعة آجلة',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('payments', {
        'id': paymentId1,
        'debt_id': debtId1,
        'customer_id': custId1,
        'amount': 1000.0,
        'notes': 'دفعة نقدية أولى',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Create in-memory snapshot simulating BackupSnapshotService logic
      final tablesRes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
      );

      final Map<String, List<Map<String, dynamic>>> tablesData = {};
      final Map<String, int> tablesCount = {};
      for (var row in tablesRes) {
        final tableName = row['name'].toString();
        final rows = await db.query(tableName);
        tablesData[tableName] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        tablesCount[tableName] = rows.length;
      }

      final meta = BackupMetadata(
        id: 'backup_uuid',
        fileName: 'Taswiyah_Backup_2026-10-05_17-00.taswiyah',
        createdAt: DateTime.now(),
        sizeBytes: 0,
        appVersion: '1.0.0',
        schemaVersion: 5,
        tablesCount: tablesCount,
        businessName: 'شركة تسوية للمحاسبة',
      );

      final payload = BackupPayload(
        metadata: meta,
        tables: tablesData,
        settings: {'currency': 'ر.ي', 'company_name': 'شركة تسوية للمحاسبة'},
      );

      final jsonStr = jsonEncode(payload.toJson());
      final compressedBytes = gzip.encode(utf8.encode(jsonStr));

      expect(compressedBytes.isNotEmpty, isTrue);

      // 3. Clear existing database to simulate new phone or empty state
      await db.delete('payments');
      await db.delete('debts');
      await db.delete('customers');
      await db.delete('business_profile');

      expect((await db.query('customers')).isEmpty, isTrue);
      expect((await db.query('debts')).isEmpty, isTrue);

      // 4. Restore snapshot from compressedBytes
      final decompressedJson = jsonDecode(utf8.decode(gzip.decode(compressedBytes))) as Map<String, dynamic>;
      final restoredPayload = BackupPayload.fromJson(decompressedJson);

      expect(restoredPayload.metadata.appName, 'Taswiyah');
      expect(restoredPayload.metadata.schemaVersion, 5);

      await db.transaction((txn) async {
        await txn.execute('PRAGMA foreign_keys = OFF;');
        for (final entry in restoredPayload.tables.entries) {
          final table = entry.key;
          await txn.delete(table);
          final batch = txn.batch();
          for (final row in entry.value) {
            batch.insert(table, row);
          }
          await batch.commit(noResult: true);
        }
        await txn.execute('PRAGMA foreign_keys = ON;');
      });

      // 5. Verify restored data
      final restoredCustomers = await db.query('customers', orderBy: 'name ASC');
      expect(restoredCustomers.length, 2);
      expect(restoredCustomers.first['name'], 'علي خالد');
      expect(restoredCustomers.first['trust_status'], 'untrusted');
      expect(restoredCustomers.last['name'], 'محمد أحمد');
      expect(restoredCustomers.last['trust_status'], 'trusted');

      final restoredDebts = await db.query('debts');
      expect(restoredDebts.length, 1);
      expect(restoredDebts.first['notes'], 'بضاعة آجلة');
      expect(restoredDebts.first['amount'], 5000.0);

      final restoredPayments = await db.query('payments');
      expect(restoredPayments.length, 1);
      expect(restoredPayments.first['notes'], 'دفعة نقدية أولى');
      expect(restoredPayments.first['amount'], 1000.0);

      final restoredProfile = await db.query('business_profile');
      expect(restoredProfile.length, 1);
      expect(restoredProfile.first['business_name'], 'شركة تسوية للمحاسبة');
    });

    test('Validation rejects corrupt or non-Taswiyah payloads', () async {
      // Empty bytes
      expect(
        () => BackupSnapshotService.instance.restoreSnapshot([]),
        throwsA(isA<FormatException>()),
      );

      // Non-GZip corrupted bytes
      expect(
        () => BackupSnapshotService.instance.restoreSnapshot([1, 2, 3, 4, 5]),
        throwsA(isA<FormatException>()),
      );

      // Non-Taswiyah payload
      final invalidPayload = {
        'metadata': {'appName': 'OtherApp', 'schemaVersion': 5},
        'tables': {'customers': []},
      };
      final invalidBytes = gzip.encode(utf8.encode(jsonEncode(invalidPayload)));
      expect(
        () => BackupSnapshotService.instance.restoreSnapshot(invalidBytes),
        throwsA(isA<FormatException>()),
      );

      // Unsupported schema version
      final futureVersionPayload = {
        'metadata': {'appName': 'Taswiyah', 'schemaVersion': 999},
        'tables': {'customers': []},
      };
      final futureBytes = gzip.encode(utf8.encode(jsonEncode(futureVersionPayload)));
      expect(
        () => BackupSnapshotService.instance.restoreSnapshot(futureBytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
