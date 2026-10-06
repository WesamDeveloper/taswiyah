import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../customers/controllers/customers_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../debts/controllers/debts_controller.dart';
import '../../debts/controllers/overdue_controller.dart';
import '../models/backup_metadata.dart';
import '../services/backup_snapshot_service.dart';
import '../services/google_drive_service.dart';

class BackupController extends GetxController {
  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final BackupSnapshotService _snapshotService = BackupSnapshotService.instance;

  var isLinked = false.obs;
  var accountEmail = ''.obs;
  var isLoading = false.obs;
  var isConnecting = false.obs;
  var isBackingUp = false.obs;
  var isRestoring = false.obs;
  var backupsList = <BackupMetadata>[].obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(GoogleDriveService.prefsLinkedEmailKey);

      final account = await _driveService.signInSilently();
      if (account != null) {
        isLinked.value = true;
        accountEmail.value = account.email;
        await fetchBackups();
      } else if (savedEmail != null && savedEmail.isNotEmpty) {
        // Was previously linked but token needs interactive refresh
        accountEmail.value = savedEmail;
        isLinked.value = false;
      }
    } catch (e) {
      debugPrint('Initial auth check note: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Interactive Google Sign-In and connection
  Future<void> connectGoogleAccount({bool promptFirstBackup = true}) async {
    isConnecting.value = true;
    errorMessage.value = '';

    try {
      final account = await _driveService.signIn();
      if (account != null) {
        isLinked.value = true;
        accountEmail.value = account.email;
        await fetchBackups();

        Get.snackbar(
          'تم الربط بنجاح',
          'تم ربط حساب Google Drive بنجاح: ${account.email}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // If no backups exist on first connection, prompt the user
        if (promptFirstBackup && backupsList.isEmpty) {
          _promptFirstBackup();
        }
      }
    } on SocketException {
      _showErrorSnackbar('تعذر الاتصال بـ Google Drive. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('sign_in_canceled') || str.contains('canceled') || str.contains('cancelled')) {
        // User cancelled picker - do nothing
        return;
      }
      if (str.contains('network') || str.contains('socket') || str.contains('connection')) {
        _showErrorSnackbar('تعذر الاتصال بـ Google Drive. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
      } else if (str.contains('access_denied') || str.contains('permission')) {
        _showErrorSnackbar('تم رفض صلاحية الوصول إلى Google Drive. يتطلب النسخ الاحتياطي الموافقة على الصلاحية.');
      } else {
        _showErrorSnackbar('تعذر ربط حساب Google: $e');
      }
    } finally {
      isConnecting.value = false;
    }
  }

  /// Change Google Account
  Future<void> changeGoogleAccount() async {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغيير حساب Google', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل تريد تغيير حساب النسخ الاحتياطي واختيار حساب Google آخر؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _performChangeAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('متابعة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performChangeAccount() async {
    isConnecting.value = true;
    try {
      final account = await _driveService.changeAccount();
      if (account != null) {
        isLinked.value = true;
        accountEmail.value = account.email;
        await fetchBackups();
        Get.snackbar(
          'تم التغيير',
          'تم ربط الحساب الجديد بنجاح: ${account.email}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (!str.contains('canceled') && !str.contains('cancelled')) {
        _showErrorSnackbar('حدث خطأ أثناء تغيير الحساب: $e');
      }
    } finally {
      isConnecting.value = false;
    }
  }

  /// Disconnect Google Account without touching remote backups or local data
  Future<void> disconnectGoogleAccount() async {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('فصل حساب Google', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'هل أنت متأكد من رغبتك في فصل حساب Google Drive؟\n\nلن يتم حذف أي نسخ احتياطية موجودة في حسابك أو بياناتك المحلية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _driveService.disconnect();
              isLinked.value = false;
              accountEmail.value = '';
              backupsList.clear();
              Get.snackbar(
                'تم الفصل',
                'تم فصل حساب Google. النسخ الاحتياطية الموجودة في حسابك لم يتم حذفها.',
                backgroundColor: Colors.blueGrey,
                colorText: Colors.white,
                duration: const Duration(seconds: 4),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('فصل الحساب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Fetches available backups from Google Drive
  Future<void> fetchBackups() async {
    if (!isLinked.value) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final list = await _driveService.listBackups();
      backupsList.assignAll(list);
    } on SocketException {
      _showErrorSnackbar('تعذر الاتصال بـ Google Drive. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
    } catch (e) {
      debugPrint('Error listing backups: $e');
      _showErrorSnackbar('تعذر استرجاع النسخ الاحتياطية: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Creates a new backup snapshot and uploads it to Google Drive
  Future<void> createBackup() async {
    if (!isLinked.value) {
      await connectGoogleAccount(promptFirstBackup: false);
      if (!isLinked.value) return;
    }

    isBackingUp.value = true;
    errorMessage.value = '';

    try {
      // 1. Snapshot local SQLite
      final snapshot = await _snapshotService.createSnapshotBytes();

      // 2. Upload to Google Drive
      final uploadedMeta = await _driveService.uploadBackup(
        bytes: snapshot.bytes,
        metadata: snapshot.metadata,
      );

      // 3. Update list
      backupsList.insert(0, uploadedMeta);

      Get.snackbar(
        'نجاح النسخ الاحتياطي',
        'تم إنشاء النسخة الاحتياطية بنجاح (${uploadedMeta.formattedDate} - ${uploadedMeta.formattedTime})',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } on SocketException {
      _showErrorSnackbar('انقطع الاتصال بالإنترنت أثناء رفع النسخة الاحتياطية. يرجى المحاولة مرة أخرى.');
    } catch (e) {
      debugPrint('Backup creation error: $e');
      _showErrorSnackbar('فشل إنشاء النسخة الاحتياطية: $e');
    } finally {
      isBackingUp.value = false;
    }
  }

  /// Prompts for confirmation then safely restores a backup
  Future<void> restoreBackup(BackupMetadata backup) async {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Text('تأكيد الاستعادة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'استعادة النسخة الاحتياطية (${backup.formattedDate} - ${backup.formattedTime}) ستستبدل البيانات الحالية الموجودة على هذا الجهاز.\n\nهل ترغب بالمتابعة؟',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _performRestore(backup);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('متابعة الاستعادة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(BackupMetadata backup) async {
    isRestoring.value = true;
    errorMessage.value = '';

    try {
      // 1. Download backup bytes
      final bytes = await _driveService.downloadBackup(backup.id);

      // 2. Validate, snapshot safety, and restore SQLite
      await _snapshotService.restoreSnapshot(bytes);

      // 3. Refresh application controllers
      _refreshApplicationState();

      Get.snackbar(
        'تمت الاستعادة بنجاح',
        'تمت استعادة جميع البيانات بنجاح من نسخة (${backup.formattedDate} - ${backup.formattedTime})',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } on SocketException {
      _showErrorSnackbar('انقطع الاتصال بالإنترنت أثناء تنزيل النسخة الاحتياطية. تم الحفاظ على بياناتك دون أي تغيير.');
    } catch (e) {
      debugPrint('Restore error: $e');
      _showErrorSnackbar('تعذر استعادة النسخة الاحتياطية: $e');
    } finally {
      isRestoring.value = false;
    }
  }

  void _refreshApplicationState() {
    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().fetchCustomers();
    }
    if (Get.isRegistered<DebtsController>()) {
      Get.find<DebtsController>().fetchDebts();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }
    if (Get.isRegistered<OverdueController>()) {
      Get.find<OverdueController>().fetchOverdueCustomers();
    }
  }

  void _promptFirstBackup() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('لم يتم العثور على نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'لم يتم العثور على أي نسخ احتياطية سابقة في حساب Google المرتبط.\n\nهل تريد إنشاء أول نسخة احتياطية لبياناتك الآن؟',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              createBackup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('إنشاء نسخة احتياطية', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    errorMessage.value = message;
    Get.snackbar(
      'تنبيه',
      message,
      backgroundColor: Colors.red.shade800,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }
}
