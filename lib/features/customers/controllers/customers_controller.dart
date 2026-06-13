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
      await _refreshLocalList();
    } catch (e) {
      if (customers.isEmpty) {
        Get.snackbar('تنبيه', 'يوجد مشكلة في قراءة البيانات المحلية.');
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
    // Check local duplicate first
    bool exists = customers.any((c) => c['name'] == name || c['primary_phone'] == phone);
    if (exists) {
      Get.snackbar('تنبيه', 'يوجد عميل مسجل مسبقاً بنفس الاسم أو رقم الهاتف.', backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

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

    try {
      // Sync or Queue
      bool success = await _syncService.executeOrQueue(
        'add_customer',
        payload,
      );

      if (success) {
        Get.snackbar('نجاح', 'تم إرسال بيانات العميل', backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('تنبيه', 'تم إضافة العميل محلياً وسيتم مزامنته لاحقاً.', backgroundColor: Colors.orange, colorText: Colors.white);
      }
      return true; // Return true to close dialog
    } catch (e) {
      return true; // Even if it fails, it's added locally, so close dialog
    }
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

  Future<void> deleteCustomer(int id) async {
    // Remove locally
    await _dbService.deleteCustomer(id);
    _refreshLocalList();

    if (_syncService.isOnline.value) {
      try {
        await _apiClient.delete('/customers/$id');
        Get.snackbar('نجاح', 'تم حذف العميل بنجاح', backgroundColor: Colors.green, colorText: Colors.white);
      } catch (e) {
        Get.snackbar('خطأ', 'فشل حذف العميل من الخادم', backgroundColor: Colors.red, colorText: Colors.white);
      }
    } else {
       Get.snackbar('تنبيه', 'أنت غير متصل بالإنترنت. سيتم حذف العميل محلياً فقط.', backgroundColor: Colors.orange, colorText: Colors.white);
    }
  }
}
