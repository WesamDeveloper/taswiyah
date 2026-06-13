import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/database/local_db_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/services/export_service.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
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
  var transactions = [].obs;
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
      final localPayments = await _dbService.getCustomerPayments(customerId);

      _updateTransactionsList(localDebts, localPayments);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل بيانات العميل');
    } finally {
      isLoading.value = false;
    }
  }

  void _updateTransactionsList(
    List<Map<String, dynamic>> dList,
    List<Map<String, dynamic>> pList,
  ) {
    debts.value =
        dList; // Keep debts for legacy logic if needed (like FIFO payments)

    List combined = [];
    for (var d in dList) {
      final map = Map<String, dynamic>.from(d);
      map['tx_type'] = 'debt';
      combined.add(map);
    }
    for (var p in pList) {
      final map = Map<String, dynamic>.from(p);
      map['tx_type'] = 'payment';
      combined.add(map);
    }

    combined.sort((a, b) {
      String dateA = a['created_at'] ?? '';
      String dateB = b['created_at'] ?? '';
      return dateB.compareTo(dateA); // DESC
    });

    transactions.value = combined;
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

    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().fetchCustomers();
    }
    if (Get.isRegistered<DebtsController>()) {
      Get.find<DebtsController>().fetchDebts();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }

    _syncService.executeOrQueue('add_debt', payload).then((success) {
      if (success) {
        Get.snackbar(
          'نجاح',
          'تم تسجيل الدين وإشعار العميل',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
  }

  Future<void> receivePayment(double amount) async {
    final tempPaymentId = DateTime.now().millisecondsSinceEpoch;
    final payload = {'amount': amount, 'customer_id': customerId, 'temp_id': tempPaymentId};

    // Update local remaining balance
    final cust = Map<String, dynamic>.from(customer.value);
    cust['remaining_balance'] = (cust['remaining_balance'] ?? 0) - amount;
    await _dbService.saveCustomer(cust);

    // Update local debts to reflect payment (FIFO)
    double remainingPayment = amount;
    final localDebts = List<Map<String, dynamic>>.from(await _dbService.getCustomerDebts(customerId));
    // Sort debts ascending by created_at to pay oldest first
    localDebts.sort(
      (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
    );

    for (var debt in localDebts) {
      if (remainingPayment <= 0) break;

      final mutableDebt = Map<String, dynamic>.from(debt);
      double debtAmount = double.parse((mutableDebt['amount'] ?? 0).toString());
      double debtPaid = double.parse((mutableDebt['paid'] ?? 0).toString());
      double debtRemaining = debtAmount - debtPaid;

      if (debtRemaining > 0) {
        double amountToApply = remainingPayment >= debtRemaining
            ? debtRemaining
            : remainingPayment;
        mutableDebt['paid'] = debtPaid + amountToApply;
        if (mutableDebt['paid'] >= debtAmount) {
          mutableDebt['status'] = 'paid';
        } else {
          mutableDebt['status'] = 'partially_paid';
        }
        await _dbService.saveDebt(
          mutableDebt,
          isSynced: false,
        ); // save updated debt
        remainingPayment -= amountToApply;
      }
    }

    // Save local payment record to make it visible in history
    final localPayment = {
      'id': tempPaymentId,
      'customer_id': customerId,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _dbService.savePayment(localPayment, isSynced: false);

    fetchProfile();

    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().fetchCustomers();
    }
    if (Get.isRegistered<DebtsController>()) {
      Get.find<DebtsController>().fetchDebts();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }

    _syncService.executeOrQueue('add_payment', payload).then((success) {
      if (success) {
        Get.snackbar(
          'نجاح',
          'تم خصم المبلغ من الديون',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
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
      // Pass the locally calculated exact remaining balance to the backend
      // This ensures the reminder is accurate even if there are unsynced transactions
      final currentCustomer = customer.value;
      final remaining = double.parse(
        (currentCustomer['remaining_balance'] ?? 0).toString(),
      );
      final phone = currentCustomer['primary_phone'];
      final name = currentCustomer['name'];

      final response = await _apiClient.post('/customers/$customerId/remind', {
        'remaining': remaining,
        'phone': phone,
        'name': name,
      });
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          'تم إرسال التذكير بنجاح عبر الواتساب',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      String errorMessage =
          'فشل إرسال التذكير عبر الواتساب. تأكد من ربط الحساب برقم صحيح.';
      if (e is DioException && e.response?.data != null) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }
      Get.snackbar(
        'خطأ',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print("${errorMessage} $e");
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

    _syncService.executeOrQueue(
      'update_customer',
      payload,
    ).then((success) {
      if (success) {
        Get.snackbar(
          'نجاح',
          'تم تحديث بيانات العميل بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
  }

  Future<void> updateSchedule(DateTime? date, int? days) async {
    final nextDate = date?.toIso8601String().split('T')[0];
    
    // Update local immediately
    final cust = Map<String, dynamic>.from(customer.value);
    cust['next_reminder_date'] = nextDate;
    cust['reminder_frequency_days'] = days;
    await _dbService.saveCustomer(cust);
    fetchProfile();

    final payload = {
      'id': customerId,
      'next_reminder_date': nextDate,
      'reminder_frequency_days': days,
    };

    _syncService.executeOrQueue(
      'update_customer',
      payload,
    ).then((success) {
      if (success) {
        Get.snackbar(
          'نجاح',
          'تم حفظ إعدادات تذكير العميل بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
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
        final cust = Map<String, dynamic>.from(customer.value);
        cust['notify_on_debt'] = value ? 1 : 0;
        await _dbService.saveCustomer(cust);
        customer.value = cust;
      }
    } on DioException catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل الحفظ: ${e.response?.data['message'] ?? e.response?.data}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print(
        "$e الرساله المدققه ${e.response?.data['message'] ?? e.response?.data}",
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
