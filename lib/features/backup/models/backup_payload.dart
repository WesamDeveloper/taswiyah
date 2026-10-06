import 'backup_metadata.dart';

class BackupPayload {
  final BackupMetadata metadata;
  final Map<String, List<Map<String, dynamic>>> tables;
  final Map<String, dynamic> settings;

  const BackupPayload({
    required this.metadata,
    required this.tables,
    this.settings = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'tables': tables,
      'settings': settings,
    };
  }

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final metaJson = json['metadata'] != null && json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};

    final rawTables = json['tables'] != null && json['tables'] is Map
        ? json['tables'] as Map
        : {};

    final Map<String, List<Map<String, dynamic>>> parsedTables = {};
    rawTables.forEach((key, value) {
      if (value is List) {
        parsedTables[key.toString()] = value.map((row) {
          if (row is Map) {
            return Map<String, dynamic>.from(row);
          }
          return <String, dynamic>{};
        }).toList();
      }
    });

    final settingsMap = json['settings'] != null && json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : <String, dynamic>{};

    return BackupPayload(
      metadata: BackupMetadata.fromJson(metaJson),
      tables: parsedTables,
      settings: settingsMap,
    );
  }
}
