import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_db_service.dart';
import '../../../core/services/export_service.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../debts/controllers/debts_controller.dart';
import '../controllers/customers_controller.dart';

class CustomerProfileController extends GetxController {
  final LocalDbService _dbService = LocalDbService.instance;
  static const Uuid _uuid = Uuid();
  final String customerId;

  var isLoading = false.obs;
  var customer = <String, dynamic>{}.obs;
  var debts = <Map<String, dynamic>>[].obs;
  var transactions = <Map<String, dynamic>>[].obs;

  // Pagination (5 items per batch)
  static const int pageSize = 5;
  var displayedTransactions = <Map<String, dynamic>>[].obs;
  var hasMoreTransactions = false.obs;
  var isLoadingMore = false.obs;
  List<Map<String, dynamic>> _allTransactions = [];

  CustomerProfileController(dynamic id) : customerId = id.toString();

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final localCust = await _dbService.getCustomer(customerId);

      if (localCust != null) {
        customer.assignAll(localCust);
      }

      final localDebts = await _dbService.getCustomerDebts(customerId);
      final localPayments = await _dbService.getCustomerPayments(customerId);

      double calculatedRemaining = 0.0;
      for (var d in localDebts) {
        final amount = double.tryParse(d['amount'].toString()) ?? 0.0;
        final paid = double.tryParse((d['paid'] ?? 0).toString()) ?? 0.0;
        calculatedRemaining += (amount - paid);
      }

      customer['remaining_balance'] = calculatedRemaining < 0 ? 0.0 : calculatedRemaining;
      customer.refresh();

      _updateTransactionsList(localDebts, localPayments);
    } catch (e) {
      debugPrint('Customer profile fetch note: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _updateTransactionsList(
    List<Map<String, dynamic>> dList,
    List<Map<String, dynamic>> pList,
  ) {
    debts.assignAll(dList);

    List<Map<String, dynamic>> combined = [];
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
      String dateA = a['created_at']?.toString() ?? '';
      String dateB = b['created_at']?.toString() ?? '';
      return dateB.compareTo(dateA); // DESC (Newest first)
    });

    _allTransactions = combined;
    transactions.assignAll(combined);

    // Initialize first batch of 5 items
    displayedTransactions.assignAll(_allTransactions.take(pageSize).toList());
    hasMoreTransactions.value = _allTransactions.length > displayedTransactions.length;

    debts.refresh();
    transactions.refresh();
    displayedTransactions.refresh();
  }

  /// Loads the next batch of 5 transactions on scroll
  Future<void> loadMoreTransactions() async {
    if (isLoadingMore.value || !hasMoreTransactions.value) return;

    isLoadingMore.value = true;
    await Future.delayed(const Duration(milliseconds: 200));

    final currentCount = displayedTransactions.length;
    final nextBatch = _allTransactions.skip(currentCount).take(pageSize).toList();
    displayedTransactions.addAll(nextBatch);
    hasMoreTransactions.value = displayedTransactions.length < _allTransactions.length;
    isLoadingMore.value = false;
  }

  Future<void> addDebt(double amount, String notes) async {
    if (amount <= 0) {
      Get.snackbar('تنبيه', 'يجب أن يكون مبلغ الدين أكبر من الصفر');
      return;
    }

    final newDebtId = _uuid.v4();
    final localDebt = {
      'id': newDebtId,
      'customer_id': customerId,
      'amount': amount,
      'paid': 0.0,
      'status': 'unpaid',
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _dbService.saveDebt(localDebt);
    await fetchProfile();

    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().fetchCustomers();
    }
    if (Get.isRegistered<DebtsController>()) {
      Get.find<DebtsController>().fetchDebts();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }

    Get.snackbar(
      'نجاح',
      'تم تسجيل الدين محلياً بنجاح',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  /// Atomic FIFO payment reception
  Future<void> receivePayment(double amount) async {
    if (amount <= 0) {
      Get.snackbar('تنبيه', 'يجب أن يكون مبلغ السداد أكبر من الصفر');
      return;
    }

    try {
      await _dbService.recordPaymentTransaction(
        customerId: customerId,
        amount: amount,
      );

      await fetchProfile();

      if (Get.isRegistered<CustomersController>()) {
        Get.find<CustomersController>().fetchCustomers();
      }
      if (Get.isRegistered<DebtsController>()) {
        Get.find<DebtsController>().fetchDebts();
      }
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().fetchStats();
      }

      Get.snackbar(
        'نجاح',
        'تم تسجيل الدفعة وتسوية الأرصدة بنجاح (FIFO)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تسجيل الدفعة: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  var isSendingReminder = false.obs;

  /// Sends reminder directly via WhatsApp using local url_launcher
  Future<void> sendReminder() async {
    final currentCustomer = customer;
    final remaining = double.tryParse((currentCustomer['remaining_balance'] ?? 0).toString()) ?? 0.0;
    final phone = currentCustomer['primary_phone']?.toString().trim() ?? '';
    final name = currentCustomer['name']?.toString() ?? 'عميلنا العزيز';

    if (remaining <= 0) {
      Get.snackbar('تنبيه', 'لا يوجد رصيد متبقي على هذا العميل', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (phone.isEmpty) {
      Get.snackbar('خطأ', 'رقم هاتف العميل غير متوفر', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.length == 9 && formattedPhone.startsWith('7')) {
      formattedPhone = '967$formattedPhone';
    } else if (formattedPhone.length == 10 && formattedPhone.startsWith('05')) {
      formattedPhone = '966${formattedPhone.substring(1)}';
    }

    final message = "📄 *تذكير رصيد مستحق*\n\n"
        "مرحباً *$name*،\n"
        "نود تذكيركم بأن الرصيد المتبقي المستحق عليكم هو: *${remaining.toStringAsFixed(0)} ر.ي*.\n"
        "يرجى التكرم بالسداد عند الاستطاعة. شكراً لتعاملكم معنا!";

    final uri = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar('تنبيه', 'تعذر فتح تطبيق الواتساب مباشرة', backgroundColor: Colors.orange, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر إرسال الرسالة: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> updateProfile(String name, String phone) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    final cust = Map<String, dynamic>.from(customer);
    cust['name'] = cleanName;
    cust['primary_phone'] = cleanPhone;
    await _dbService.saveCustomer(cust);
    await fetchProfile();

    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().fetchCustomers();
    }

    Get.snackbar(
      'نجاح',
      'تم تحديث بيانات العميل بنجاح',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
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
    }
  }
}
