import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/database/local_db_service.dart';

class CustomersController extends GetxController {
  final ApiClient _apiClient = ApiClient();
  final SyncService _syncService = Get.find<SyncService>();
  final LocalDbService _dbService = LocalDbService.instance;
  
  var isLoading = true.obs;
  var customers = [].obs;
  var selectedCustomers = <int>[].obs;
  var searchQuery = ''.obs;

  void toggleSelection(int id) {
    if (selectedCustomers.contains(id)) {
      selectedCustomers.remove(id);
    } else {
      selectedCustomers.add(id);
    }
  }

  void clearSelection() {
    selectedCustomers.clear();
  }

  @override
  void onInit() {
    super.onInit();
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    isLoading.value = true;
    try {
      // 1. Fetch local customers first for fast UI
      final localCustomers = await _dbService.getAllCustomers();
      if (localCustomers.isNotEmpty) {
        customers.value = localCustomers;
      }

      // 2. Try fetching from remote if online
      if (_syncService.isOnline.value) {
        final response = await _apiClient.get('/customers');
        if (response.data['status'] == 'success') {
          final remoteCustomers = response.data['data'];
          
          // Clear old synced data to prevent duplicates
          await _dbService.clearSyncedCustomers();
          
          // Save to local DB
          for (var c in remoteCustomers) {
            await _dbService.saveCustomer(Map<String, dynamic>.from(c));
          }
          
          // Reload from local DB to get search and sorting consistent
          _refreshLocalList();
        }
      }
    } catch (e) {
      if (customers.isEmpty) {
        Get.snackbar('تنبيه', 'أنت غير متصل بالإنترنت ولا يوجد بيانات محلية.');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshLocalList() async {
    if (searchQuery.value.isEmpty) {
      customers.value = await _dbService.getAllCustomers();
    } else {
      customers.value = await _dbService.searchCustomers(searchQuery.value);
    }
  }

  void searchCustomers(String query) {
    searchQuery.value = query;
    _refreshLocalList();
  }

  Future<bool> addCustomer(String name, String phone) async {
    final payload = {'name': name, 'primary_phone': phone};
    
    // Save locally first for instant UI response
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final localCustomer = {
      'id': tempId, // Temporary ID, will be replaced when synced if possible
      'name': name,
      'primary_phone': phone,
      'remaining_balance': 0.0,
      'notify_on_debt': 0,
    };
    await _dbService.saveCustomer(localCustomer, isSynced: false);
    _refreshLocalList();

    // Sync or Queue
    bool success = await _syncService.executeOrQueue(
      'add_customer',
      payload,
      onlineAction: () async {
        final response = await _apiClient.post('/customers', {}, data: payload);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final newCustomer = response.data['data'];
          await _dbService.saveCustomer(newCustomer);
          // Try to remove the temp one, or just let it be overwritten by refresh
          _refreshLocalList();
        } else {
          throw Exception('Failed from server');
        }
      }
    );

    if (success) {
      Get.snackbar('نجاح', 'تم إضافة العميل بنجاح', backgroundColor: Colors.green, colorText: Colors.white);
    }
    return true; // Return true because it's locally added anyway
  }

  Future<void> sendToAll() async {
    if (!_syncService.isOnline.value) {
      Get.snackbar('تنبيه', 'يجب الاتصال بالإنترنت لإرسال تذكير جماعي عبر الواتساب', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    try {
      final response = await _apiClient.post('/customers/remind-all', {});
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          response.data['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل إرسال التذكير الجماعي',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> sendToGroup() async {
    if (!_syncService.isOnline.value) {
      Get.snackbar('تنبيه', 'يجب الاتصال بالإنترنت لإرسال رسائل الواتساب', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    if (selectedCustomers.isEmpty) {
      sendToAll();
      return;
    }
    try {
      final response = await _apiClient.post(
        '/customers/remind-group',
        {},
        data: {'customer_ids': selectedCustomers.toList()},
      );
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          response.data['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        clearSelection();
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل الإرسال للمجموعة',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> scheduleGroup(DateTime? date, int? frequencyDays) async {
    if (!_syncService.isOnline.value) {
      Get.snackbar('تنبيه', 'يجب الاتصال بالإنترنت لجدولة رسائل الواتساب', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    if (selectedCustomers.isEmpty) return;
    try {
      final response = await _apiClient.post(
        '/customers/schedule-group',
        {},
        data: {
          'customer_ids': selectedCustomers.toList(),
          'next_reminder_date': date?.toIso8601String().split('T')[0],
          'reminder_frequency_days': frequencyDays,
        },
      );
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          response.data['message'],
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        clearSelection();
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل الجدولة',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
