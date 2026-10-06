class BackupMetadata {
  final String id;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final String appVersion;
  final int schemaVersion;
  final int backupVersion;
  final Map<String, int> tablesCount;
  final String? businessName;
  final String? appName;

  const BackupMetadata({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    required this.appVersion,
    required this.schemaVersion,
    this.backupVersion = 1,
    this.tablesCount = const {},
    this.businessName,
    this.appName = 'Taswiyah',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'sizeBytes': sizeBytes,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'backupVersion': backupVersion,
      'tablesCount': tablesCount,
      'businessName': businessName,
      'appName': appName,
    };
  }

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      sizeBytes: int.tryParse(json['sizeBytes']?.toString() ?? '0') ?? 0,
      appVersion: json['appVersion']?.toString() ?? '1.0.0',
      schemaVersion: int.tryParse(json['schemaVersion']?.toString() ?? '5') ?? 5,
      backupVersion: int.tryParse(json['backupVersion']?.toString() ?? '1') ?? 1,
      tablesCount: json['tablesCount'] != null && json['tablesCount'] is Map
          ? Map<String, int>.from(json['tablesCount'].map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0)))
          : const {},
      businessName: json['businessName']?.toString(),
      appName: json['appName']?.toString() ?? 'Taswiyah',
    );
  }

  /// Formatted human-readable size (e.g. 1.2 MB or 450 KB)
  String get formattedSize {
    if (sizeBytes <= 0) return '0 بايت';
    if (sizeBytes < 1024) return '$sizeBytes بايت';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} كيلوبايت';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} ميجابايت';
  }

  /// Arabic formatted date (e.g. 5 أكتوبر 2026)
  String get formattedDate {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final day = createdAt.day;
    final month = months[createdAt.month - 1];
    final year = createdAt.year;
    return '$day $month $year';
  }

  /// Arabic formatted time (e.g. 4:30 م)
  String get formattedTime {
    int hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }
}
