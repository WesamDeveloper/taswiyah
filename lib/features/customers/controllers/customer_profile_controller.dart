import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/database/local_db_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/services/export_service.dart';
import '../../debts/controllers/debts_controller.dart';
import '../controllers/customers_controller.dart';

class CustomerProfileController extends GetxController {
  final ApiClient _apiClient = ApiClient();
  final SyncService _syncService = Get.find<SyncService>();
  final LocalDbService _dbService = LocalDbService.instance;
  final int customerId;

  var isLoading = true.obs;
  var customer = {}.obs;
  var debts = [].obs;

  CustomerProfileController(this.customerId);

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final localCust = await _dbService.getCustomer(customerId);
      if (localCust != null) {
        customer.value = localCust;
      }
      final localDebts = await _dbService.getCustomerDebts(customerId);
      if (localDebts.isNotEmpty) {
        debts.value = localDebts;
      }

      if (_syncService.isOnline.value) {
        final response = await _apiClient.get('/customers/$customerId');
        if (response.statusCode == 200) {
          customer.value = response.data['data'];
          debts.value = response.data['data']['debts'] ?? [];

          await _dbService.saveCustomer(
            Map<String, dynamic>.from(customer.value),
          );
          await _dbService.clearSyncedCustomerDebts(customerId);
          for (var d in debts) {
            await _dbService.saveDebt(Map<String, dynamic>.from(d));
          }
        }
      }
    } catch (e) {
      if (customer.isEmpty) {
        Get.snackbar(
          'تنبيه',
          'لا يوجد اتصال بالإنترنت ولا بيانات محلية للعميل',
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addDebt(double amount, String notes) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'customer_id': customerId,
      'amount': amount,
      'notes': notes,
      'temp_id': tempId,
    };

    // Save locally
    final localDebt = {
      'id': tempId,
      'customer_id': customerId,
      'amount': amount,
      'paid': 0.0,
      'status': 'unpaid',
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _dbService.saveDebt(localDebt, isSynced: false);

    // Update local remaining balance
    final cust = Map<String, dynamic>.from(customer.value);
    cust['remaining_balance'] = (cust['remaining_balance'] ?? 0) + amount;
    await _dbService.saveCustomer(cust);

    fetchProfile();

    bool success = await _syncService.executeOrQueue(
      'add_debt',
      payload,
      onlineAction: () async {
        final response = await _apiClient.post('/debts', {}, data: payload);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final newDebt = response.data['data'];
          await _dbService.deleteDebtByRemoteId(tempId);
          await _dbService.saveDebt(Map<String, dynamic>.from(newDebt));
          fetchProfile();
          if (Get.isRegistered<CustomersController>())
            Get.find<CustomersController>().fetchCustomers();
          if (Get.isRegistered<DebtsController>())
            Get.find<DebtsController>().fetchDebts();
        } else {
          throw Exception('Failed');
        }
      },
    );

    if (success) {
      Get.snackbar(
        'نجاح',
        'تم تسجيل الدين وإشعار العميل',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  Future<void> receivePayment(double amount) async {
    final payload = {'amount': amount, 'customer_id': customerId};

    // Update local remaining balance
    final cust = Map<String, dynamic>.from(customer.value);
    cust['remaining_balance'] = (cust['remaining_balance'] ?? 0) - amount;
    await _dbService.saveCustomer(cust);
    fetchProfile();

    bool success = await _syncService.executeOrQueue(
      'add_payment',
      payload,
      onlineAction: () async {
        final response = await _apiClient.post(
          '/customers/$customerId/pay',
          {},
          data: {'amount': amount},
        );
        if (response.statusCode == 200) {
          fetchProfile();
          if (Get.isRegistered<CustomersController>())
            Get.find<CustomersController>().fetchCustomers();
          if (Get.isRegistered<DebtsController>())
            Get.find<DebtsController>().fetchDebts();
        } else {
          throw Exception('Failed');
        }
      },
    );

    if (success) {
      Get.snackbar(
        'نجاح',
        'تم خصم المبلغ من الديون',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  Future<void> sendReminder() async {
    if (!_syncService.isOnline.value) {
      Get.snackbar(
        'تنبيه',
        'يجب الاتصال بالإنترنت لإرسال تذكير واتساب',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    try {
      final response = await _apiClient.post(
        '/customers/$customerId/remind',
        {},
      );
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          'تم إرسال التذكير للعميل عبر الواتساب بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } on DioException catch (e) {
      Get.snackbar(
        'خطأ',
        e.response?.data['message'] ?? 'فشل الإرسال',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل الإرسال',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> updateProfile(String name, String phone) async {
    final payload = {'id': customerId, 'name': name, 'primary_phone': phone};

    // Update local immediately
    final cust = Map<String, dynamic>.from(customer.value);
    cust['name'] = name;
    cust['primary_phone'] = phone;
    await _dbService.saveCustomer(cust);
    fetchProfile();

    bool success = await _syncService.executeOrQueue(
      'update_customer',
      payload,
      onlineAction: () async {
        final response = await _apiClient.put(
          '/customers/$customerId',
          data: {'name': name, 'primary_phone': phone},
        );
        if (response.statusCode == 200) {
          fetchProfile();
          if (Get.isRegistered<CustomersController>()) {
            Get.find<CustomersController>().fetchCustomers();
          }
        } else {
          throw Exception('Failed');
        }
      },
    );

    if (success) {
      Get.snackbar(
        'نجاح',
        'تم تحديث بيانات العميل بنجاح',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  Future<void> updateSchedule(DateTime? date, int? days) async {
    try {
      final response = await _apiClient.post(
        '/customers/$customerId',
        {},
        data: {
          'next_reminder_date': date?.toIso8601String().split('T')[0],
          'reminder_frequency_days': days,
        },
      );
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          'تم حفظ إعدادات تذكير العميل',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        fetchProfile();
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل حفظ الإعدادات',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> toggleDebtNotification(bool value) async {
    if (!_syncService.isOnline.value) {
      Get.snackbar(
        'تنبيه',
        'يجب الاتصال بالإنترنت لتعديل إعدادات الواتساب',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    try {
      final response = await _apiClient.put(
        '/customers/$customerId',
        data: {'notify_on_debt': value},
      );
      if (response.statusCode == 200) {
        fetchProfile();
      }
    } on DioException catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل الحفظ: ${e.response?.data['message'] ?? e.response?.data}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل حفظ إعدادات الإشعارات',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> exportStatement(
    String format,
    DateTime? start,
    DateTime? end,
  ) async {
    final exportService = Get.put(ExportService());

    Get.snackbar(
      'جاري التحضير',
      'يتم الآن تجهيز كشف الحساب...',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );

    try {
      await exportService.exportCustomerStatement(
        customerId: customerId,
        customerName: customer['name'] ?? 'العميل',
        format: format,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تصدير كشف الحساب: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print("فشل تصدير كشف الحساب: $e");
    }
  }
}
