import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/dashboard/controllers/dashboard_controller.dart';
import '../../features/customers/controllers/customers_controller.dart';
import '../database/local_db_service.dart';
import 'api_client.dart';

class SyncService extends GetxService {
  final ApiClient _apiClient = ApiClient();
  final LocalDbService _dbService = LocalDbService.instance;

  var isOnline = true.obs;
  var isSyncing = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkInitialConnectivity();
    _listenToConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionState(results);
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectionState(results);
    });
  }

  void _updateConnectionState(List<ConnectivityResult> results) {
    bool online = !results.contains(ConnectivityResult.none);
    if (online && !isOnline.value) {
      // Transitioned from offline to online
      isOnline.value = true;
      syncOfflineData();
    } else {
      isOnline.value = online;
    }
  }

  Future<bool> hasPendingSync() async {
    final queue = await _dbService.getSyncQueue();
    return queue.isNotEmpty;
  }

  Future<void> syncOfflineData() async {
    if (isSyncing.value || !isOnline.value) return;

    isSyncing.value = true;
    try {
      final queue = await _dbService.getSyncQueue();
      if (queue.isEmpty) {
        isSyncing.value = false;
        return;
      }

      for (var item in queue) {
        try {
          // Re-fetch item from DB in case previous queue operations modified its payload
          final refreshedItem = await _dbService.getSyncQueueItem(item['id'] as int);
          if (refreshedItem != null) {
            await _processQueueItem(refreshedItem);
            await _dbService.removeFromSyncQueue(refreshedItem['id']);
          }
        } catch (e) {
          print("Failed to sync item ${item['id']}: $e");
          // If it's a client error (4xx) like validation or not found, discard it so it doesn't block the queue forever
          if (e is DioException && e.response != null) {
            final statusCode = e.response!.statusCode;
            if (statusCode != null && statusCode >= 400 && statusCode < 500) {
              await _dbService.removeFromSyncQueue(item['id']);
              Get.snackbar('فشل مزامنة عمليه', 'تم تجاهل عملية سابقة بسبب تعارض مع بيانات السيرفر', backgroundColor: Colors.orange, colorText: Colors.white);
            }
          }
        }
      }

      // Optionally trigger a refresh on controllers so they fetch fresh IDs from server
      Get.snackbar('مزامنة ناجحة', 'تم مزامنة البيانات المتأخرة مع السيرفر', backgroundColor: Colors.green, colorText: Colors.white);
      
      if (Get.isRegistered<CustomersController>()) {
         Get.find<CustomersController>().fetchCustomers();
      }
      if (Get.isRegistered<DashboardController>()) {
         Get.find<DashboardController>().fetchStats();
      }
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _processQueueItem(Map<String, dynamic> item) async {
    final payload = jsonDecode(item['payload']);
    final operation = item['operation'];

    switch (operation) {
      case 'add_customer':
        final tempId = payload['temp_id'] ?? payload['id']; // Sometimes we pass id, sometimes temp_id
        if (payload.containsKey('temp_id')) payload.remove('temp_id');
        final response = await _apiClient.post('/customers', {}, data: payload);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final newId = response.data['data']['id'];
          if (tempId != null && newId != null && tempId != newId) {
            await _dbService.replaceCustomerTempId(tempId, newId);
          }
        }
        break;
      case 'add_debt':
        final tempId = payload['temp_id'] ?? payload['id'];
        if (payload.containsKey('temp_id')) payload.remove('temp_id');
        final response = await _apiClient.post('/debts', {}, data: payload);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final newId = response.data['data']['id'];
          if (tempId != null && newId != null && tempId != newId) {
             await _dbService.replaceDebtTempId(tempId, newId);
          }
        }
        break;
      case 'update_customer':
        final id = payload['id'];
        payload.remove('id');
        final response = await _apiClient.put('/customers/$id', data: payload);
        if (response.statusCode == 200) {
          await _dbService.markCustomerAsSynced(id);
        }
        break;
      case 'add_payment':
        final id = payload['customer_id'];
        final tempId = payload['temp_id'];
        payload.remove('customer_id');
        if (payload.containsKey('temp_id')) payload.remove('temp_id');
        final response = await _apiClient.post('/customers/$id/pay', {}, data: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (tempId != null) {
            await _dbService.markPaymentAsSynced(tempId);
          }
        }
        break;
      default:
        print('Unknown operation: $operation');
    }
  }

  /// Use this method instead of direct ApiClient calls when the app needs offline support.
  Future<bool> executeOrQueue(
    String operation,
    Map<String, dynamic> payload,
  ) async {
    if (isOnline.value) {
      try {
        await _processQueueItem({
          'operation': operation,
          'payload': jsonEncode(payload),
        });
        return true; // Sent to server successfully
      } catch (e) {
        // Fallback to queue if server fails but internet is somewhat available
        await _dbService.addToSyncQueue(operation, jsonEncode(payload));
        return false;
      }
    } else {
      // Offline: Add to queue
      await _dbService.addToSyncQueue(operation, jsonEncode(payload));
      Get.snackbar(
        'وضع عدم الاتصال',
        'تم حفظ العملية في الهاتف وستتم المزامنة لاحقاً',
      );
      return false; // Queued locally
    }
  }

  /// Perform a full initial sync from the server
  Future<bool> performInitialSync() async {
    if (!isOnline.value) {
      Get.snackbar('تنبيه', 'يجب أن تكون متصلاً بالإنترنت لسحب البيانات لأول مرة');
      return false;
    }

    try {
      isSyncing.value = true;
      Get.snackbar('جاري المزامنة', 'جاري سحب البيانات من السيرفر، يرجى الانتظار...');

      final response = await _apiClient.get('/sync/initial');
      
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];
        final customers = data['customers'] as List;
        final debts = data['debts'] as List;
        final payments = data['payments'] as List;

        // Clear local database
        await _dbService.clearAllSyncedDebts();
        await _dbService.clearSyncedCustomers();
        // Clear payments too - wait, LocalDbService doesn't have a specific method for this yet, we can execute raw sql
        final db = await LocalDbService.instance.database;
        await db.delete('payments', where: 'is_synced = 1');

        // Populate local database
        for (var c in customers) {
          await _dbService.saveCustomer(Map<String, dynamic>.from(c), isSynced: true);
        }
        for (var d in debts) {
          // debt['id'] is the remote_id
          await _dbService.saveDebt(Map<String, dynamic>.from(d), isSynced: true);
        }
        for (var p in payments) {
          await _dbService.savePayment(Map<String, dynamic>.from(p), isSynced: true);
        }

        Get.snackbar('نجاح', 'تم سحب جميع البيانات بنجاح، التطبيق جاهز للعمل!');
        return true;
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل سحب البيانات من السيرفر: ${e.toString()}');
    } finally {
      isSyncing.value = false;
    }
    return false;
  }
}
