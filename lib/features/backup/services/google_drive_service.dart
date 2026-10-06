import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_metadata.dart';

/// Authenticated HTTP Client passing OAuth authHeaders to Google APIs
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  static const String backupFolderName = 'Taswiyah Backups';
  static const String prefsLinkedEmailKey = 'google_drive_linked_email';

  // Request ONLY drive.file scope (strictly minimal permission to only access files created by Taswiyah)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get currentEmail => _currentUser?.email;

  /// Attempts silent sign in if previously authorized
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        await _initializeDriveApi(account);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefsLinkedEmailKey, account.email);
      }
      return account;
    } catch (e) {
      debugPrint('Google Drive silent sign in note: $e');
      return null;
    }
  }

  /// Initiates interactive Google Sign-In with account picker
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        await _initializeDriveApi(account);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefsLinkedEmailKey, account.email);
      }
      return account;
    } catch (e) {
      debugPrint('Google Drive sign in error: $e');
      rethrow;
    }
  }

  /// Signs out and disconnects local OAuth link
  Future<void> disconnect() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    } finally {
      _currentUser = null;
      _driveApi = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsLinkedEmailKey);
    }
  }

  /// Changes Google Account: disconnects existing and shows account picker
  Future<GoogleSignInAccount?> changeAccount() async {
    await disconnect();
    return await signIn();
  }

  Future<void> _initializeDriveApi(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(authenticateClient);
  }

  drive.DriveApi _getDriveApi() {
    if (_driveApi == null) {
      throw StateError('يجب ربط حساب Google Drive أولاً للمتابعة');
    }
    return _driveApi!;
  }

  /// Finds or creates the dedicated 'Taswiyah Backups' folder
  Future<String> _getOrCreateBackupFolder() async {
    final api = _getDriveApi();

    try {
      final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$backupFolderName' and trashed = false";
      final folderList = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (folderList.files != null && folderList.files!.isNotEmpty) {
        return folderList.files!.first.id!;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await api.files.create(
        folderMetadata,
        $fields: 'id',
      );

      return createdFolder.id!;
    } catch (e) {
      debugPrint('Error getting or creating backup folder: $e');
      throw Exception('تعذر إنشاء مجلد النسخ الاحتياطية في Google Drive: $e');
    }
  }

  /// Uploads compressed backup bytes to Google Drive
  Future<BackupMetadata> uploadBackup({
    required List<int> bytes,
    required BackupMetadata metadata,
  }) async {
    final api = _getDriveApi();
    final folderId = await _getOrCreateBackupFolder();

    final mediaStream = Stream.value(bytes);
    final media = drive.Media(mediaStream, bytes.length);

    final metadataJson = jsonEncode(metadata.toJson());

    final driveFile = drive.File()
      ..name = metadata.fileName
      ..parents = [folderId]
      ..description = metadataJson
      ..mimeType = 'application/octet-stream';

    try {
      final uploadedFile = await api.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, size, createdTime, modifiedTime, description',
      );

      return BackupMetadata(
        id: uploadedFile.id ?? metadata.id,
        fileName: metadata.fileName,
        createdAt: metadata.createdAt,
        sizeBytes: bytes.length,
        appVersion: metadata.appVersion,
        schemaVersion: metadata.schemaVersion,
        tablesCount: metadata.tablesCount,
        businessName: metadata.businessName,
      );
    } catch (e) {
      debugPrint('Error uploading backup to Google Drive: $e');
      throw Exception('فشل رفع النسخة الاحتياطية إلى Google Drive: $e');
    }
  }

  /// Lists all Taswiyah backup files in the 'Taswiyah Backups' folder sorted newest first
  Future<List<BackupMetadata>> listBackups() async {
    final api = _getDriveApi();
    final folderId = await _getOrCreateBackupFolder();

    try {
      final query = "'$folderId' in parents and trashed = false";
      final fileList = await api.files.list(
        q: query,
        orderBy: 'createdTime desc',
        spaces: 'drive',
        $fields: 'files(id, name, size, createdTime, modifiedTime, description)',
      );

      final List<BackupMetadata> backups = [];

      for (var f in fileList.files ?? <drive.File>[]) {
        final id = f.id ?? '';
        final fileName = f.name ?? '';
        final sizeBytes = int.tryParse(f.size ?? '0') ?? 0;
        final createdTime = f.createdTime ?? DateTime.now();

        // Try extracting detailed metadata from description
        if (f.description != null && f.description!.isNotEmpty) {
          try {
            final descMap = jsonDecode(f.description!) as Map<String, dynamic>;
            final meta = BackupMetadata.fromJson(descMap);
            backups.add(BackupMetadata(
              id: id,
              fileName: fileName.isNotEmpty ? fileName : meta.fileName,
              createdAt: meta.createdAt,
              sizeBytes: sizeBytes > 0 ? sizeBytes : meta.sizeBytes,
              appVersion: meta.appVersion,
              schemaVersion: meta.schemaVersion,
              tablesCount: meta.tablesCount,
              businessName: meta.businessName,
            ));
            continue;
          } catch (_) {}
        }

        // Fallback metadata if description is missing or corrupted
        backups.add(BackupMetadata(
          id: id,
          fileName: fileName,
          createdAt: createdTime,
          sizeBytes: sizeBytes,
          appVersion: '1.0.0',
          schemaVersion: 5,
        ));
      }

      return backups;
    } catch (e) {
      debugPrint('Error listing Google Drive backups: $e');
      throw Exception('تعذر استرجاع قائمة النسخ الاحتياطية من Google Drive: $e');
    }
  }

  /// Downloads binary bytes of a backup file from Google Drive
  Future<List<int>> downloadBackup(String fileId) async {
    final api = _getDriveApi();

    try {
      final dynamic response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        final List<int> bytes = [];
        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
        }
        return bytes;
      } else {
        throw Exception('استجابة غير متوقعة من Google Drive أثناء تنزيل الملف');
      }
    } catch (e) {
      debugPrint('Error downloading backup file from Google Drive: $e');
      throw Exception('فشل تنزيل ملف النسخة الاحتياطية من Google Drive: $e');
    }
  }
}
