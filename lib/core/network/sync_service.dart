import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

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
          await _processQueueItem(item);
          await _dbService.removeFromSyncQueue(item['id']);
        } catch (e) {
          print("Failed to sync item \${item['id']}: $e");
          // If it's a 4xx error (e.g. validation failed), we might want to remove it or log it
          // For now, keep it in queue to retry later
        }
      }

      // Optionally trigger a refresh on controllers so they fetch fresh IDs from server
      Get.snackbar('مزامنة ناجحة', 'تم مزامنة البيانات المتأخرة مع السيرفر');
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _processQueueItem(Map<String, dynamic> item) async {
    final payload = jsonDecode(item['payload']);
    final operation = item['operation'];

    switch (operation) {
      case 'add_customer':
        await _apiClient.post('/customers', {}, data: payload);
        break;
      case 'add_debt':
        await _apiClient.post('/debts', {}, data: payload);
        if (payload.containsKey('temp_id')) {
          await _dbService.deleteDebtByRemoteId(payload['temp_id']);
        }
        break;
      case 'update_customer':
        final id = payload['id'];
        payload.remove('id');
        await _apiClient.put('/customers/$id', data: payload);
        break;
      case 'add_payment':
        final id = payload['customer_id'];
        payload.remove('customer_id');
        await _apiClient.post('/customers/$id/pay', {}, data: payload);
        break;
      default:
        print('Unknown operation: $operation');
    }
  }

  /// Use this method instead of direct ApiClient calls when the app needs offline support.
  Future<bool> executeOrQueue(
    String operation,
    Map<String, dynamic> payload, {
    Function? onlineAction,
  }) async {
    if (isOnline.value) {
      try {
        if (onlineAction != null) {
          await onlineAction();
        } else {
          await _processQueueItem({
            'operation': operation,
            'payload': jsonEncode(payload),
          });
        }
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
}
