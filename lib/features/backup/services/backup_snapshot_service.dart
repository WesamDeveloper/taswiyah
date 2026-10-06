import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_db_service.dart';
import '../models/backup_metadata.dart';
import '../models/backup_payload.dart';

class BackupSnapshotService {
  static final BackupSnapshotService instance = BackupSnapshotService._();
  BackupSnapshotService._();

  static const String currentAppVersion = '1.0.0';
  static const int currentSchemaVersion = 5;
  static const Uuid _uuid = Uuid();

  /// Captures a complete snapshot of all SQLite tables and user settings,
  /// compresses it with GZip, and returns the binary payload and metadata.
  Future<({List<int> bytes, BackupMetadata metadata})> createSnapshotBytes() async {
    final db = await LocalDbService.instance.database;

    // 1. Discover all user tables dynamically
    final tablesRes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
    );

    final Map<String, List<Map<String, dynamic>>> tablesData = {};
    final Map<String, int> tablesCount = {};

    for (var row in tablesRes) {
      final tableName = row['name']?.toString();
      if (tableName == null || tableName.isEmpty) continue;

      final rows = await db.query(tableName);
      final cleanRows = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      tablesData[tableName] = cleanRows;
      tablesCount[tableName] = cleanRows.length;
    }

    // 2. Capture user settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> settingsData = {
      'user_name': prefs.getString('user_name'),
      'company_name': prefs.getString('company_name'),
      'phone': prefs.getString('phone'),
      'address': prefs.getString('address'),
      'currency': prefs.getString('currency') ?? 'ر.ي',
      'auto_remind_day': prefs.getInt('auto_remind_day'),
      'avatar_icon': prefs.getString('avatar_icon'),
      'overdue_threshold_days': prefs.getInt('overdue_threshold_days') ?? 30,
    };

    // Business name for metadata
    String? businessName = prefs.getString('company_name');
    if (businessName == null || businessName.isEmpty) {
      final profile = await LocalDbService.instance.getBusinessProfile();
      businessName = profile?['business_name'];
    }

    final backupId = _uuid.v4();
    final now = DateTime.now();

    // Standard filename: Taswiyah_Backup_YYYY-MM-DD_HH-mm.taswiyah
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'Taswiyah_Backup_${dateStr}_$timeStr.taswiyah';

    // 3. Temporary metadata for payload
    var meta = BackupMetadata(
      id: backupId,
      fileName: fileName,
      createdAt: now,
      sizeBytes: 0,
      appVersion: currentAppVersion,
      schemaVersion: currentSchemaVersion,
      tablesCount: tablesCount,
      businessName: businessName,
    );

    final payload = BackupPayload(
      metadata: meta,
      tables: tablesData,
      settings: settingsData,
    );

    // 4. Encode JSON and compress with GZip
    final jsonString = jsonEncode(payload.toJson());
    final uncompressedBytes = utf8.encode(jsonString);
    final compressedBytes = gzip.encode(uncompressedBytes);

    // Update with final compressed size
    meta = BackupMetadata(
      id: backupId,
      fileName: fileName,
      createdAt: now,
      sizeBytes: compressedBytes.length,
      appVersion: currentAppVersion,
      schemaVersion: currentSchemaVersion,
      tablesCount: tablesCount,
      businessName: businessName,
    );

    return (bytes: compressedBytes, metadata: meta);
  }

  /// Takes an in-memory safety snapshot of current SQLite tables and settings
  Future<BackupPayload> _takeSafetySnapshot() async {
    final db = await LocalDbService.instance.database;

    final tablesRes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
    );

    final Map<String, List<Map<String, dynamic>>> tablesData = {};
    for (var row in tablesRes) {
      final tableName = row['name']?.toString();
      if (tableName == null || tableName.isEmpty) continue;
      final rows = await db.query(tableName);
      tablesData[tableName] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    }

    final prefs = await SharedPreferences.getInstance();
    final settingsData = {
      'user_name': prefs.getString('user_name'),
      'company_name': prefs.getString('company_name'),
      'currency': prefs.getString('currency'),
      'overdue_threshold_days': prefs.getInt('overdue_threshold_days'),
    };

    return BackupPayload(
      metadata: BackupMetadata(
        id: 'safety_local',
        fileName: 'safety_backup',
        createdAt: DateTime.now(),
        sizeBytes: 0,
        appVersion: currentAppVersion,
        schemaVersion: currentSchemaVersion,
      ),
      tables: tablesData,
      settings: settingsData,
    );
  }

  /// Restores a safety snapshot if the restore process failed
  Future<void> _rollbackSafetySnapshot(BackupPayload safety) async {
    try {
      final db = await LocalDbService.instance.database;
      await db.transaction((txn) async {
        await txn.execute('PRAGMA foreign_keys = OFF;');
        for (final entry in safety.tables.entries) {
          final table = entry.key;
          await txn.delete(table);
          final batch = txn.batch();
          for (final row in entry.value) {
            batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
        await txn.execute('PRAGMA foreign_keys = ON;');
      });
    } catch (e) {
      debugPrint('Fatal error rolling back safety snapshot: $e');
    }
  }

  /// Validates and securely restores a compressed backup payload.
  /// Automatically creates a safety snapshot before replacement and rolls back on failure.
  Future<BackupMetadata> restoreSnapshot(List<int> compressedBytes) async {
    if (compressedBytes.isEmpty) {
      throw const FormatException('ملف النسخة الاحتياطية فارغ');
    }

    // 1. Decompress and parse
    final String jsonString;
    try {
      final decompressedBytes = gzip.decode(compressedBytes);
      jsonString = utf8.decode(decompressedBytes);
    } catch (e) {
      throw const FormatException('الملف تالف أو ليس بصيغة نسخة احتياطية صالحة لتطبيق Taswiyah');
    }

    final dynamic parsedJson;
    try {
      parsedJson = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('تعذر فك ترميز بيانات النسخة الاحتياطية (تنسيق JSON غير صالح)');
    }

    if (parsedJson is! Map<String, dynamic>) {
      throw const FormatException('هيكل ملف النسخة الاحتياطية غير متوافق');
    }

    final payload = BackupPayload.fromJson(parsedJson);

    // 2. Validate App and Schema Version
    if (payload.metadata.appName != 'Taswiyah') {
      throw const FormatException('هذا الملف لا ينتمي لتطبيق Taswiyah');
    }

    if (payload.metadata.schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'إصدار هذه النسخة الاحتياطية (${payload.metadata.schemaVersion}) أحدث من إصدار التطبيق المثبت ($currentSchemaVersion). يرجى تحديث التطبيق أولاً.',
      );
    }

    if (payload.tables.isEmpty) {
      throw const FormatException('النسخة الاحتياطية لا تحتوي على أي جداول بيانات');
    }

    // 3. Take safety snapshot of current data before touching SQLite
    final safety = await _takeSafetySnapshot();

    // 4. Perform atomic replacement
    final db = await LocalDbService.instance.database;
    try {
      await db.transaction((txn) async {
        // Disable foreign keys temporarily during table reload
        await txn.execute('PRAGMA foreign_keys = OFF;');

        // Discover existing tables in SQLite
        final existingTablesRes = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
        );
        final existingTableNames = existingTablesRes.map((r) => r['name']?.toString()).whereType<String>().toSet();

        // Wipe only tables that exist and are part of the restore payload
        for (final tableName in payload.tables.keys) {
          if (existingTableNames.contains(tableName)) {
            await txn.delete(tableName);
          }
        }

        // Insert restored rows
        for (final entry in payload.tables.entries) {
          final tableName = entry.key;
          final rows = entry.value;

          if (!existingTableNames.contains(tableName)) {
            // If table doesn't exist in current SQLite, skip gracefully
            continue;
          }

          if (rows.isNotEmpty) {
            final batch = txn.batch();
            for (final row in rows) {
              batch.insert(tableName, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          }
        }

        // Re-enable foreign keys
        await txn.execute('PRAGMA foreign_keys = ON;');
      });

      // 5. Restore user settings into SharedPreferences
      if (payload.settings.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        payload.settings.forEach((key, val) {
          if (val is String) prefs.setString(key, val);
          if (val is int) prefs.setInt(key, val);
          if (val is double) prefs.setDouble(key, val);
          if (val is bool) prefs.setBool(key, val);
        });
      }

      return payload.metadata;
    } catch (e) {
      // Rollback to safety snapshot
      await _rollbackSafetySnapshot(safety);
      throw Exception('فشلت عملية استعادة البيانات وتم الحفاظ على البيانات السابقة بأمان: $e');
    }
  }
}
